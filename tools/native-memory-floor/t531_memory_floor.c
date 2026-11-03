// SPDX-License-Identifier: GPL-2.0-only
/* Bounded diagnostic: retain the stock 450-MHz OCMEM bandwidth request
 * while comparing lower GPU core OPPs. Never exceeds the DT's stock peak.
 */
#include <linux/interconnect.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_platform.h>
#include <linux/platform_device.h>
#include <linux/workqueue.h>
#include <linux/mutex.h>
static struct platform_device *gpu;
static struct icc_path *path;
static DEFINE_MUTEX(floor_lock);
static bool voted;
static void release_floor(struct work_struct *unused)
{
 int ret;
 mutex_lock(&floor_lock);
 if (voted) {
  ret = icc_set_bw(path, 0, 0);
  if (ret) pr_err("t531-memory-floor: release failed: %d\n", ret);
  else voted = false;
 }
 mutex_unlock(&floor_lock);
}
static DECLARE_DELAYED_WORK(timeout, release_floor);
static int __init floor_init(void)
{
 struct device_node *node;
 int ret;
 if (!of_machine_is_compatible("samsung,matisse3g")) return -ENODEV;
 node = of_find_compatible_node(NULL, NULL, "qcom,adreno-305.18");
 if (!node) return -ENODEV;
 gpu = of_find_device_by_node(node);
 of_node_put(node);
 if (!gpu) return -ENODEV;
 path = of_icc_get(&gpu->dev, "ocmem");
 if (IS_ERR_OR_NULL(path)) { ret = path ? PTR_ERR(path) : -ENODEV; goto put; }
 ret = icc_set_bw(path, 0, 6400000);
 if (ret) { icc_put(path); goto put; }
 voted = true;
 schedule_delayed_work(&timeout, msecs_to_jiffies(120000));
 pr_info("t531-memory-floor: stock OCMEM peak floor for at most 120 seconds\n");
 return 0;
put:
 put_device(&gpu->dev);
 return ret;
}
static void __exit floor_exit(void)
{
 cancel_delayed_work_sync(&timeout);
 release_floor(NULL);
 icc_put(path);
 put_device(&gpu->dev);
}
module_init(floor_init);
module_exit(floor_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Bounded SM-T531 stock OCMEM bandwidth floor diagnostic");
