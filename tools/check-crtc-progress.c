// SPDX-License-Identifier: MIT
/* Verify the live scanout counter advances; allocator state is insufficient. */
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>
#include <drm.h>

int main(int argc, char **argv)
{
	struct drm_crtc_get_sequence before = {0}, after = {0};
	struct timespec delay = {.tv_sec = 1};
	union drm_wait_vblank wait = {
		.request.type = _DRM_VBLANK_RELATIVE,
		.request.sequence = 2,
	};
	int fd;

	if (argc != 3) {
		fprintf(stderr, "Usage: %s DRM_DEVICE CRTC_ID\n", argv[0]);
		return 2;
	}
	before.crtc_id = after.crtc_id = strtoul(argv[2], NULL, 10);
	fd = open(argv[1], O_RDWR | O_CLOEXEC);
	if (fd < 0 || ioctl(fd, DRM_IOCTL_CRTC_GET_SEQUENCE, &before)) {
		perror("CRTC sequence before");
		return 1;
	}
	if (ioctl(fd, DRM_IOCTL_WAIT_VBLANK, &wait)) {
		perror("vblank interrupt");
		return 1;
	}
	while (nanosleep(&delay, &delay) && errno == EINTR) {}
	if (ioctl(fd, DRM_IOCTL_CRTC_GET_SEQUENCE, &after)) {
		perror("CRTC sequence after");
		return 1;
	}
	close(fd);
	printf("{\"active\":%u,\"before\":%" PRIu64 ",\"after\":%" PRIu64 ",\"delta\":%" PRIu64 "}\n",
	       after.active, (uint64_t)before.sequence, (uint64_t)after.sequence,
	       (uint64_t)(after.sequence - before.sequence));
	return !before.active || !after.active || after.sequence <= before.sequence;
}
