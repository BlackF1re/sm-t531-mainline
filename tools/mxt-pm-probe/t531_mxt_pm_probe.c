// SPDX-License-Identifier: GPL-2.0-only
/* One-shot diagnostic: exercise only the SM-T531 touch driver's PM callbacks. */
#include <linux/delay.h>
#include <linux/device.h>
#include <linux/i2c.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/pm.h>

static int __init t531_mxt_pm_probe_init(void)
{
	const struct dev_pm_ops *pm;
	struct device *dev;
	int ret;

	if (!of_machine_is_compatible("samsung,matisse3g"))
		return -ENODEV;
	dev = bus_find_device_by_name(&i2c_bus_type, NULL, "4-004a");
	if (!dev)
		return -ENODEV;
	device_lock(dev);
	if (!dev->driver || strcmp(dev->driver->name, "atmel_mxt_ts") ||
	    !dev->driver->pm || !dev->driver->pm->suspend ||
	    !dev->driver->pm->resume) {
		ret = -ENODEV;
		goto out;
	}
	pm = dev->driver->pm;
	ret = pm->suspend(dev);
	if (!ret) {
		msleep(100);
		ret = pm->resume(dev);
	}
	dev_info(dev, "touch-only PM diagnostic completed: %d\n", ret);
out:
	device_unlock(dev);
	put_device(dev);
	return ret;
}

static void __exit t531_mxt_pm_probe_exit(void)
{
}

module_init(t531_mxt_pm_probe_init);
module_exit(t531_mxt_pm_probe_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("SM-T531 one-shot maXTouch PM diagnostic, no system sleep");
