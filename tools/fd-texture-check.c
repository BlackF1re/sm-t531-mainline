// SPDX-License-Identifier: MIT
// Offscreen FD305 texture upload/readback checks; never change shell settings.
#define _POSIX_C_SOURCE 200809L
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#include <drm_fourcc.h>
#include <fcntl.h>
#include <gbm.h>
#include <errno.h>
#include <linux/dma-buf.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <xf86drm.h>
#include <xf86drmMode.h>

static EGLDisplay display;
static struct gbm_device *gbm;
static double now(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}

static void require(int ok, const char *what)
{
    if (!ok) { fprintf(stderr, "%s failed (GL %#x)\n", what, glGetError()); exit(1); }
}

struct kms_source {
    int fd, prime;
    uint32_t handle, pitch;
    size_t size;
    void *map;
};

static void kms_sync(struct kms_source *source, uint64_t flags)
{
    struct dma_buf_sync sync = {.flags = flags | DMA_BUF_SYNC_WRITE};
    int ret;
    do {
        ret = ioctl(source->prime, DMA_BUF_IOCTL_SYNC, &sync);
    } while (ret < 0 && errno == EINTR);
    require(ret == 0, "KMS DMA-BUF CPU synchronization");
}

static void kms_write(struct kms_source *source, int x, int y, int width,
                       int height, const unsigned char *data)
{
    kms_sync(source, DMA_BUF_SYNC_START);
    for (int row = 0; row < height; row++)
        memcpy((char *)source->map + (size_t)(y + row) * source->pitch + x * 4,
               data + (size_t)row * width * 4, (size_t)width * 4);
    kms_sync(source, DMA_BUF_SYNC_END);
}

static void kms_create(struct kms_source *source, int width, int height)
{
    const char *node = getenv("FD_TEXTURE_KMS_NODE");
    require(node != NULL, "set FD_TEXTURE_KMS_NODE from DRM capability probe");
    source->fd = open(node, O_RDWR | O_CLOEXEC);
    require(source->fd >= 0, "native KMS fd");
    drmVersion *version = drmGetVersion(source->fd);
    require(version && !strcmp(version->name, "msm"), "unified MSM driver");
    drmFreeVersion(version);
    drmModeRes *resources = drmModeGetResources(source->fd);
    require(resources && resources->count_crtcs > 0, "KMS resources");
    drmModeFreeResources(resources);
    struct drm_mode_create_dumb bo = {.width = width, .height = height, .bpp = 32};
    require(drmIoctl(source->fd, DRM_IOCTL_MODE_CREATE_DUMB, &bo) == 0, "KMS dumb BO");
    source->handle = bo.handle;
    source->pitch = bo.pitch;
    source->size = bo.size;
    struct drm_mode_map_dumb mapping = {.handle = bo.handle};
    require(drmIoctl(source->fd, DRM_IOCTL_MODE_MAP_DUMB, &mapping) == 0, "KMS BO map");
    source->map = mmap(NULL, bo.size, PROT_READ | PROT_WRITE, MAP_SHARED,
                       source->fd, mapping.offset);
    require(source->map != MAP_FAILED, "KMS BO mmap");
    require(drmPrimeHandleToFD(source->fd, bo.handle, DRM_CLOEXEC,
                                &source->prime) == 0, "KMS BO export");
}

static void kms_destroy(struct kms_source *source)
{
    munmap(source->map, source->size);
    close(source->prime);
    struct drm_mode_destroy_dumb bo = {.handle = source->handle};
    require(drmIoctl(source->fd, DRM_IOCTL_MODE_DESTROY_DUMB, &bo) == 0,
            "KMS BO destroy");
    close(source->fd);
}

static GLuint shader(GLenum type, const char *source)
{
    GLuint id = glCreateShader(type);
    glShaderSource(id, 1, &source, NULL);
    glCompileShader(id);
    GLint ok;
    glGetShaderiv(id, GL_COMPILE_STATUS, &ok);
    require(ok, "shader");
    return id;
}

