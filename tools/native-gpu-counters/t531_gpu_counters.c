// SPDX-License-Identifier: GPL-2.0-only
/* Temporary counters only: Samsung adreno_a3xx.c, countable85 = AXI beats. */
#include <linux/io.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_address.h>
#include <linux/of_platform.h>
#include <linux/platform_device.h>
#include <linux/pm_runtime.h>
#include <linux/workqueue.h>

#define CNT_EN 0x1c0
#define CNT_SEL 0x1c8
#define OWNED_BITS 5U /* VBIF CNT0 and PWRCNT0 (waiting for RAM) */
#define AXI_BEATS 85U

static struct platform_device *gpu;
static void __iomem *regs;
static u32 saved_select;
static bool shader;
module_param(shader, bool, 0400);
MODULE_PARM_DESC(shader, "Also sample fixed SP/TP/UCHE performance selectors");
static void __iomem *selectors;
/* Register offsets in words; no HLSQ registers are accessed. */
static const struct { u32 reg, select; } samples[] = {
	/* PC and RB selectors from Mesa 25.0.7 a3xx.xml; no HLSQ access. */
	{ 0xc48, 0x0c }, { 0xc49, 0x09 }, { 0xc4a, 0x0a }, { 0xc4b, 0x0b },
	{ 0xcc6, 0x00 }, { 0xcc7, 0x05 },
	{ 0xec4, 0x1d }, { 0xec5, 0x20 }, { 0xec6, 0x21 }, { 0xec7, 0x22 },
	{ 0xec8, 0x23 }, { 0xec9, 0x0e }, { 0xeca, 0x0f }, { 0xecb, 0x0b },
	{ 0xf04, 0x01 }, { 0xf05, 0x02 }, { 0xf06, 0x1a }, { 0xf07, 0x1b },
	{ 0xf08, 0x17 }, { 0xf09, 0x19 },
	{ 0xe84, 0x12 }, { 0xe85, 0x13 }, { 0xe86, 0x14 }, { 0xe87, 0x00 },
};
static bool changed;
static DEFINE_MUTEX(counter_lock);

static void restore(struct work_struct *work)
{
	u32 enable, select;
	int i;

	mutex_lock(&counter_lock);
	if (changed) {
		enable = readl(regs + CNT_EN);
		select = readl(regs + CNT_SEL);
		writel(enable & ~OWNED_BITS, regs + CNT_EN);
		if ((select & 0x7f) == AXI_BEATS)
			writel((select & ~0x7fU) | (saved_select & 0x7f),
			       regs + CNT_SEL);
		else
			pr_warn("t531-gpu-counters: another client changed CNT0 selector\n");
		if (selectors) {
			for (i = 0; i < ARRAY_SIZE(samples); i++) {
				void __iomem *reg = selectors + (samples[i].reg - 0xc00) * 4;

				if (readl(reg) == samples[i].select)
					writel(0, reg);
				else
					pr_warn("t531-gpu-counters: selector %#x changed by another client\n",
						samples[i].reg);
			}
		}
		changed = false;
		pr_info("t531-gpu-counters: stopped; enable=%#x select=%#x\n",
			readl(regs + CNT_EN), readl(regs + CNT_SEL));
	}
	mutex_unlock(&counter_lock);
}
static DECLARE_DELAYED_WORK(restore_work, restore);

static int __init counters_init(void)
{
	struct device_node *np;
	struct resource resource;
	u32 enable;
	int ret, i;

	if (!of_machine_is_compatible("samsung,matisse3g"))
		return -ENODEV;
	np = of_find_compatible_node(NULL, NULL, "qcom,adreno-305.18");
	if (!np)
		return -ENODEV;
	ret = of_address_to_resource(np, 0, &resource);
	gpu = of_find_device_by_node(np);
	of_node_put(np);
	if (ret || !gpu || !gpu->dev.driver || resource.start != 0xfdb00000 ||
	    resource_size(&resource) < 0xd000) {
		ret = -ENODEV;
		goto put_device;
	}
	ret = pm_runtime_resume_and_get(&gpu->dev);
	if (ret < 0)
		goto put_device;
	regs = ioremap(resource.start + 0xc000, 0x1000);
	if (!regs) {
		ret = -ENOMEM;
		goto put_pm;
	}
	enable = readl(regs + CNT_EN);
	saved_select = readl(regs + CNT_SEL);
	if (enable & 0x1f) {
		ret = -EBUSY;
		goto unmap;
	}
	if (shader) {
		selectors = ioremap(resource.start + 0x3000, 0x1000);
		if (!selectors) {
			ret = -ENOMEM;
			goto unmap;
		}
		for (i = 0; i < ARRAY_SIZE(samples); i++) {
			if (readl(selectors + (samples[i].reg - 0xc00) * 4)) {
				ret = -EBUSY;
				goto unmap;
			}
		}
	}
	pr_info("t531-gpu-counters: enable=%#x select=%#x; AXI beats + RAM waits for30s\n",
		enable, saved_select);
	changed = true;
	if (selectors) {
		for (i = 0; i < ARRAY_SIZE(samples); i++)
			writel(samples[i].select, selectors + (samples[i].reg - 0xc00) * 4);
	}
	writel((saved_select & ~0x7fU) | AXI_BEATS, regs + CNT_SEL);
	writel(enable | OWNED_BITS, regs + CNT_EN);
	if (readl(regs + CNT_EN) != (enable | OWNED_BITS) ||
	    readl(regs + CNT_SEL) != ((saved_select & ~0x7fU) | AXI_BEATS)) {
		ret = -EIO;
		restore(NULL);
		goto unmap;
	}
	schedule_delayed_work(&restore_work, 30 * HZ);
	return 0;
unmap:
	iounmap(selectors);
	iounmap(regs);
put_pm:
	pm_runtime_put(&gpu->dev);
put_device:
	if (gpu)
		put_device(&gpu->dev);
	return ret;
}

static void __exit counters_exit(void)
{
	cancel_delayed_work_sync(&restore_work);
	restore(NULL);
	iounmap(selectors);
	iounmap(regs);
	pm_runtime_put(&gpu->dev);
	put_device(&gpu->dev);
}
module_init(counters_init);
module_exit(counters_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Bounded SM-T531 GPU bus counter diagnostic");
