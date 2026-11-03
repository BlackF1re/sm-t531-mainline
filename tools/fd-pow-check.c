// SPDX-License-Identifier: MIT
// Offscreen highp pow reference and timing probe for Adreno 305.
#define _POSIX_C_SOURCE 200809L
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
static void need(int ok,const char *s){if(!ok){fprintf(stderr,"FAIL %s\n",s);exit(1);}}
static double now(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec+t.tv_nsec*1e-9;}
static GLuint shader(GLenum type,const char *src){GLuint s=glCreateShader(type);glShaderSource(s,1,&src,0);glCompileShader(s);GLint ok;glGetShaderiv(s,GL_COMPILE_STATUS,&ok);if(!ok){char l[4096];glGetShaderInfoLog(s,sizeof l,0,l);fprintf(stderr,"%s\n",l);}need(ok,"compile");return s;}
int main(void){
 PFNEGLGETPLATFORMDISPLAYEXTPROC get=(void*)eglGetProcAddress("eglGetPlatformDisplayEXT");need(get!=0,"platform");EGLDisplay d=get(EGL_PLATFORM_SURFACELESS_MESA,EGL_DEFAULT_DISPLAY,0);need(eglInitialize(d,0,0),"initialize");need(eglBindAPI(EGL_OPENGL_ES_API),"api");EGLint a[]={EGL_CONTEXT_CLIENT_VERSION,2,EGL_NONE};EGLContext c=eglCreateContext(d,EGL_NO_CONFIG_KHR,EGL_NO_CONTEXT,a);need(c!=EGL_NO_CONTEXT,"context");need(eglMakeCurrent(d,EGL_NO_SURFACE,EGL_NO_SURFACE,c),"current");need(strstr((const char*)glGetString(GL_RENDERER),"FD305")!=0,"hardware");
 GLuint vs=shader(GL_VERTEX_SHADER,"attribute vec2 pos;void main(){gl_Position=vec4(pos,0.,1.);}");
 GLuint fs=shader(GL_FRAGMENT_SHADER,"precision highp float;uniform float exponent;uniform float split;void main(){vec2 uv=gl_FragCoord.xy/vec2(1280.,800.);vec3 x=vec3(uv,0.25+0.5*uv.x*uv.y);float e=exponent;if(split>0.5&&uv.x<0.5)e=1.;gl_FragColor=vec4(pow(x,vec3(e)),1.);}");
 GLuint p=glCreateProgram();glAttachShader(p,vs);glAttachShader(p,fs);glBindAttribLocation(p,0,"pos");glLinkProgram(p);GLint ok;glGetProgramiv(p,GL_LINK_STATUS,&ok);need(ok,"link");glUseProgram(p);GLint ex=glGetUniformLocation(p,"exponent"),sp=glGetUniformLocation(p,"split");
 GLuint tex,fbo;glGenTextures(1,&tex);glBindTexture(GL_TEXTURE_2D,tex);glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,1280,800,0,GL_RGBA,GL_UNSIGNED_BYTE,0);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);glGenFramebuffers(1,&fbo);glBindFramebuffer(GL_FRAMEBUFFER,fbo);glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,tex,0);need(glCheckFramebufferStatus(GL_FRAMEBUFFER)==GL_FRAMEBUFFER_COMPLETE,"fbo");
 GLfloat verts[]={-1,-1,1,-1,-1,1,1,1};glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,0,verts);glEnableVertexAttribArray(0);glViewport(0,0,1280,800);glDisable(GL_DITHER);unsigned char *pixels=malloc(1280*800*4);need(pixels!=0,"alloc");
 float ee[]={1,.5,2,2,1,0,-1};int ss[]={0,0,0,1,0,0,0};
 for(unsigned test=0;test<sizeof ee/sizeof ee[0];test++){
  glUniform1f(ex,ee[test]);glUniform1f(sp,ss[test]);for(int i=0;i<5;i++){glClear(GL_COLOR_BUFFER_BIT);glDrawArrays(GL_TRIANGLE_STRIP,0,4);glFinish();}
  double start=now();for(int i=0;i<40;i++){glClear(GL_COLOR_BUFFER_BIT);glDrawArrays(GL_TRIANGLE_STRIP,0,4);glFinish();}double end=now();
  glReadPixels(0,0,1280,800,GL_RGBA,GL_UNSIGNED_BYTE,pixels);need(glGetError()==GL_NO_ERROR,"read");int max=0,checked=0;
  for(int y=0;y<800;y+=7)for(int x=0;x<1280;x+=7){double u=(x+.5)/1280.,v=(y+.5)/800.,e=ss[test]&&u<.5?1:ee[test],base[]={u,v,.25+.5*u*v};for(int k=0;k<4;k++){double expected=k==3?1:fmin(1.,pow(base[k],e));int delta=abs(pixels[(y*1280+x)*4+k]-(int)lround(255*expected));if(delta>max)max=delta;}checked++;}
  printf("{\"exponent\":%.3f,\"split\":%d,\"mean_ms\":%.5f,\"start_monotonic\":%.9f,\"end_monotonic\":%.9f,\"max_error\":%d,\"checked\":%d}\n",ee[test],ss[test],(end-start)*1000/40,start,end,max,checked);fflush(stdout);need(max<=2,"pixel reference");
 }
 free(pixels);glDeleteFramebuffers(1,&fbo);glDeleteTextures(1,&tex);glDeleteProgram(p);glDeleteShader(vs);glDeleteShader(fs);eglMakeCurrent(d,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT);eglDestroyContext(d,c);eglTerminate(d);return 0;
}
