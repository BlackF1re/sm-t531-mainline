// SPDX-License-Identifier: MIT
// Small offscreen precision/branch checks; no compositor or modesetting.
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static void require(int ok, const char *s) { if (!ok) { fprintf(stderr,"FAILED: %s\n",s); exit(1); } }
static GLuint shader(GLenum kind,const char *text) {
 GLuint s=glCreateShader(kind); glShaderSource(s,1,&text,NULL); glCompileShader(s);
 GLint ok=0;glGetShaderiv(s,GL_COMPILE_STATUS,&ok);
 if (!ok) { char log[4096];glGetShaderInfoLog(s,sizeof(log),NULL,log);fprintf(stderr,"%s\n",log); }
 require(ok,"shader compilation");return s;
}
int main(void) {
 PFNEGLGETPLATFORMDISPLAYEXTPROC platform=(void *)eglGetProcAddress("eglGetPlatformDisplayEXT");require(platform!=NULL,"surfaceless entrypoint");
 EGLDisplay d=platform(EGL_PLATFORM_SURFACELESS_MESA,EGL_DEFAULT_DISPLAY,NULL);require(eglInitialize(d,NULL,NULL),"EGL initialize");require(eglBindAPI(EGL_OPENGL_ES_API),"ES API");
 EGLint attr[]={EGL_CONTEXT_CLIENT_VERSION,2,EGL_NONE};EGLContext ctx=eglCreateContext(d,EGL_NO_CONFIG_KHR,EGL_NO_CONTEXT,attr);require(ctx!=EGL_NO_CONTEXT,"context");require(eglMakeCurrent(d,EGL_NO_SURFACE,EGL_NO_SURFACE,ctx),"current");
 const char *renderer=(const char *)glGetString(GL_RENDERER);require(renderer && strstr(renderer,"FD305"),"FD305 hardware");
 printf("{\"renderer\":\"%s\"}\n",renderer);
 GLuint texture,fbo;glGenTextures(1,&texture);glBindTexture(GL_TEXTURE_2D,texture);glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,32,32,0,GL_RGBA,GL_UNSIGNED_BYTE,NULL);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
 glGenFramebuffers(1,&fbo);glBindFramebuffer(GL_FRAMEBUFFER,fbo);glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,texture,0);require(glCheckFramebufferStatus(GL_FRAMEBUFFER)==GL_FRAMEBUFFER_COMPLETE,"FBO");glViewport(0,0,32,32);glDisable(GL_DITHER);
 const char *names[]={"mediump-arithmetic","mediump-comparison","mediump-sqrt","highp-cancellation","mediump-loop"};
 const char *bodies[]={
 "mediump float x=gl_FragCoord.x/32.0,y=gl_FragCoord.y/32.0; mediump float v=x*(0.1+y*0.2)+0.3;",
 "mediump float x=gl_FragCoord.x/32.0,y=gl_FragCoord.y/32.0; mediump float v; if(x<0.5) v=x>y?0.25:0.5; else v=x==y?0.75:1.0;",
 "mediump float x=gl_FragCoord.x/32.0; mediump float v=sqrt(x*0.25+0.25)*0.8;",
 "highp float v=(big+gl_FragCoord.x/64.0)-big;",
 "mediump float x=gl_FragCoord.x/32.0; mediump float v=0.0; for(int i=0;i<4;i++) v=v*0.5+x*0.125;"};
 GLuint vs=shader(GL_VERTEX_SHADER,"attribute vec2 pos;void main(){gl_Position=vec4(pos,0.,1.);}");
 const GLfloat verts[]={-1,-1,1,-1,-1,1,1,1};
 for (int test=0;test<5;test++) {
  char fs_text[2048];snprintf(fs_text,sizeof(fs_text),"precision highp float; uniform highp float big; void main(){%s gl_FragColor=vec4(v,v*0.5,1.0-v,1.0);}",bodies[test]);
  GLuint fs=shader(GL_FRAGMENT_SHADER,fs_text),program=glCreateProgram();glAttachShader(program,vs);glAttachShader(program,fs);glBindAttribLocation(program,0,"pos");glLinkProgram(program);GLint ok=0;glGetProgramiv(program,GL_LINK_STATUS,&ok);require(ok,"link");glUseProgram(program);
  GLint location=glGetUniformLocation(program,"big");if(location>=0)glUniform1f(location,1024.0f);
  glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,0,verts);glEnableVertexAttribArray(0);glClear(GL_COLOR_BUFFER_BIT);glDrawArrays(GL_TRIANGLE_STRIP,0,4);
  unsigned char pixels[32*32*4];glReadPixels(0,0,32,32,GL_RGBA,GL_UNSIGNED_BYTE,pixels);require(glGetError()==GL_NO_ERROR,"draw/readback");int maximum=0;
  for(int y=0;y<32;y++)for(int x=0;x<32;x++) {
   double u=(x+0.5)/32.0,w=(y+0.5)/32.0,v;
   if(test==0)v=u*(0.1+w*0.2)+0.3;
   else if(test==1)v=u<0.5?(u>w?0.25:0.5):(x==y?0.75:1.0);
   else if(test==2)v=sqrt(u*0.25+0.25)*0.8;
   else if(test==3)v=(x+0.5)/64.0;
   else {v=0;for(int i=0;i<4;i++)v=v*0.5+u*0.125;}
   double expected[]={v,v*0.5,1-v,1};
   for(int c=0;c<4;c++){int delta=abs((int)pixels[(y*32+x)*4+c]-(int)lround(expected[c]*255));if(delta>maximum)maximum=delta;}
  }
  printf("{\"test\":\"%s\",\"checked_pixels\":1024,\"max_channel_error\":%d,\"ok\":%s}\n",names[test],maximum,maximum<=2?"true":"false");fflush(stdout);require(maximum<=2,"fragment output reference");glDeleteProgram(program);glDeleteShader(fs);
 }
 glDeleteShader(vs);glDeleteFramebuffers(1,&fbo);glDeleteTextures(1,&texture);eglMakeCurrent(d,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT);eglDestroyContext(d,ctx);eglTerminate(d);return 0;
}
