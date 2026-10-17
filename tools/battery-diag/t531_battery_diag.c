// SPDX-License-Identifier: GPL-2.0-only
/*
 * Bounded read-only diagnostic for the SM-T531 PM8226 battery peripherals.
 * Register documentation: Samsung MSM8226 BSP commit
 * 3fa1853ed5d6c3a8ef5a2fda9822705243bbc256, drivers/power/qpnp-bms.c,
 * drivers/hwmon/qpnp-adc-current.c and arch/arm/boot/dts/msm-pm8226.dtsi.
 * No hold, clear, calibration, enable or charger register writes.
 * Multi-byte samples are intentionally unlocked: compare repeated snapshots
 * before interpreting them; this is not a production gauge driver.
 */
#include <linux/module.h>
#include <linux/of.h>
#include <linux/regmap.h>
#include <linux/spmi.h>
#include <linux/workqueue.h>

static struct device *pmic;
static struct regmap *map;

struct sample_range {
	u16 reg;
	u8 size;
	const char *name;
};

static const struct sample_range ranges[] = {
	{ 0x1208, 1, "battery-presence" },
	{ 0x3600, 6, "iadc-revision-type" },
	{ 0x3640, 10, "iadc-mode-channel" },
	{ 0x3660, 2, "iadc-last-data" },
	{ 0x36f0, 5, "iadc-trim" },
	{ 0x3800, 6, "bms-iadc-revision-type" },
	{ 0x3840, 10, "bms-iadc-mode-channel" },
	{ 0x385b, 1, "bms-iadc-fast-average" },
	{ 0x4000, 9, "bms-revision-type-status" },
	{ 0x4040, 7, "bms-mode-hold-clear-tolerance-enable" },
	{ 0x4080, 4, "bms-ocv-vsense-for-r" },
	{ 0x408a, 5, "bms-coulomb-counter" },
	{ 0x4090, 2, "bms-ocv-for-soc" },
	{ 0x4094, 2, "bms-vsense-poweron" },
	{ 0x4098, 2, "bms-vsense-average" },
	{ 0x409e, 2, "bms-vbat-average" },
	{ 0x40a8, 5, "bms-shadow-coulomb-counter" },
};

static void snapshot(struct work_struct *work)
{
	u8 data[10];
	int i, ret;

	for (i = 0; i < ARRAY_SIZE(ranges); i++) {
		ret = regmap_bulk_read(map, ranges[i].reg, data, ranges[i].size);
		if (ret)
			pr_err("t531-battery: %04x %s read error %d\n",
			       ranges[i].reg, ranges[i].name, ret);
		else
			pr_info("t531-battery: %04x %s %*ph\n",
				ranges[i].reg, ranges[i].name, ranges[i].size, data);
	}
}
static DECLARE_DELAYED_WORK(sample_work, snapshot);

static int __init t531_battery_diag_init(void)
{
	struct device_node *np;
	struct spmi_device *spmi;
	u32 usid;
	unsigned int type, subtype;
	int ret;

	if (!of_machine_is_compatible("samsung,matisse3g"))
		return -ENODEV;

	for_each_compatible_node(np, NULL, "qcom,pm8226") {
		if (!of_property_read_u32(np, "reg", &usid) && usid == 0)
			break;
	}
	if (!np)
		return -ENODEV;
	spmi = spmi_find_device_by_of_node(np);
	of_node_put(np);
	if (!spmi)
		return -EPROBE_DEFER;
	pmic = &spmi->dev;
	map = dev_get_regmap(pmic, NULL);
	if (!map) {
		ret = -ENODEV;
		goto put_pmic;
	}
	ret = regmap_read(map, 0x4004, &type);
	if (ret)
		goto put_pmic;
	ret = regmap_read(map, 0x4005, &subtype);
	if (ret)
		goto put_pmic;
	if (type != 0x0d || subtype != 1) {
		pr_err("t531-battery: unexpected BMS type=%02x subtype=%02x\n",
		       type, subtype);
		ret = -ENODEV;
		goto put_pmic;
	}
	pr_info("t531-battery: read-only PM8226 BMS1 snapshot; no register writes\n");
	snapshot(NULL);
	schedule_delayed_work(&sample_work, 2 * HZ);
	return 0;
put_pmic:
	put_device(pmic);
	return ret;
}

static void __exit t531_battery_diag_exit(void)
{
	cancel_delayed_work_sync(&sample_work);
	put_device(pmic);
}
module_init(t531_battery_diag_init);
module_exit(t531_battery_diag_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Read-only bounded SM-T531 PM8226 BMS register snapshots");
