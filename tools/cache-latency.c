// SPDX-License-Identifier: MIT
/* Dependent random cache-line loads. No privileged registers or clock writes. */
#define _GNU_SOURCE
#include <errno.h>
#include <inttypes.h>
#include <sched.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <time.h>
#include <unistd.h>

static uint32_t rng = 0x531a305;
static uint32_t random_word(void)
{
	rng ^= rng << 13;
	rng ^= rng >> 17;
	rng ^= rng << 5;
	return rng;
}

static uint64_t ns(clockid_t clock)
{
	struct timespec t;
	if (clock_gettime(clock, &t)) { perror("clock_gettime"); exit(1); }
	return (uint64_t)t.tv_sec * 1000000000 + t.tv_nsec;
}

static unsigned frequency(unsigned cpu)
{
	char path[128];
	unsigned khz = 0;
	snprintf(path, sizeof(path), "/sys/devices/system/cpu/cpu%u/cpufreq/scaling_cur_freq", cpu);
	FILE *f = fopen(path, "r");
	if (f) { if (fscanf(f, "%u", &khz) != 1) khz = 0; fclose(f); }
	return khz;
}

static uint32_t chase(const unsigned char *base, uint32_t index, unsigned steps)
{
	/* Every load depends on the preceding one; volatile prevents elision. */
	for (unsigned i = 0; i < steps / 8; i++) {
		index = *(const volatile uint32_t *)(base + index);
		index = *(const volatile uint32_t *)(base + index);
		index = *(const volatile uint32_t *)(base + index);
		index = *(const volatile uint32_t *)(base + index);
		index = *(const volatile uint32_t *)(base + index);
		index = *(const volatile uint32_t *)(base + index);
		index = *(const volatile uint32_t *)(base + index);
		index = *(const volatile uint32_t *)(base + index);
	}
	return index;
}

int main(int argc, char **argv)
{
	unsigned cpu;
	char *end;
	unsigned long parsed;
	if (argc != 2) { fprintf(stderr, "usage: %s CPU (64-byte lines)\n", argv[0]); return 2; }
	errno = 0;
	parsed = strtoul(argv[1], &end, 10);
	if (errno || !*argv[1] || *end || parsed >= CPU_SETSIZE) return 2;
	cpu = parsed;
	cpu_set_t set;
	CPU_ZERO(&set);
	CPU_SET(cpu, &set);
	if (sched_setaffinity(0, sizeof(set), &set)) { perror("affinity"); return 1; }
	setvbuf(stdout, NULL, _IOLBF, 0);
	const unsigned sizes[] = {4096, 16384, 32768, 65536, 131072, 262144,
		524288, 1048576, 2097152, 4194304, 8388608, 16777216};
	const unsigned steps = 2097152;
	for (unsigned s = 0; s < sizeof(sizes) / sizeof(sizes[0]); s++) {
		unsigned bytes = sizes[s], count = bytes / 64;
		unsigned char *base = mmap(NULL, bytes, PROT_READ | PROT_WRITE,
			MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
		uint32_t *order = malloc(count * sizeof(*order));
		if (base == MAP_FAILED || !order) { perror("allocation"); return 1; }
		madvise(base, bytes, MADV_NOHUGEPAGE);
		for (unsigned i = 0; i < count; i++) order[i] = i * 64;
		for (unsigned i = count - 1; i; i--) {
			unsigned j = random_word() % (i + 1);
			uint32_t tmp = order[i]; order[i] = order[j]; order[j] = tmp;
		}
		for (unsigned i = 0; i < count; i++)
			*(uint32_t *)(base + order[i]) = order[(i + 1) % count];
		free(order);
		uint32_t index = chase(base, 0, steps / 2);
		for (unsigned run = 0; run < 3; run++) {
			struct rusage a, b;
			unsigned khz = frequency(cpu);
			getrusage(RUSAGE_THREAD, &a);
			uint64_t wall = ns(CLOCK_MONOTONIC_RAW), thread = ns(CLOCK_THREAD_CPUTIME_ID);
			index = chase(base, index, steps);
			thread = ns(CLOCK_THREAD_CPUTIME_ID) - thread;
			wall = ns(CLOCK_MONOTONIC_RAW) - wall;
			getrusage(RUSAGE_THREAD, &b);
			printf("{\"cpu\":%u,\"bytes\":%u,\"run\":%u,\"loads\":%u,"
			       "\"wall_ns_per_load\":%.3f,\"cpu_ns_per_load\":%.3f,"
			       "\"khz_before\":%u,\"khz_after\":%u,\"minor_faults\":%ld,"
			       "\"involuntary_switches\":%ld,\"check\":%u}\n",
			       cpu, bytes, run, steps, (double)wall / steps,
			       (double)thread / steps, khz, frequency(cpu),
			       b.ru_minflt - a.ru_minflt, b.ru_nivcsw - a.ru_nivcsw, index);
		}
		munmap(base, bytes);
	}
	return 0;
}
