// SPDX-License-Identifier: MIT
// Offscreen 2D GPU diagnostic: no compositor window, scanout or swap interval.
#define _POSIX_C_SOURCE 200809L
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#include <drm_fourcc.h>
#include <fcntl.h>
#include <gbm.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <stdint.h>
#include <poll.h>
#include <sys/ioctl.h>
#include <linux/sync_file.h>

static double now(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}
static void require(int condition, const char *what)
{
    if (!condition) { fprintf(stderr, "%s failed\n", what); exit(1); }
}
static GLuint shader(GLenum type, const char *source)
{
    GLuint obj = glCreateShader(type);
    glShaderSource(obj, 1, &source, NULL);
    glCompileShader(obj);
    GLint ok;
    glGetShaderiv(obj, GL_COMPILE_STATUS, &ok);
    if (!ok) { char log[4096]; glGetShaderInfoLog(obj, sizeof(log), NULL, log); fprintf(stderr, "%s\n", log); }
    require(ok, "shader compile");
    return obj;
}
static int compare(const void *a, const void *b)
{
    double x=*(const double *)a, y=*(const double *)b;
    return (x>y)-(x<y);
}
int main(int argc, char **argv)
{
    FILE *board = fopen("/proc/device-tree/compatible", "r");
    char compatible[128]={0};
    require(board != NULL, "board file");
    require(fread(compatible, 1, sizeof(compatible)-1, board)>0, "board read");
    fclose(board);
    require(!strcmp(compatible, "samsung,matisse3g"), "SM-T531 board");
    int width=1280, height=800, frames=40;
    int repeats = 1;
    const char *repeat_env = getenv("FD2D_DRAW_REPEATS");
    if (repeat_env) {
        repeats = atoi(repeat_env);
        require(repeats >= 1 && repeats <= 64, "draw repeats 1..64");
    }
    int uniform_updates = getenv("FD2D_UNIFORM_UPDATES") != NULL;
    int clear_only = getenv("FD2D_CLEAR_ONLY") != NULL;
    int depth_test = getenv("FD2D_DEPTH_TEST") != NULL;
    int rgb565_target = getenv("FD2D_RGB565_TARGET") != NULL;
    int fence_probe = getenv("FD2D_FENCE_PROBE") != NULL;
    int only_layers = 0;
    const char *selected_layers = getenv("FD2D_ONLY_LAYERS");
    if (selected_layers) {
        require(!strcmp(selected_layers, "1") || !strcmp(selected_layers, "2") ||
                !strcmp(selected_layers, "4"), "FD2D_ONLY_LAYERS must be 1, 2 or 4");
        only_layers = atoi(selected_layers);
    }
    const char *mode=getenv("FD2D_SHADER_MODE");
    if (!mode) mode="sample";
    require(!strcmp(mode,"sample") || !strcmp(mode,"solid") ||
            !strcmp(mode,"nearest") || !strcmp(mode,"alu"), "shader mode");
    require(!rgb565_target || !strcmp(mode, "solid"), "RGB565 control requires solid shader");
    if (argc==3) { width=atoi(argv[1]); height=atoi(argv[2]); }
    require(width>0 && width<=1280 && height>0 && height<=1280, "dimensions");
    PFNEGLGETPLATFORMDISPLAYEXTPROC platform=(void *)eglGetProcAddress("eglGetPlatformDisplayEXT");
    require(platform != NULL, "platform display");
    EGLDisplay d=platform(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, NULL);
    require(eglInitialize(d, NULL, NULL), "eglInitialize");
    require(eglBindAPI(EGL_OPENGL_ES_API), "eglBindAPI");
    EGLint attr[]={EGL_CONTEXT_CLIENT_VERSION,2,EGL_NONE};
    EGLContext ctx=eglCreateContext(d,EGL_NO_CONFIG_KHR,EGL_NO_CONTEXT,attr);
    require(ctx!=EGL_NO_CONTEXT, "eglCreateContext");
    require(eglMakeCurrent(d,EGL_NO_SURFACE,EGL_NO_SURFACE,ctx), "eglMakeCurrent");
    const char *renderer=(const char *)glGetString(GL_RENDERER);
    require(renderer && strstr(renderer,"FD305"), "FD305 hardware renderer");
    int linear = getenv("FD2D_LINEAR_TARGET") != NULL;
    int match_wlroots = getenv("FD2D_MATCH_WLROOTS") != NULL;
    require(!match_wlroots || strcmp(mode,"solid"), "wlroots mode requires a texture");
    printf("{\"renderer\":\"%s\",\"version\":\"%s\",\"width\":%d,\"height\":%d,\"shader_mode\":\"%s\",\"linear_target\":%s,\"match_wlroots\":%s}\n",renderer,glGetString(GL_VERSION),width,height,mode,linear?"true":"false",match_wlroots?"true":"false");
    GLuint program=glCreateProgram();
    GLuint vs=shader(GL_VERTEX_SHADER,"attribute vec2 pos; varying vec2 uv; uniform vec2 uvshift; void main(){uv=(pos+1.0)*0.5+uvshift;gl_Position=vec4(pos,0.,1.);}");
    const char *fragment=!strcmp(mode,"solid") ?
        "precision mediump float; void main(){gl_FragColor=vec4(0.0,0.0,127.0/255.0,1.0)*0.7;}" :
        "precision mediump float; varying vec2 uv; uniform sampler2D tex; void main(){gl_FragColor=texture2D(tex,uv)*0.7;}";
    if (!strcmp(mode,"alu"))
        fragment="precision mediump float; varying vec2 uv; uniform sampler2D tex; void main(){vec4 c=texture2D(tex,uv); for(int i=0;i<16;i++) c=c*0.9+vec4(0.01,0.02,0.03,0.1); gl_FragColor=c*0.7;}";
    if (match_wlroots)
        fragment="#ifdef GL_FRAGMENT_PRECISION_HIGH\nprecision highp float;\n#else\nprecision mediump float;\n#endif\nvarying vec2 uv; uniform sampler2D tex; uniform float alpha; void main(){gl_FragColor=texture2D(tex,uv)*alpha;}";
    GLuint fs=shader(GL_FRAGMENT_SHADER,fragment);
    glAttachShader(program,vs); glAttachShader(program,fs);
    glBindAttribLocation(program,0,"pos"); glLinkProgram(program);
    GLint linked; glGetProgramiv(program,GL_LINK_STATUS,&linked); require(linked,"program link");
    glUseProgram(program);
    GLint shift_location = glGetUniformLocation(program, "uvshift");
    require(!uniform_updates || shift_location >= 0, "live vertex uniform");
    if (shift_location >= 0) glUniform2f(shift_location, 0.0f, 0.0f);
    printf("{\"draw_repeats\":%d,\"uniform_updates\":%s}\n",
           repeats, uniform_updates ? "true" : "false");
    if (match_wlroots) {
        GLint location=glGetUniformLocation(program,"alpha");
        require(location>=0,"alpha uniform");
        glUniform1f(location,0.7f);
    }
    GLuint solid=glCreateProgram();
    GLuint solid_fs=shader(GL_FRAGMENT_SHADER,"precision mediump float; void main(){gl_FragColor=vec4(0.,0.,0.,1.);}");
    glAttachShader(solid,vs); glAttachShader(solid,solid_fs);
    glBindAttribLocation(solid,0,"pos"); glLinkProgram(solid);
    glGetProgramiv(solid,GL_LINK_STATUS,&linked); require(linked,"solid link");
    const GLfloat positions[]={-1,-1, 1,-1, -1,1, 1,1};
    glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,0,positions); glEnableVertexAttribArray(0);
    GLuint tex[2], fbo; glGenTextures(2,tex);
    struct gbm_device *gbm=NULL;
    struct gbm_bo *linear_target=NULL;
    EGLImageKHR linear_image=EGL_NO_IMAGE_KHR;
    int gpu=-1;
    unsigned char *pixels=malloc((size_t)width*height*4); require(pixels!=NULL,"pixels");
    for (int i=0; i<width*height; i++) { pixels[i*4]=(i*13)%256; pixels[i*4+1]=(i/width)%256; pixels[i*4+2]=127; pixels[i*4+3]=255; }
    for (int i=0;i<2;i++) {
        glBindTexture(GL_TEXTURE_2D,tex[i]);
        GLint filter=!strcmp(mode,"nearest") ? GL_NEAREST:GL_LINEAR;
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,filter);
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,filter);
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
        if (i && linear) {
            const char *node=getenv("FD2D_RENDER_NODE");
            require(node != NULL, "set FD2D_RENDER_NODE from DRM capability probe");
            gpu=open(node,O_RDWR|O_CLOEXEC);
            require(gpu>=0,"GPU fd");
            gbm=gbm_create_device(gpu);
            require(gbm!=NULL,"GBM");
            const uint64_t modifier=DRM_FORMAT_MOD_LINEAR;
            const uint32_t target_fourcc=rgb565_target ? DRM_FORMAT_RGB565 : DRM_FORMAT_ABGR8888;
            linear_target=gbm_bo_create_with_modifiers2(gbm,width,height,
                target_fourcc,&modifier,1,GBM_BO_USE_RENDERING);
            require(linear_target && gbm_bo_get_modifier(linear_target)==modifier,"linear target");
            int fd=gbm_bo_get_fd(linear_target);
            require(fd>=0,"DMA-BUF fd");
            EGLint attrs[]={EGL_WIDTH,width,EGL_HEIGHT,height,
                EGL_LINUX_DRM_FOURCC_EXT,target_fourcc,
                EGL_DMA_BUF_PLANE0_FD_EXT,fd,EGL_DMA_BUF_PLANE0_OFFSET_EXT,0,
                EGL_DMA_BUF_PLANE0_PITCH_EXT,gbm_bo_get_stride(linear_target),EGL_NONE};
            PFNEGLCREATEIMAGEKHRPROC create_image=(void *)eglGetProcAddress("eglCreateImageKHR");
            PFNGLEGLIMAGETARGETTEXTURE2DOESPROC image_texture=
                (void *)eglGetProcAddress("glEGLImageTargetTexture2DOES");
            require(create_image && image_texture,"EGL image entrypoints");
            linear_image=create_image(d,EGL_NO_CONTEXT,EGL_LINUX_DMA_BUF_EXT,NULL,attrs);
            close(fd);
            require(linear_image!=EGL_NO_IMAGE_KHR,"linear EGL image");
            image_texture(GL_TEXTURE_2D,linear_image);
        } else {
            if (i && rgb565_target)
                glTexImage2D(GL_TEXTURE_2D,0,GL_RGB,width,height,0,GL_RGB,GL_UNSIGNED_SHORT_5_6_5,NULL);
            else
                glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,width,height,0,GL_RGBA,GL_UNSIGNED_BYTE,i ? NULL:pixels);
        }
    }
    free(pixels);
    printf("{\"clear_only\":%s,\"target_cpp\":%d}\n", clear_only ? "true" : "false", rgb565_target ? 2 : 4);
    glGenFramebuffers(1,&fbo); glBindFramebuffer(GL_FRAMEBUFFER,fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,tex[1],0);
    GLuint depth_buffer = 0;
    PFNGLDISCARDFRAMEBUFFEREXTPROC discard_depth = NULL;
    if (depth_test) {
        discard_depth = (void *)eglGetProcAddress("glDiscardFramebufferEXT");
        require(discard_depth != NULL, "depth discard entrypoint");
        glGenRenderbuffers(1, &depth_buffer);
        glBindRenderbuffer(GL_RENDERBUFFER, depth_buffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8_OES, width, height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depth_buffer);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, depth_buffer);
        glEnable(GL_DEPTH_TEST);
        glDepthFunc(GL_LEQUAL);
        glDepthMask(GL_TRUE);
        glClearDepthf(1.0f);
    }
    require(glCheckFramebufferStatus(GL_FRAMEBUFFER)==GL_FRAMEBUFFER_COMPLETE,"framebuffer");
    glBindTexture(GL_TEXTURE_2D,tex[0]); glViewport(0,0,width,height);
    glBlendFunc(GL_ONE,GL_ONE_MINUS_SRC_ALPHA); glClearColor(0,0,0,1);
    for(int clear_quad=0;clear_quad<=1;clear_quad++) for(int layers=1;layers<=4;layers*=2) for(int blend=0;blend<=1;blend++) {
        if (only_layers && (clear_quad || !blend || layers != only_layers))
            continue;
        double samples[40],sum=0,submission_sum=0,fence_sum=0;
        double phase_start=now();
        for(int f=-5;f<frames;f++) {
            double start=now();
            if(clear_quad) {
                glDisable(GL_BLEND);glUseProgram(solid);
                glDrawArrays(GL_TRIANGLE_STRIP,0,4);
            } else glClear(GL_COLOR_BUFFER_BIT | (depth_test ? GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT : 0));
            glUseProgram(program);
            if(blend) glEnable(GL_BLEND); else glDisable(GL_BLEND);
            for(int l=0;l<(clear_only ? 0 : layers*repeats);l++) {
                if (uniform_updates)
                    glUniform2f(shift_location, (l & 1) ? 1.0f/1024.0f : 0.0f, 0.0f);
                glDrawArrays(GL_TRIANGLE_STRIP,0,4);
            }
            if (depth_test) {
                const GLenum attachments[] = {GL_DEPTH_ATTACHMENT, GL_STENCIL_ATTACHMENT};
                discard_depth(GL_FRAMEBUFFER, 2, attachments);
            }
            double submitted = now();
            double completed = 0;
            if (fence_probe) {
                PFNEGLCREATESYNCKHRPROC create_sync = (void *)eglGetProcAddress("eglCreateSyncKHR");
                PFNEGLDUPNATIVEFENCEFDANDROIDPROC dup_fence = (void *)eglGetProcAddress("eglDupNativeFenceFDANDROID");
                PFNEGLDESTROYSYNCKHRPROC destroy_sync = (void *)eglGetProcAddress("eglDestroySyncKHR");
                require(create_sync && dup_fence && destroy_sync, "native fence functions");
                EGLSyncKHR sync = create_sync(d, EGL_SYNC_NATIVE_FENCE_ANDROID, NULL);
                require(sync != EGL_NO_SYNC_KHR, "native fence creation");
                glFlush();
                int fd = dup_fence(d, sync);
                require(fd >= 0, "native fence export");
                struct pollfd waiter = {.fd=fd,.events=POLLIN};
                require(poll(&waiter, 1, 2000) == 1 && (waiter.revents & POLLIN), "fence completion");
                struct sync_file_info info = {0};
                require(ioctl(fd, SYNC_IOC_FILE_INFO, &info) == 0 && info.status == 1 &&
                        info.num_fences > 0 && info.num_fences <= 64, "signaled sync file info");
                struct sync_fence_info fences[64];
                memset(fences, 0, sizeof(fences));
                info.sync_fence_info = (uint64_t)(uintptr_t)fences;
                require(ioctl(fd, SYNC_IOC_FILE_INFO, &info) == 0, "fence timestamp info");
                uint64_t timestamp = 0;
                for (unsigned i=0; i<info.num_fences; i++) {
                    require(fences[i].status == 1, "successful individual fence");
                    if (fences[i].timestamp_ns > timestamp) timestamp = fences[i].timestamp_ns;
                }
                completed = timestamp / 1e9;
                require(completed >= start && completed <= now(), "monotonic completion timestamp");
                close(fd);
                require(destroy_sync(d, sync), "native fence destroy");
            }
            glFinish();
            if (f>=0) {
                submission_sum += (submitted-start)*1000;
                if (fence_probe) fence_sum += (completed-start)*1000;
            }
            require(glGetError()==GL_NO_ERROR,"render");
            if(f>=0) {samples[f]=(now()-start)*1000;sum+=samples[f];}
        }
        if (fence_probe)
            printf("{\"cpu_submission_mean_ms\":%.4f,\"native_fence_completion_mean_ms\":%.4f}\n", submission_sum/frames, fence_sum/frames);
        qsort(samples,frames,sizeof(double),compare);
        unsigned char pixel[4];
        glReadPixels(0,0,1,1,GL_RGBA,GL_UNSIGNED_BYTE,pixel);
        int expected=89;
        if(blend && layers==2) expected=116;
        if(blend && layers==4) expected=126;
        if (blend && repeats > 1) {
            double value = 0.0;
            for (int layer = 0; layer < layers*repeats; layer++)
                value = (127.0/255.0)*0.7 + value*0.3;
            expected = (int)(value*255.0+0.5);
        }
        if (!strcmp(mode,"alu")) {
            double blue=127.0/255.0, value=0.0;
            for(int step=0;step<16;step++) blue=blue*0.9+0.03;
            for(int layer=0;layer<(blend?layers*repeats:1);layer++) value=blue*0.7+value*0.3;
            expected=(int)(value*255.0+0.5);
        }
        if (rgb565_target) {
            double value = 0.0;
            for (int layer=0; layer<(blend ? layers*repeats : 1); layer++) {
                value = (127.0/255.0)*0.7 + (blend ? value*0.3 : 0.0);
                value = (int)(value*31.0+0.5)/31.0;
            }
            expected = (int)(value*255.0+0.5);
        }
        if (clear_only) expected = 0;
        require(abs((int)pixel[2]-expected)<=2,"rendered blue pixel");
        printf("{\"clear_quad\":%d,\"layers\":%d,\"blend\":%d,\"frames\":%d,\"start_monotonic\":%.9f,\"end_monotonic\":%.9f,\"mean_ms\":%.4f,\"p50_ms\":%.4f,\"p95_ms\":%.4f,\"fps\":%.3f}\n",clear_quad,layers,blend,frames,phase_start,now(),sum/frames,samples[frames/2],samples[(frames-1)*95/100],1000*frames/sum);
        fflush(stdout);
    }
    if (depth_buffer) glDeleteRenderbuffers(1, &depth_buffer);
    glDeleteFramebuffers(1,&fbo); glDeleteTextures(2,tex); glDeleteProgram(program);
    glDeleteShader(vs);glDeleteShader(fs);
    glDeleteProgram(solid);glDeleteShader(solid_fs);
    if (linear_target) {
        PFNEGLDESTROYIMAGEKHRPROC destroy_image=(void *)eglGetProcAddress("eglDestroyImageKHR");
        destroy_image(d,linear_image);
        gbm_bo_destroy(linear_target);
    }
    eglMakeCurrent(d,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT);
    eglDestroyContext(d,ctx);eglTerminate(d);
    if(gbm) gbm_device_destroy(gbm);
    if(gpu>=0) close(gpu);
    return 0;
}
