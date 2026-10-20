// SPDX-License-Identifier: GPL-2.0-only
/* Temporary recovery for a WLAN driver unbound with edge-triggered DT IRQs.
 * Run only while the WLAN platform device is unbound. No firmware access.
 */
#include <linux/module.h>
#include <linux/irq.h>
#include <linux/irqdomain.h>
#include <linux/of.h>
#include <linux/platform_device.h>

static bool apply;
module_param(apply, bool, 0400);

static int __init t531_wifi_irq_rearm_init(void)
{
	struct device *dev;
	struct irq_data *data;
	unsigned int irq, found = 0;
	u32 tx_type, rx_type;
	int ret;

	if (!of_machine_is_compatible("samsung,matisse3g"))
		return -ENODEV;
	dev = bus_find_device_by_name(&platform_bus_type, NULL,
			      "fb204000.remoteproc:smd-edge:wcnss:wifi");
	if (!dev)
		return -ENODEV;
	device_lock(dev);
	if (dev->driver) {
		ret = -EBUSY;
		goto out;
	}
	/* Never undo the corrected level-high DT on newer kernels. */
	if (of_property_read_u32_index(dev->of_node, "interrupts", 2, &tx_type) ||
	    of_property_read_u32_index(dev->of_node, "interrupts", 5, &rx_type) ||
	    tx_type != IRQ_TYPE_EDGE_RISING || rx_type != IRQ_TYPE_EDGE_RISING) {
		ret = -EOPNOTSUPP;
		goto out;
	}
	for (irq = 1; irq < 4096; irq++) {
		data = irq_get_irq_data(irq);
		if (!data || !data->domain ||
		    (data->hwirq != 177 && data->hwirq != 178) ||
		    !of_device_is_compatible(irq_domain_get_of_node(data->domain),
				     "qcom,msm-qgic2"))
			continue;
		pr_info("t531_wifi_irq_rearm: irq=%u hwirq=%lu type=%u apply=%u\n",
			irq, data->hwirq, irqd_get_trigger_type(data), apply);
		if (apply) {
			ret = irq_set_irq_type(irq, IRQ_TYPE_EDGE_RISING);
			if (ret)
				goto out;
		}
		found++;
	}
	ret = found == 2 ? 0 : -ENODEV;
out:
	device_unlock(dev);
	put_device(dev);
	return ret;
}

static void __exit t531_wifi_irq_rearm_exit(void)
{
}
module_init(t531_wifi_irq_rearm_init);
module_exit(t531_wifi_irq_rearm_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("SM-T531 temporary unbound WLAN IRQ recovery");