static void pattern(unsigned char *pixel, int x, int y, unsigned seed, GLenum format)
{
    pixel[0] = (x * 13 + y * 7 + seed * 31) & 255;
    pixel[1] = (x * 3 + y * 17 + seed * 11) & 255;
    pixel[2] = (x * 19 + y * 5 + seed * 29) & 255;
    pixel[3] = 255;
    if (getenv("FD_TEXTURE_VARY_ALPHA") &&
        (format == GL_RGBA || format == GL_BGRA_EXT))
        pixel[3] = (x * 17 + y * 9 + seed * 7) & 255;
    if (format == GL_ALPHA) {
        pixel[3] = pixel[0];
        pixel[0] = pixel[1] = pixel[2] = 0;
    } else if (format == GL_LUMINANCE) {
        pixel[1] = pixel[2] = pixel[0];
    }
}

static void pack(unsigned char *upload, const unsigned char *pixel, GLenum format)
{
    if (format == GL_ALPHA || format == GL_LUMINANCE) {
        upload[0] = pixel[format == GL_ALPHA ? 3 : 0];
    } else {
        upload[0] = pixel[format == GL_BGRA_EXT ? 2 : 0];
        upload[1] = pixel[1];
        upload[2] = pixel[format == GL_BGRA_EXT ? 0 : 2];
        upload[3] = pixel[3];
    }
}

static void check_pixels(unsigned char *actual, const unsigned char *expected,
                         int width, int height, int update, const char *format)
{
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, actual);
    require(glGetError() == GL_NO_ERROR, "readback");
    for (int i = 0; i < width * height * 4; i++) {
        if (abs((int)actual[i] - expected[i]) > 1) {
            fprintf(stderr, "INVALID %s %dx%d update=%d at %d,%d channel=%d: %u != %u\n",
                    format, width, height, update, i / 4 % width, i / 4 / width,
                    i % 4, actual[i], expected[i]);
            int p = i & ~3;
            fprintf(stderr, "actual RGBA=%u,%u,%u,%u expected=%u,%u,%u,%u\n",
                    actual[p], actual[p + 1], actual[p + 2], actual[p + 3],
                    expected[p], expected[p + 1], expected[p + 2], expected[p + 3]);
            exit(1);
        }
    }
    printf("{\"format\":\"%s\",\"width\":%d,\"height\":%d,\"update\":%d,\"checked_pixels\":%d,\"ok\":true}\n",
           format, width, height, update, width * height);
    fflush(stdout);
}

