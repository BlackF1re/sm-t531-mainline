// SPDX-License-Identifier: MIT
// Toggle Phosh's configured Super+V shortcut, without touching quick settings.
#include <fcntl.h>
#include <linux/uinput.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

static int input;
static unsigned settle_us = 1200000;
static void check(int result, const char *operation)
{
    if (result < 0) { perror(operation); exit(1); }
}
static void event(unsigned type, unsigned code, int value)
{
    struct input_event e = { .type = type, .code = code, .value = value };
    check(write(input, &e, sizeof(e)), "input event");
}
static void toggle(int cycle, const char *action)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    printf("{\"cycle\":%d,\"shortcut\":\"Super+V\",\"action\":\"%s\",\"time\":%.9f}\n",
           cycle, action, t.tv_sec + t.tv_nsec / 1e9);
    fflush(stdout);
    event(EV_KEY, KEY_LEFTMETA, 1);
    event(EV_KEY, KEY_V, 1);
    event(EV_SYN, SYN_REPORT, 0);
    usleep(30000);
    event(EV_KEY, KEY_V, 0);
    event(EV_KEY, KEY_LEFTMETA, 0);
    event(EV_SYN, SYN_REPORT, 0);
    usleep(settle_us);
}
int main(int argc, char **argv)
{
    char board[128] = {0};
    int fd = open("/proc/device-tree/compatible", O_RDONLY);
    check(fd, "board");
    check(read(fd, board, sizeof(board)-1), "board read");
    close(fd);
    if (strcmp(board, "samsung,matisse3g")) return 2;
    if (argc > 3) return 2;
    int cycles = argc >= 2 ? atoi(argv[1]) : 4;
    if (cycles < 1 || cycles > 8) return 2;
    if (argc == 3) {
        int settle_ms = atoi(argv[2]);
        if (settle_ms < 500 || settle_ms > 10000) return 2;
        settle_us = (unsigned)settle_ms * 1000;
    }
    input = open("/dev/uinput", O_WRONLY | O_CLOEXEC);
    check(input, "uinput");
    check(ioctl(input, UI_SET_EVBIT, EV_KEY), "key events");
    /* udev's input_id requires ordinary letter keys to identify a keyboard. */
    for (unsigned key = KEY_ESC; key <= KEY_SPACE; key++)
        check(ioctl(input, UI_SET_KEYBIT, key), "keyboard capability");
    check(ioctl(input, UI_SET_EVBIT, EV_REP), "repeat capability");
    check(ioctl(input, UI_SET_KEYBIT, KEY_LEFTMETA), "meta");
    check(ioctl(input, UI_SET_KEYBIT, KEY_V), "V");
    struct uinput_setup setup = {.id = {.bustype = BUS_VIRTUAL, .vendor = 1, .product = 2}};
    strcpy(setup.name, "T531 Phosh panel diagnostic keyboard");
    check(ioctl(input, UI_DEV_SETUP, &setup), "setup");
    check(ioctl(input, UI_DEV_CREATE), "create");
    sleep(2);
    for (int i=0; i<cycles; i++) { toggle(i, "open"); toggle(i, "close"); }
    check(ioctl(input, UI_DEV_DESTROY), "destroy");
    close(input);
    return 0;
}
