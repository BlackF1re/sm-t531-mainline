// SPDX-License-Identifier: GPL-2.0-only
/* Standard V4L2 RF acceptance probe. No private ioctl, audio or FM transmit. */
#include <errno.h>
#include <fcntl.h>
#include <linux/videodev2.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

static const unsigned int stations[] = {
	87700, 88500, 88900, 89500, 90300, 90700, 91100, 91500,
	95700, 96100, 96500, 98000, 98400, 98800, 99200, 99600,
	101300, 101700, 102100, 102500, 102900, 103400, 103800,
	104200, 104600, 105400, 106100, 106600, 107100,
};

int main(int argc, char **argv)
{
	struct v4l2_capability cap = {0};
	unsigned int detected = 0, errors = 0;
	int fd;

	if (argc != 2) {
		fprintf(stderr, "Usage: %s /dev/radioN\n", argv[0]);
		return 2;
	}
	setvbuf(stdout, NULL, _IOLBF, 0);
	fd = open(argv[1], O_RDWR | O_NONBLOCK | O_CLOEXEC);
	if (fd < 0) { perror("open"); return 2; }
	if (ioctl(fd, VIDIOC_QUERYCAP, &cap) < 0) {
		perror("VIDIOC_QUERYCAP"); close(fd); return 2;
	}
	printf("{\"driver\":\"%.16s\",\"card\":\"%.32s\"}\n", cap.driver, cap.card);
	for (unsigned int i = 0; i < sizeof(stations)/sizeof(stations[0]); i++) {
		struct v4l2_frequency f = {
			.type = V4L2_TUNER_RADIO, .frequency = stations[i] * 16,
		};
		struct v4l2_tuner t = {0};
		struct timespec dwell = {.tv_sec = 2};
		unsigned int rds_bytes = 0;
		unsigned char blocks[3 * 256];
		ssize_t n;

		if (ioctl(fd, VIDIOC_S_FREQUENCY, &f) < 0) {
			printf("{\"khz\":%u,\"tune_errno\":%d}\n", stations[i], errno);
			errors++;
			continue;
		}
		nanosleep(&dwell, NULL);
		if (ioctl(fd, VIDIOC_G_TUNER, &t) < 0) {
			printf("{\"khz\":%u,\"tuner_errno\":%d}\n", stations[i], errno);
			errors++;
			continue;
		}
		while ((n = read(fd, blocks, sizeof(blocks))) > 0) rds_bytes += n;
		if (n < 0 && errno != EAGAIN) errors++;
		printf("{\"khz\":%u,\"signal_u16\":%u,\"stereo\":%s,\"rds_sync\":%s,\"rds_bytes\":%u}\n",
		       stations[i], t.signal,
		       t.rxsubchans & V4L2_TUNER_SUB_STEREO ? "true" : "false",
		       t.rxsubchans & V4L2_TUNER_SUB_RDS ? "true" : "false", rds_bytes);
		if (t.signal && (t.rxsubchans & (V4L2_TUNER_SUB_STEREO | V4L2_TUNER_SUB_RDS))) detected++;
	}
	close(fd);
	printf("{\"candidate_signals\":%u,\"io_errors\":%u,\"note\":\"Nonzero signal alone does not identify a station; validate RDS or audio\"}\n", detected, errors);
	return errors ? 2 : detected ? 0 : 1;
}