static void test_size(int width, int height, GLenum upload_format)
{
    const char *format = upload_format == GL_BGRA_EXT ? "BGRA" :
        upload_format == GL_ALPHA ? "A8" : upload_format == GL_LUMINANCE ? "L8" : "RGBA";
    int bytes = upload_format == GL_ALPHA || upload_format == GL_LUMINANCE ? 1 : 4;
    int inflight = getenv("FD_TEXTURE_INFLIGHT") != NULL;
    require(!inflight || (!getenv("FD_TEXTURE_LINEAR_SOURCE") &&
                         !getenv("FD_TEXTURE_LINEAR_TARGET")),
            "inflight test uses private GL textures");
    size_t size = (size_t)width * height * 4;
    unsigned char *snapshots = inflight ? malloc(size * 7) : NULL;
    GLuint saved[7] = {0};
    if (inflight) {
        require(snapshots != NULL, "inflight snapshots");
        glGenTextures(7, saved);
    }
    unsigned char *expected = malloc(size), *upload = malloc(size), *actual = malloc(size);
    require(expected && upload && actual, "allocation");
    for (int y = 0; y < height; y++) for (int x = 0; x < width; x++)
        pattern(expected + ((size_t)y * width + x) * 4, x, y, 0, upload_format);
    for (size_t i = 0; i < size; i += 4) {
        pack(upload + i / 4 * bytes, expected + i, upload_format);
    }

    GLuint textures[2], fbo;
    struct gbm_bo *bos[2] = {0};
    struct kms_source source = {0};
    int native_source = getenv("FD_TEXTURE_KMS_SOURCE") != NULL;
    EGLImageKHR images[2] = {EGL_NO_IMAGE_KHR, EGL_NO_IMAGE_KHR};
    glGenTextures(2, textures);
    for (int i = 0; i < 2; i++) {
        glBindTexture(GL_TEXTURE_2D, textures[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        if (!i && native_source) {
            kms_create(&source, width, height);
            kms_write(&source, 0, 0, width, height, upload);
            EGLint attrs[] = {
                EGL_WIDTH, width, EGL_HEIGHT, height,
                EGL_LINUX_DRM_FOURCC_EXT,
                upload_format == GL_BGRA_EXT ? DRM_FORMAT_ARGB8888 : DRM_FORMAT_ABGR8888,
                EGL_DMA_BUF_PLANE0_FD_EXT, source.prime,
                EGL_DMA_BUF_PLANE0_OFFSET_EXT, 0,
                EGL_DMA_BUF_PLANE0_PITCH_EXT, source.pitch,
                EGL_NONE
            };
            PFNEGLCREATEIMAGEKHRPROC create_image = (void *)eglGetProcAddress("eglCreateImageKHR");
            PFNGLEGLIMAGETARGETTEXTURE2DOESPROC image_texture =
                (void *)eglGetProcAddress("glEGLImageTargetTexture2DOES");
            require(create_image && image_texture, "EGL image entrypoints");
            images[i] = create_image(display, EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT, NULL, attrs);
            require(images[i] != EGL_NO_IMAGE_KHR, "native KMS EGL image import");
            image_texture(GL_TEXTURE_2D, images[i]);
        } else if (getenv(i ? "FD_TEXTURE_LINEAR_TARGET" : "FD_TEXTURE_LINEAR_SOURCE")) {
            const uint64_t modifier = DRM_FORMAT_MOD_LINEAR;
            bos[i] = gbm_bo_create_with_modifiers2(gbm, width, height,
                DRM_FORMAT_ABGR8888, &modifier, 1, GBM_BO_USE_RENDERING);
            require(bos[i] && gbm_bo_get_modifier(bos[i]) == modifier, "linear GBM BO");
            int fd = gbm_bo_get_fd(bos[i]);
            require(fd >= 0, "DMA-BUF fd");
            EGLint attrs[] = {
                EGL_WIDTH, width, EGL_HEIGHT, height,
                EGL_LINUX_DRM_FOURCC_EXT, DRM_FORMAT_ABGR8888,
                EGL_DMA_BUF_PLANE0_FD_EXT, fd,
                EGL_DMA_BUF_PLANE0_OFFSET_EXT, 0,
                EGL_DMA_BUF_PLANE0_PITCH_EXT, gbm_bo_get_stride(bos[i]),
                EGL_NONE
            };
            PFNEGLCREATEIMAGEKHRPROC create_image = (void *)eglGetProcAddress("eglCreateImageKHR");
            PFNGLEGLIMAGETARGETTEXTURE2DOESPROC image_texture =
                (void *)eglGetProcAddress("glEGLImageTargetTexture2DOES");
            require(create_image && image_texture, "EGL image entrypoints");
            images[i] = create_image(display, EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT, NULL, attrs);
            close(fd);
            require(images[i] != EGL_NO_IMAGE_KHR, "linear EGL image");
            image_texture(GL_TEXTURE_2D, images[i]);
            if (!i) glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height,
                                    upload_format, GL_UNSIGNED_BYTE, upload);
        } else {
            glTexImage2D(GL_TEXTURE_2D, 0, i ? GL_RGBA : upload_format, width, height,
                         0, i ? GL_RGBA : upload_format, GL_UNSIGNED_BYTE, i ? NULL : upload);
        }
    }
    require(glGetError() == GL_NO_ERROR, "texture creation");
    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, textures[1], 0);
    require(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE, "framebuffer");
    glBindTexture(GL_TEXTURE_2D, textures[0]);
    glViewport(0, 0, width, height);

    for (int update = 0; update < 7; update++) {
        if (update) {
            // Unaligned, overlapping and edge-touching partial uploads. Keep
            // every other pixel in the CPU reference to catch lost contents.
            int whole = update == 6 || getenv("FD_TEXTURE_FULL_UPDATES");
            int w = whole ? width : 13 + update * 3;
            int h = whole ? height : 7 + update * 2;
            int left = update == 5 ? width - w : (update * 17) % (width - w + 1);
            int top = update == 5 ? height - h : (update * 11) % (height - h + 1);
            for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
                unsigned char *p = expected + ((size_t)(top + y) * width + left + x) * 4;
                unsigned char *u = upload + ((size_t)y * w + x) * bytes;
                pattern(p, left + x, top + y, update, upload_format);
                pack(u, p, upload_format);
            }
            double start = now();
            if (native_source) {
                kms_write(&source, left, top, w, h, upload);
                PFNGLEGLIMAGETARGETTEXTURE2DOESPROC image_texture =
                    (void *)eglGetProcAddress("glEGLImageTargetTexture2DOES");
                image_texture(GL_TEXTURE_2D, images[0]);
            } else {
                glTexSubImage2D(GL_TEXTURE_2D, 0, left, top, w, h,
                                upload_format, GL_UNSIGNED_BYTE, upload);
            }
            if (inflight)
                printf("{\"phase\":\"upload\",\"format\":\"%s\",\"width\":%d,\"height\":%d,\"update\":%d,\"cpu_ms\":%.6f}\n",
                       format, width, height, update, (now()-start)*1000);
        }
        if (inflight) {
            glBindTexture(GL_TEXTURE_2D, saved[update]);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0,
                         GL_RGBA, GL_UNSIGNED_BYTE, NULL);
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                                   GL_TEXTURE_2D, saved[update], 0);
            require(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE,
                    "inflight framebuffer");
            glBindTexture(GL_TEXTURE_2D, textures[0]);
            memcpy(snapshots + update * size, expected, size);
        }
        glClearColor(1, 0, 1, 1);
        glClear(GL_COLOR_BUFFER_BIT);
        for (int repeat = 0; repeat < (inflight ? 4 : 1); repeat++)
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        require(glGetError() == GL_NO_ERROR, "draw");
        if (inflight)
            glFlush();
        else
            check_pixels(actual, expected, width, height, update, format);
    }
    if (inflight) {
        for (int update = 0; update < 7; update++) {
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                                   GL_TEXTURE_2D, saved[update], 0);
            check_pixels(actual, snapshots + update * size, width, height, update, format);
        }
        glDeleteTextures(7, saved);
        free(snapshots);
    }
    glDeleteFramebuffers(1, &fbo);
    glDeleteTextures(2, textures);
    PFNEGLDESTROYIMAGEKHRPROC destroy_image = (void *)eglGetProcAddress("eglDestroyImageKHR");
    for (int i = 0; i < 2; i++) if (bos[i]) {
        destroy_image(display, images[i]);
        gbm_bo_destroy(bos[i]);
    }
    if (native_source) {
        destroy_image(display, images[0]);
        kms_destroy(&source);
    }
    free(actual); free(upload); free(expected);
}

