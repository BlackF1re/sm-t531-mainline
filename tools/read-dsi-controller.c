// SPDX-License-Identifier: MIT
/* Read-only SM-T531 DSI controller snapshot; no PHY/PLL or protected globals. */
#define _FILE_OFFSET_BITS 64
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

static int sample_fifo(int fd, const volatile uint32_t *regs)
{
    char power[32] = {0};
    unsigned total[1024] = {0}, underflow[1024] = {0}, rising[1024] = {0};
    unsigned invalid = 0, previous = 0, transitions = 0, last_line = 0;
    int pfd = open("/sys/bus/platform/devices/fd900100.display-controller/power/runtime_status", O_RDONLY);
    if (pfd < 0 || read(pfd, power, sizeof(power) - 1) < 0) return 1;
    close(pfd);
    if (strcmp(power, "active\n")) return 2;
    const volatile uint32_t *mdp = mmap(NULL, 4096, PROT_READ, MAP_SHARED,
                                      fd, (off_t)0xfd921000);
    if (mdp == MAP_FAILED) { perror("MDP mmap"); return 1; }
    unsigned htotal = mdp[0x308 / 4] >> 16;
    unsigned vsync_period = mdp[0x30c / 4];
    unsigned display_start = mdp[0x31c / 4];
    unsigned display_end = mdp[0x324 / 4];
    struct timespec next;
    clock_gettime(CLOCK_MONOTONIC, &next);
    for (unsigned i = 0; i < 20000; i++) {
        unsigned fifo = regs[0x80c / 4];
        unsigned line = mdp[0x3b0 / 4];
        unsigned flags = fifo & 0x88880000u;
        if (line < 1024) {
            total[line]++;
            underflow[line] += !!flags;
            rising[line] += flags && !previous && i;
        } else {
            invalid++;
        }
        transitions += i && line != last_line;
        last_line = line;
        previous = flags;
        next.tv_nsec += 250000;
        if (next.tv_nsec >= 1000000000) {
            next.tv_sec++;
            next.tv_nsec -= 1000000000;
        }
        int ret;
        do {
            ret = clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &next, NULL);
        } while (ret == EINTR);
        if (ret) { munmap((void *)mdp, 4096); return 1; }
    }
    printf("{\"samples\":20000,\"period_us\":250,\"invalid_line\":%u,\"line_transitions\":%u,"
           "\"htotal\":%u,\"vsync_period\":%u,\"display_start\":%u,\"display_end\":%u,\"lines\":[",
           invalid, transitions, htotal, vsync_period, display_start, display_end);
    const char *separator = "";
    for (unsigned i = 0; i < 1024; i++) {
        if (!total[i]) continue;
        printf("%s{\"line\":%u,\"samples\":%u,\"underflow\":%u,\"rising\":%u}",
               separator, i, total[i], underflow[i], rising[i]);
        separator = ",";
    }
    puts("]}");
    munmap((void *)mdp, 4096);
    return transitions ? 0 : 2;
}

int main(int argc, char **argv)
{
    char board[128] = {0}, power[32] = {0};
    const unsigned offsets[] = {
        0x000, 0x004, 0x008, 0x00c, 0x010, 0x014, 0x020,
        0x024, 0x028, 0x02c, 0x030, 0x034, 0x038,
        0x068, 0x0a8, 0x0ac, 0x0b4, 0x0b8, 0x0bc, 0x0c0,
        0x0c4, 0x0cc, 0x10c, 0x110, 0x11c, 0x120, 0x1f0, 0x1f4,
    };
    if (argc > 2 || (argc == 2 && strcmp(argv[1], "--sample-fifo"))) return 2;
    int fd = open("/proc/device-tree/compatible", O_RDONLY);
    if (fd < 0 || read(fd, board, sizeof(board) - 1) < 0) return 1;
    close(fd);
    if (strcmp(board, "samsung,matisse3g")) return 2;
    fd = open("/sys/bus/platform/devices/fd922800.dsi/power/runtime_status", O_RDONLY);
    if (fd < 0 || read(fd, power, sizeof(power) - 1) < 0) return 1;
    close(fd);
    if (strcmp(power, "active\n")) {
        fputs("Rejecting inactive DSI controller\n", stderr);
        return 2;
    }
    fd = open("/dev/mem", O_RDONLY | O_SYNC);
    if (fd < 0) { perror("devmem"); return 1; }
    const volatile uint32_t *regs = mmap(NULL, 4096, PROT_READ, MAP_SHARED,
                                       fd, (off_t)0xfd922000);
    if (regs == MAP_FAILED) { perror("mmap"); close(fd); return 1; }
    int result = 0;
    if (argc == 2) {
        result = sample_fifo(fd, regs);
    } else {
        for (unsigned i = 0; i < sizeof(offsets) / sizeof(offsets[0]); i++)
            printf("%08x %08x\n", 0xfd922800u + offsets[i], regs[(0x800 + offsets[i]) / 4]);
    }
    munmap((void *)regs, 4096);
    close(fd);
    return result;
}
