// SPDX-License-Identifier: MIT
// Exercise GEM handle lifetime only; no GPU submission, modeset or MMIO.
#include <xf86drm.h>
#include <msm_drm.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
static void check(int result,const char *what){if(result){perror(what);exit(1);}}
static unsigned create(int fd){struct drm_msm_gem_new n={.size=4096,.flags=MSM_BO_WC};check(drmIoctl(fd,DRM_IOCTL_MSM_GEM_NEW,&n),"gem_new");return n.handle;}
static uint64_t address(int fd,unsigned h){struct drm_msm_gem_info i={.handle=h,.flags=MSM_INFO_IOVA};check(drmIoctl(fd,DRM_IOCTL_MSM_GEM_INFO,&i),"get_iova");return i.offset;}
static void drop(int fd,unsigned h){struct drm_gem_close c={.handle=h};check(drmIoctl(fd,DRM_IOCTL_GEM_CLOSE,&c),"gem_close");}
int main(int argc,char **argv){
 if(argc!=2){fprintf(stderr,"Usage: %s RENDER_NODE\n",argv[0]);return 2;}
 int a=open(argv[1],O_RDWR|O_CLOEXEC),b=open(argv[1],O_RDWR|O_CLOEXEC),prime;
 if(a<0||b<0){perror("open render");return 1;}
 unsigned ha=create(a),hb;uint64_t before=address(a,ha);
 check(drmPrimeHandleToFD(a,ha,DRM_CLOEXEC|DRM_RDWR,&prime),"export");
 check(drmPrimeFDToHandle(b,prime,&hb),"import");
 uint64_t imported=address(b,hb);drop(b,hb);
 unsigned filler=create(a);uint64_t reused=address(a,filler),after=address(a,ha);
 printf("{\"before\":\"0x%"PRIx64"\",\"imported\":\"0x%"PRIx64"\",\"filler\":\"0x%"PRIx64"\",\"after\":\"0x%"PRIx64"\",\"stable\":%s}\n",before,imported,reused,after,before==after?"true":"false");
 drop(a,filler);drop(a,ha);close(prime);close(b);close(a);return before==after?0:3;
}