int main(int argc, char **argv)
{
    require(argc == 1 || argc == 3, "usage: fd-texture-check [WIDTH HEIGHT]");
    int width = argc == 3 ? atoi(argv[1]) : 257;
    int height = argc == 3 ? atoi(argv[2]) : 131;
    require(width >= 32 && width <= 1280 && height >= 32 && height <= 1280, "dimensions");
    char compatible[128] = {0};
    FILE *board = fopen("/proc/device-tree/compatible", "r");
    require(board && fread(compatible, 1, sizeof(compatible) - 1, board), "board");
    fclose(board);
    require(!strcmp(compatible, "samsung,matisse3g"), "SM-T531");
    PFNEGLGETPLATFORMDISPLAYEXTPROC platform = (void *)eglGetProcAddress("eglGetPlatformDisplayEXT");
    require(platform != NULL, "EGL platform");
    display = platform(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, NULL);
    require(eglInitialize(display, NULL, NULL) && eglBindAPI(EGL_OPENGL_ES_API), "EGL init");
    EGLint attrs[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
    EGLContext context = eglCreateContext(display, EGL_NO_CONFIG_KHR, EGL_NO_CONTEXT, attrs);
    require(context != EGL_NO_CONTEXT, "context");
    require(eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, context), "make current");
    const char *renderer = (const char *)glGetString(GL_RENDERER);
    require(renderer && strstr(renderer, "FD305"), "FD305");
    int gpu = -1;
    if (getenv("FD_TEXTURE_LINEAR_SOURCE") || getenv("FD_TEXTURE_LINEAR_TARGET")) {
        const char *node = getenv("FD_TEXTURE_RENDER_NODE");
        require(node != NULL, "set FD_TEXTURE_RENDER_NODE from DRM capability probe");
        gpu = open(node, O_RDWR | O_CLOEXEC);
        require(gpu >= 0, "GPU fd");
        gbm = gbm_create_device(gpu);
        require(gbm != NULL, "GBM");
    }
    printf("{\"renderer\":\"%s\",\"mesa\":\"%s\",\"debug\":\"%s\",\"linear_source\":%s,\"linear_target\":%s,\"kms_source\":%s}\n",
           renderer, glGetString(GL_VERSION), getenv("FD_MESA_DEBUG") ?: "",
           getenv("FD_TEXTURE_LINEAR_SOURCE") ? "true" : "false",
           getenv("FD_TEXTURE_LINEAR_TARGET") ? "true" : "false",
           getenv("FD_TEXTURE_KMS_SOURCE") ? "true" : "false");
    GLuint vs = shader(GL_VERTEX_SHADER,
        "attribute vec2 pos; varying vec2 uv; void main(){uv=(pos+1.0)*0.5; gl_Position=vec4(pos,0.,1.);}");
    GLuint fs = shader(GL_FRAGMENT_SHADER,
        "precision mediump float; varying vec2 uv; uniform sampler2D tex; void main(){gl_FragColor=texture2D(tex,uv);}");
    GLuint program = glCreateProgram();
    glAttachShader(program, vs); glAttachShader(program, fs);
    glBindAttribLocation(program, 0, "pos"); glLinkProgram(program);
    GLint ok;
    glGetProgramiv(program, GL_LINK_STATUS, &ok); require(ok, "link");
    glUseProgram(program);
    const GLfloat vertices[] = {-1,-1, 1,-1, -1,1, 1,1};
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, vertices);
    glEnableVertexAttribArray(0);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    test_size(width, height, GL_RGBA);
    if (argc == 1) test_size(1280, 800, GL_RGBA);
    const char *extensions = (const char *)glGetString(GL_EXTENSIONS);
    if (extensions && strstr(extensions, "GL_EXT_texture_format_BGRA8888")) {
        test_size(width, height, GL_BGRA_EXT);
        if (argc == 1) test_size(1280, 800, GL_BGRA_EXT);
    }
    // The explicit GBM source has ABGR8888 storage. ES2 does not permit
    // GL_ALPHA/LUMINANCE subimage uploads into that RGBA EGL image.
    if (!getenv("FD_TEXTURE_LINEAR_SOURCE") && !getenv("FD_TEXTURE_KMS_SOURCE")) {
        test_size(width, height, GL_ALPHA);
        test_size(width, height, GL_LUMINANCE);
        if (argc == 1) {
            test_size(1280, 800, GL_ALPHA);
            test_size(1280, 800, GL_LUMINANCE);
        }
    } else {
        puts("{\"skipped_formats\":[\"A8\",\"L8\"],\"reason\":\"explicit source uses 32-bit color storage\"}");
    }
    glDeleteProgram(program); glDeleteShader(vs); glDeleteShader(fs);
    eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglDestroyContext(display, context); eglTerminate(display);
    if (gbm) gbm_device_destroy(gbm);
    if (gpu >= 0) close(gpu);
    return 0;
}
