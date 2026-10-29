// SPDX-License-Identifier: MIT
// Query only: never becomes DRM master, allocates buffers, or modesets.
#define _GNU_SOURCE
#include <xf86drm.h>
#include <xf86drmMode.h>
#include <msm_drm.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <fcntl.h>
#include <errno.h>
#include <glob.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

struct info { char card[PATH_MAX], render[PATH_MAX]; const char *driver; unsigned gpu, width, height, mhz; int atomic, unified; };
static int same_device(const char *a, const char *b) {
 struct stat x,y; char sx[128],sy[128],rx[PATH_MAX],ry[PATH_MAX];
 if(stat(a,&x)||stat(b,&y)||!S_ISCHR(x.st_mode)||!S_ISCHR(y.st_mode))return 0;
 snprintf(sx,sizeof sx,"/sys/dev/char/%u:%u/device",major(x.st_rdev),minor(x.st_rdev));
 snprintf(sy,sizeof sy,"/sys/dev/char/%u:%u/device",major(y.st_rdev),minor(y.st_rdev));
 return realpath(sx,rx)&&realpath(sy,ry)&&!strcmp(rx,ry);
}
static int inspect(const char *path,struct info *i) {
 int fd=open(path,O_RDWR|O_CLOEXEC); if(fd<0)return 0;
 drmVersionPtr v=drmGetVersion(fd); if(!v){close(fd);return 0;}
 if(v->name_len==3&&!memcmp(v->name,"msm",3))i->driver="msm";
 else if(v->name_len==7&&!memcmp(v->name,"msm-kms",7))i->driver="msm-kms";
 else {drmFreeVersion(v);close(fd);return 0;}
 snprintf(i->card,sizeof i->card,"%s",path);
 char *render=drmGetRenderDeviceNameFromFd(fd);
 if(render){snprintf(i->render,sizeof i->render,"%s",render);free(render);}
 if(i->render[0]) {
  struct drm_msm_param p={.pipe=MSM_PIPE_3D0,.param=MSM_PARAM_GPU_ID};
  int rfd=open(i->render,O_RDWR|O_CLOEXEC);
  if(rfd>=0){if(!drmIoctl(rfd,DRM_IOCTL_MSM_GET_PARAM,&p))i->gpu=p.value;else fprintf(stderr,"GPU query %s: %s\n",i->render,strerror(errno));if(!i->gpu){p.param=MSM_PARAM_CHIP_ID;p.value=0;if(!drmIoctl(rfd,DRM_IOCTL_MSM_GET_PARAM,&p)){unsigned chip=p.value;i->gpu=((chip>>24)&255)*100+((chip>>16)&255)*10+((chip>>8)&255);}}close(rfd);}
 }
 i->atomic=!drmSetClientCap(fd,DRM_CLIENT_CAP_ATOMIC,1);
 drmModeRes *r=drmModeGetResources(fd);
 if(r){for(int c=0;c<r->count_connectors;c++) {
   drmModeConnector *conn=drmModeGetConnector(fd,r->connectors[c]); if(!conn)continue;
   if(conn->connection!=DRM_MODE_DISCONNECTED)for(int m=0;m<conn->count_modes;m++) {
    drmModeModeInfo *m0=&conn->modes[m];
    unsigned mhz=m0->htotal&&m0->vtotal?(unsigned)((unsigned long long)m0->clock*1000000/(m0->htotal*m0->vtotal)):0;
    if(m0->hdisplay==1280&&m0->vdisplay==800&&mhz>=59000&&mhz<=61000){i->width=1280;i->height=800;i->mhz=mhz;}
   }
   drmModeFreeConnector(conn);
  }drmModeFreeResources(r);}
 i->unified=i->gpu==305&&i->atomic&&i->width&&i->render[0]&&same_device(i->card,i->render)&&!strcmp(i->driver,"msm");
 drmFreeVersion(v);close(fd);return 1;
}
static void show(const struct info *i) {
 printf("{\"card\":\"%s\",\"render\":\"%s\",\"driver\":\"%s\",\"gpu_id\":%u,\"atomic\":%s,\"width\":%u,\"height\":%u,\"refresh_millihz\":%u,\"unified\":%s}",i->card,i->render,i->driver,i->gpu,i->atomic?"true":"false",i->width,i->height,i->mhz,i->unified?"true":"false");
}
int main(int argc,char **argv) {
 int require=0,wait=0;
 for(int k=1;k<argc;k++) {
  if(!strcmp(argv[k],"--require-unified"))require=1;
  else if(!strcmp(argv[k],"--inventory"))require=0;
  else if(!strcmp(argv[k],"--wait")&&k+1<argc) { char *end;long n=strtol(argv[++k],&end,10);if(*end||n<0||n>60)return 2;wait=n; }
  else {fprintf(stderr,"Usage: %s [--inventory|--require-unified] [--wait 0..60]\n",argv[0]);return 2;}
 }
 for(int attempt=0;attempt<=wait;attempt++) {
  glob_t g={0};struct info found={0};int matches=0,first=1;
  glob("/dev/dri/card[0-9]*",0,NULL,&g);
  if(!require)putchar('[');
  for(size_t j=0;j<g.gl_pathc;j++){struct info i={0};if(!inspect(g.gl_pathv[j],&i))continue;
   if(i.unified){found=i;matches++;}
   if(!require){if(!first)putchar(',');show(&i);first=0;}
  }
  globfree(&g);
  if(!require){puts("]");return 0;}
  if(matches==1){show(&found);putchar('\n');return 0;}
  if(matches>1){fprintf(stderr,"Ambiguous: multiple Adreno305/KMS devices\n");return 1;}
  if(attempt<wait)sleep(1);
 }
 fprintf(stderr,"No single msm device with Adreno305, render node, atomic KMS and 1280x800@60Hz\n");return 1;
}
