// SPDX-License-Identifier: GPL-2.0-only
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

#define WORD_BITS (8 * sizeof(unsigned long))
#define KEY_WORDS ((KEY_MAX + WORD_BITS) / WORD_BITS)

static int held(int fd)
{
    unsigned long keys[KEY_WORDS] = {0};
    if (ioctl(fd, EVIOCGKEY(sizeof(keys)), keys) < 0)
        return 0;
    return ((keys[KEY_VOLUMEUP / WORD_BITS] >> (KEY_VOLUMEUP % WORD_BITS)) |
            (keys[KEY_VOLUMEDOWN / WORD_BITS] >> (KEY_VOLUMEDOWN % WORD_BITS))) & 1;
}

int main(int argc, char **argv)
{
    struct pollfd fds[32];
    struct input_event event;
    char path[64];
    int count = 0, timeout = -1;
    int check = argc == 2 && !strcmp(argv[1], "--held");
    int press = argc == 2 && !strcmp(argv[1], "--press");
    if (argc > 2)
        return 2;
    if (argc == 2 && !check && !press) {
        char *end;
        long seconds = strtol(argv[1], &end, 10);
        if (*end || seconds < 0 || seconds > 60)
            return 2;
        timeout = seconds * 1000;
    }
    for (int i = 0; i < 32; i++) {
        snprintf(path, sizeof(path), "/dev/input/event%d", i);
        int fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
        if (fd < 0)
            continue;
        if (!press && held(fd))
            return 0;
        fds[count++] = (struct pollfd){ .fd = fd, .events = POLLIN };
    }
    if (!count)
        return 2;
    if (check)
        return 1;
    struct timespec started, now;
    clock_gettime(CLOCK_MONOTONIC, &started);
    for (;;) {
        int remaining = timeout;
        if (timeout >= 0) {
            clock_gettime(CLOCK_MONOTONIC, &now);
            remaining -= (now.tv_sec - started.tv_sec) * 1000 +
                         (now.tv_nsec - started.tv_nsec) / 1000000;
            if (remaining <= 0)
                return 1;
        }
        int ret = poll(fds, count, remaining);
        if (!ret)
            return 1;
        if (ret < 0) {
            if (errno == EINTR)
                continue;
            return 2;
        }
        for (int i = 0; i < count; i++) {
            if (fds[i].revents & (POLLERR | POLLHUP | POLLNVAL))
                return 2;
            while (read(fds[i].fd, &event, sizeof(event)) == sizeof(event)) {
                if (event.type == EV_KEY && event.value == 1 &&
                    (event.code == KEY_VOLUMEUP || event.code == KEY_VOLUMEDOWN))
                    return 0;
            }
        }
    }
}
