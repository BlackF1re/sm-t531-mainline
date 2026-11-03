// SPDX-License-Identifier: MIT
#define _POSIX_C_SOURCE 200809L
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES3/gl3.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
static void need(int v,const char*s){if(!v){fprintf(stderr,"FAIL %s gl=0x%x\n",s,glGetError());exit(1);}}
static double now(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec+t.tv_nsec*1e-9;}
static GLuint sh(GLenum t,const char*s){GLuint a=glCreateShader(t);glShaderSource(a,1,&s,0);glCompileShader(a);GLint ok;glGetShaderiv(a,GL_COMPILE_STATUS,&ok);if(!ok){char l[4096];glGetShaderInfoLog(a,sizeof l,0,l);fprintf(stderr,"%s\n",l);}need(ok,"shader");return a;}
int main(int argc,char**argv){need(argc==2,"output prefix");
 PFNEGLGETPLATFORMDISPLAYEXTPROC get=(void*)eglGetProcAddress("eglGetPlatformDisplayEXT");need(get!=0,"platform");EGLDisplay d=get(EGL_PLATFORM_SURFACELESS_MESA,EGL_DEFAULT_DISPLAY,0);need(eglInitialize(d,0,0),"EGL");eglBindAPI(EGL_OPENGL_ES_API);EGLint ca[]={EGL_CONTEXT_CLIENT_VERSION,3,EGL_NONE};EGLContext c=eglCreateContext(d,EGL_NO_CONFIG_KHR,EGL_NO_CONTEXT,ca);need(c!=EGL_NO_CONTEXT,"context");need(eglMakeCurrent(d,EGL_NO_SURFACE,EGL_NO_SURFACE,c),"current");need(strstr((const char*)glGetString(GL_RENDERER),"FD305")!=0,"GPU");
 GLuint v=sh(GL_VERTEX_SHADER,"attribute vec2 pos;varying vec2 uv;void main(){gl_Position=vec4(pos,0.,1.);uv=0.5+0.5*pos;}");
 const char *src[]={"precision highp float;varying vec2 uv;uniform vec4 col;uniform sampler2D tex;void main(){gl_FragColor=texture2D(tex,uv)*col;}","precision highp float;varying vec2 uv;uniform vec4 col;uniform sampler2D tex;void main(){vec4 x=texture2D(tex,uv);gl_FragColor=vec4(x.bgr*col.rgb,col.a*x.a);}"};
 GLuint ps[2];GLint colors[2];for(int k=0;k<2;k++){GLuint f=sh(GL_FRAGMENT_SHADER,src[k]);ps[k]=glCreateProgram();glAttachShader(ps[k],v);glAttachShader(ps[k],f);glBindAttribLocation(ps[k],0,"pos");glLinkProgram(ps[k]);GLint ok;glGetProgramiv(ps[k],GL_LINK_STATUS,&ok);need(ok,"link");glUseProgram(ps[k]);glUniform1i(glGetUniformLocation(ps[k],"tex"),0);colors[k]=glGetUniformLocation(ps[k],"col");glDeleteShader(f);}
 GLuint textures[2];glGenTextures(2,textures);unsigned char images[2][16]={{255,96,32,255,64,255,128,255,32,64,255,255,255,255,255,255},{80,220,100,255,240,64,200,255,160,120,255,255,255,200,64,255}};for(int i=0;i<2;i++){glBindTexture(GL_TEXTURE_2D,textures[i]);glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,2,2,0,GL_RGBA,GL_UNSIGNED_BYTE,images[i]);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);}
 GLuint bo;glGenBuffers(1,&bo);glBindBuffer(GL_ARRAY_BUFFER,bo);float verts[]={-1,-1,1,-1,-1,1,1,1};glBufferData(GL_ARRAY_BUFFER,sizeof verts,verts,GL_STATIC_DRAW);glVertexAttribPointer(0,2,GL_FLOAT,0,0,0);glEnableVertexAttribArray(0);glDisable(GL_DITHER);glBlendFunc(GL_ONE,GL_ONE_MINUS_SRC_ALPHA);
 for(int size=0;size<2;size++){int w=size?257:1280,h=size?131:800;GLuint rt,fb,ds;glGenTextures(1,&rt);glBindTexture(GL_TEXTURE_2D,rt);glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,w,h,0,GL_RGBA,GL_UNSIGNED_BYTE,0);glGenFramebuffers(1,&fb);glBindFramebuffer(GL_FRAMEBUFFER,fb);glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,rt,0);glGenRenderbuffers(1,&ds);glBindRenderbuffer(GL_RENDERBUFFER,ds);glRenderbufferStorage(GL_RENDERBUFFER,GL_DEPTH24_STENCIL8,w,h);glFramebufferRenderbuffer(GL_FRAMEBUFFER,GL_DEPTH_STENCIL_ATTACHMENT,GL_RENDERBUFFER,ds);need(glCheckFramebufferStatus(GL_FRAMEBUFFER)==GL_FRAMEBUFFER_COMPLETE,"FBO");glViewport(0,0,w,h);unsigned char *pixels=malloc(w*h*4);need(pixels!=0,"pixels");
  for(int test=0;test<5;test++){double start=0;unsigned query_value=0;GLuint query=0;if(test==3)glGenQueries(1,&query);
   for(int frame=0;frame<23;frame++){glDisable(GL_SCISSOR_TEST);glDisable(GL_BLEND);glDisable(GL_STENCIL_TEST);glDisable(GL_DEPTH_TEST);glDepthMask(GL_TRUE);glStencilMask(255);glClearColor(.05,.1,.15,1);glClearDepthf(1);glClearStencil(0);glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT|GL_STENCIL_BUFFER_BIT);if(frame==3)start=now();if(test==3)glBeginQuery(GL_ANY_SAMPLES_PASSED,query);
    for(int i=0;i<96;i++){int small=i>=5 && test!=1;int x=(i*37+frame*3)%w,y=(i*23+frame)%h,rw=small?(w/10+1):w,rh=small?(h/10+1):h;if(test==4&&small){x=((i/12)*37+frame*3)%w;y=((i/12)*23+frame)%h;}if(!small)x=y=0;if(x+rw>w)rw=w-x;if(y+rh>h)rh=h-y;glEnable(GL_SCISSOR_TEST);glScissor(x,y,rw,rh);
     if(test==2&&i==48){glClearColor(.3,.05,.2,1);glStencilMask(255);glClear(GL_COLOR_BUFFER_BIT|GL_STENCIL_BUFFER_BIT);}
     if(test==2&&i%3==0){glEnable(GL_STENCIL_TEST);glStencilFunc(GL_ALWAYS,i&255,255);glStencilOp(GL_KEEP,GL_KEEP,GL_REPLACE);}else glDisable(GL_STENCIL_TEST);
     int k=i&1;float alpha=.25f+(i%4)*.125f;glUseProgram(ps[k]);glUniform4f(colors[k],alpha*((i%7)+1)/8,alpha*((i%5)+1)/6,alpha*((i%3)+1)/4,alpha);glBindTexture(GL_TEXTURE_2D,textures[(i/3)&1]);glEnable(GL_BLEND);glDrawArrays(GL_TRIANGLE_STRIP,0,4);
    }
    if(test==3)glEndQuery(GL_ANY_SAMPLES_PASSED);glFinish();need(glGetError()==GL_NO_ERROR,"draw");
   }
   double end=now();if(test==3){glGetQueryObjectuiv(query,GL_QUERY_RESULT,&query_value);glEnable(GL_SCISSOR_TEST);glScissor(0,0,0,0);glBeginQuery(GL_ANY_SAMPLES_PASSED,query);glDrawArrays(GL_TRIANGLE_STRIP,0,4);glEndQuery(GL_ANY_SAMPLES_PASSED);glFinish();GLuint empty=9;glGetQueryObjectuiv(query,GL_QUERY_RESULT,&empty);need(empty==0,"empty query");glDeleteQueries(1,&query);}glReadPixels(0,0,w,h,GL_RGBA,GL_UNSIGNED_BYTE,pixels);need(glGetError()==GL_NO_ERROR,"read");char path[512];snprintf(path,sizeof path,"%s-%d-%d.rgba",argv[1],size,test);FILE*f=fopen(path,"wb");need(f!=0,"open");need(fwrite(pixels,4,w*h,f)==(unsigned)(w*h),"write");fclose(f);printf("{\"w\":%d,\"h\":%d,\"case\":%d,\"frames\":20,\"mean_ms\":%.6f,\"start_monotonic\":%.9f,\"end_monotonic\":%.9f,\"query\":%u}\n",w,h,test,(end-start)*1000/20,start,end,query_value);fflush(stdout);
  }
  free(pixels);glDeleteRenderbuffers(1,&ds);glDeleteFramebuffers(1,&fb);glDeleteTextures(1,&rt);
 }
 eglMakeCurrent(d,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT);eglDestroyContext(d,c);eglTerminate(d);return 0;
}
