// SPDX-License-Identifier: GPL-2.0-only
/* Read CPU cache control/capacity. Restore the core-local CSSELR selector. */
#include <linux/cpu.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/smp.h>
#include <asm/cachetype.h>
#include <asm/cp15.h>
#include <asm/cputype.h>
#include <asm/barrier.h>

struct cache_snapshot {
	u32 midr, mpidr, sctlr, actlr, clidr;
	u32 data[2], instruction[2];
	bool valid, restored;
};
static struct cache_snapshot snapshots[NR_CPUS];

static void snapshot_cpu(void *unused)
{
	struct cache_snapshot *s = &snapshots[smp_processor_id()];
	unsigned long flags;
	u32 selector, restored;
	int level;

	s->midr = read_cpuid_id();
	if ((s->midr & ARM_CPU_PART_MASK) != ARM_CPU_PART_CORTEX_A7)
		return;
	local_irq_save(flags);
	s->mpidr = read_cpuid_mpidr();
	s->sctlr = get_cr();
	s->actlr = get_auxcr();
	s->clidr = read_clidr();
	asm volatile("mrc p15, 2, %0, c0, c0, 0" : "=r" (selector));
	for (level = 0; level < 2; level++) {
		u32 type = (s->clidr >> (level * 3)) & 7;

		if (type == 2 || type == 3 || type == 4) {
			set_csselr(level << 1);
			isb();
			s->data[level] = read_ccsidr();
		}
		if (type == 1 || type == 3) {
			set_csselr((level << 1) | CSSELR_ICACHE);
			isb();
			s->instruction[level] = read_ccsidr();
		}
	}
	set_csselr(selector);
	isb();
	asm volatile("mrc p15, 2, %0, c0, c0, 0" : "=r" (restored));
	s->restored = restored == selector;
	s->valid = true;
	local_irq_restore(flags);
}

static unsigned int cache_bytes(u32 ccsidr)
{
	if (!ccsidr)
		return 0;
	return (16U << (ccsidr & 7)) * (((ccsidr >> 3) & 1023) + 1) *
		(((ccsidr >> 13) & 32767) + 1);
}

static int __init cache_state_init(void)
{
	int cpu;

	if (!of_machine_is_compatible("samsung,matisse3g"))
		return -ENODEV;
	cpus_read_lock();
	on_each_cpu(snapshot_cpu, NULL, 1);
	for_each_online_cpu(cpu) {
		struct cache_snapshot *s = &snapshots[cpu];

		pr_info("t531-cache: cpu=%d valid=%u midr=%08x mpidr=%08x sctlr=%08x actlr=%08x clidr=%08x MMU=%u D=%u I=%u SMP=%u selector_restored=%u\n",
			cpu, s->valid, s->midr, s->mpidr, s->sctlr, s->actlr,
			s->clidr, !!(s->sctlr & CR_M), !!(s->sctlr & CR_C),
			!!(s->sctlr & CR_I), !!(s->actlr & BIT(6)), s->restored);
		pr_info("t531-cache: cpu=%d L1D=%u L1I=%u L2=%u ccsidr=%08x/%08x/%08x\n",
			cpu, cache_bytes(s->data[0]), cache_bytes(s->instruction[0]),
			cache_bytes(s->data[1]), s->data[0], s->instruction[0], s->data[1]);
	}
	cpus_read_unlock();
	return 0;
}
static void __exit cache_state_exit(void) {}
module_init(cache_state_init);
module_exit(cache_state_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Bounded SM-T531 CPU cache-control observation");
