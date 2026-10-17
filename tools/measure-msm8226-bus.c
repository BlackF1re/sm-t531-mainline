// SPDX-License-Identifier: MIT
// Diagnostic only: measure GCC clocks against XO/4, without changing rates.
// Register sequence and mux IDs: Samsung clock-8226.c, commit
// 3fa1853ed5d6c3a8ef5a2fda9822705243bbc256. No PLLTEST pad writes.
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

enum { XO4 = 0xc8, MUX = 0x880, CTL = 0x884, STATUS = 0x888 };
static volatile uint32_t *regs;
static volatile uint32_t *mmss;
static volatile uint32_t *apcs;
static uint32_t saved_xo4, saved_mux, saved_ctl;
static uint32_t saved_mmss_mux;
static uint32_t saved_apcs_mux;
static int changed;
static volatile sig_atomic_t interrupted;

static uint32_t rd(unsigned offset) { return regs[offset / 4]; }
static void wr(unsigned offset, uint32_t value)
{
    regs[offset / 4] = value;
    __sync_synchronize();
}
static void restore(void)
{
    if (!changed) return;
    wr(CTL, saved_ctl);
    wr(MUX, saved_mux);
    if (mmss) {
        mmss[0x900 / 4] = saved_mmss_mux;
        __sync_synchronize();
    }
    if (apcs) {
        apcs[0x1c / 4] = saved_apcs_mux;
        __sync_synchronize();
    }
    wr(XO4, saved_xo4);
    changed = 0;
}
static void signal_received(int number) { interrupted = number; }
static double now(void)
{
    struct timespec stamp;
    clock_gettime(CLOCK_MONOTONIC, &stamp);
    return stamp.tv_sec + stamp.tv_nsec / 1e9;
}
static int wait_done(int done)
{
    double deadline = now() + 0.1;
    while (!!(rd(STATUS) & (1u << 25)) != done) {
        if (interrupted || now() > deadline) return -1;
        usleep(50);
    }
    return 0;
}
static int measure(unsigned ticks, uint32_t *count)
{
    wr(CTL, ticks);
    if (wait_done(0)) return -1;
    wr(CTL, (1u << 20) | ticks);
    if (wait_done(1)) return -1;
    *count = rd(STATUS) & 0x1ffffff;
    wr(CTL, ticks);
    return 0;
}
int main(int argc, char **argv)
{
    const struct { const char *name; unsigned mux; const char *gate; } clocks[] = {
        { "ddr_kpss_axi", 0x155, NULL }, { "snoc", 0, NULL },
        { "cnoc", 8, NULL }, { "pnoc", 0x10, NULL },
        { "mmss_axi", 4, "mmss_mmssnoc_axi_clk" },
        { "gpu_axi", 0xb, "oxilicx_axi_clk" },
        { "gpu_core", 0xd, "oxili_gfx3d_clk" },
        { "mdp_core", 0x14, "mdss_mdp_clk" },
        { "dsi_pixel", 0x16, "mdss_pclk0_clk" },
        { "dsi_byte", 0x1e, "mdss_byte0_clk" },
        /* APSS debug selectors, not operating-clock mux values. */
        { "cpu0", 0x10, NULL }, { "cpu1", 0x114, NULL },
        { "cpu2", 0x220, NULL }, { "cpu3", 0x324, NULL },
        { "l2", 0x1000, NULL },
    };
    unsigned selected = 0;
    if (argc != 2 || geteuid()) {
        fprintf(stderr, "Usage (root): %s ddr_kpss_axi|snoc|cnoc|pnoc|mmss_axi|gpu_axi|gpu_core|mdp_core|dsi_pixel|dsi_byte|cpu0|cpu1|cpu2|cpu3|l2\n", argv[0]);
        return 2;
    }
    for (; selected < sizeof(clocks)/sizeof(clocks[0]); selected++)
        if (!strcmp(argv[1], clocks[selected].name)) break;
    if (selected == sizeof(clocks)/sizeof(clocks[0])) return 2;
    char compatible[128] = {0};
    int board = open("/proc/device-tree/compatible", O_RDONLY);
    if (board < 0 || read(board, compatible, sizeof(compatible)-1) <= 0 ||
        strcmp(compatible, "samsung,matisse3g")) return 2;
    close(board);
    int lock = open("/run/lock/t531-clock-measure.lock", O_CREAT|O_RDWR|O_CLOEXEC, 0600);
    if (lock < 0 || flock(lock, LOCK_EX|LOCK_NB)) { perror("lock"); return 1; }
    int mem = open("/dev/mem", O_RDWR|O_SYNC|O_CLOEXEC);
    if (mem < 0) { perror("devmem"); return 1; }
    regs = mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_SHARED, mem, 0xfc401000);
    if (regs == MAP_FAILED) { perror("mmap"); return 1; }
    int is_apcs = !strncmp(clocks[selected].name, "cpu", 3) ||
        !strcmp(clocks[selected].name, "l2");
    if (is_apcs) {
        /* Always-on KPSS global diagnostic register; no PLL access. */
        apcs = mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_SHARED, mem, 0xf9011000);
        if (apcs == MAP_FAILED) { apcs = NULL; perror("APCS mmap"); return 1; }
        saved_apcs_mux = apcs[0x1c / 4];
    }
    if (clocks[selected].gate) {
        char path[256];
        snprintf(path, sizeof(path), "/sys/kernel/debug/clk/%s/clk_enable_count", clocks[selected].gate);
        FILE *gate = fopen(path, "r");
        unsigned enabled = 0;
        if (gate) { int scanned = fscanf(gate, "%u", &enabled); fclose(gate); if (scanned != 1) enabled = 0; }
        if (!enabled) { fprintf(stderr, "Clock disabled; activate display/GPU first\n"); return 1; }
        mmss = mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_SHARED, mem, 0xfd8c0000);
        if (mmss == MAP_FAILED) { mmss = NULL; perror("MMSS mmap"); return 1; }
        saved_mmss_mux = mmss[0x900 / 4];
    }
    saved_xo4 = rd(XO4); saved_mux = rd(MUX); saved_ctl = rd(CTL);
    // Firmware can leave the debug mux enabled with its counter stopped.
    // No measurement driver owns these registers in this board kernel.
    usleep(20000);
    if ((saved_ctl & (1u << 20)) || rd(CTL) != saved_ctl || rd(MUX) != saved_mux) {
        fprintf(stderr, "Debug counter busy: mux=%#x ctl=%#x\n", saved_mux, saved_ctl);
        return 1;
    }
    atexit(restore);
    signal(SIGINT, signal_received); signal(SIGTERM, signal_received);
    changed = 1;
    if (mmss) {
        mmss[0x900 / 4] = clocks[selected].mux;
        __sync_synchronize();
        mmss[0x900 / 4] = (1u << 16) | clocks[selected].mux;
        __sync_synchronize();
    }
    if (apcs) {
        /* Exact BSP measure_mux_APSS sequence: divide observed clock by4. */
        apcs[0x1c / 4] = 0xc0000000u | clocks[selected].mux;
        __sync_synchronize();
    }
    unsigned mux = apcs ? 362 : mmss ? 0x2c : clocks[selected].mux;
    wr(MUX, mux);
    wr(MUX, (1u << 16) | mux);
    wr(XO4, saved_xo4 | 1u);
    uint32_t short_count = 0, full_count = 0;
    int failed = measure(0x1000, &short_count) || measure(0x10000, &full_count);
    restore();
    // XO4 branch HALT is asynchronous and read-only; let it settle.
    usleep(1000);
    if (failed) { fprintf(stderr, "Measurement timed out/interrupted; registers restored\n"); return 1; }
    if (rd(XO4) != saved_xo4 || rd(MUX) != saved_mux || rd(CTL) != saved_ctl ||
        (mmss && mmss[0x900 / 4] != saved_mmss_mux) ||
        (apcs && apcs[0x1c / 4] != saved_apcs_mux)) {
        fprintf(stderr, "Register restoration mismatch: xo4=%#x/%#x mux=%#x/%#x ctl=%#x/%#x\n",
                rd(XO4), saved_xo4, rd(MUX), saved_mux, rd(CTL), saved_ctl);
        return 1;
    }
    double hz = short_count == full_count ? 0 :
        ((double)full_count * 10 + 15) * 4800000 / (0x10000 * 10.0 + 35);
    if (apcs) hz *= 4;
    printf("{\"clock\":\"%s\",\"mux\":%u,\"short_count\":%u,\"full_count\":%u,"
           "\"observed_hz\":%.3f,\"registers_restored\":true}\n",
           clocks[selected].name, clocks[selected].mux, short_count, full_count, hz);
    munmap((void *)regs, 4096); close(mem); close(lock);
    if (mmss) munmap((void *)mmss, 4096);
    if (apcs) munmap((void *)apcs, 4096);
    return interrupted ? 1 : 0;
}
