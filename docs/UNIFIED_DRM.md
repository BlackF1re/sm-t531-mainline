# SD graphics update and recovery

Technical architecture: [GPU](../Porting%20Notes/gpu.md),
[display](../Porting%20Notes/display.md), [storage](../Porting%20Notes/storage.md).
This guide is the supported replacement for the retired in-place trial writer.

1. Build the main profile (`make build`, optionally `SD_ONLY=1`). Build probes
   using `scripts/graphics/build-probe.sh` with an existing `DRM_SYSROOT`.
2. Before an approved device update, run `scripts/graphics/snapshot.sh` on the
   tablet. Verify its SD boot files, complete module tree and configuration/
   absence manifest. Keep the baseline and golden slot.
3. Use installed `t531-graphics-ab prepare BASELINE TRIAL_DIR RELEASE` (source
   `scripts/graphics/ab.sh`) to stage an immutable slot with a unique release.
   Check the script's usage and artifacts; do not mix modules across releases.
4. The early guard selects golden for next boot before graphics and arms a
   fifteen-minute rollback. A failed/wedged kernel can still need physical
   recovery: the userspace timer is not a hardware watchdog.
5. `confirm-session` stops the timer without promotion. `promote PROD_DIR`
   stages production. `confirm-boot` accepts an observed production boot;
   `confirm-primary` selects a verified running candidate without claiming a
   fresh cold boot. Do not confirm from a successful build/probe alone.
6. `recover` restores the checked baseline. Rescue shell helper
   `scripts/restore-native-from-bootstrap.sh` selects golden.

The controller only writes verified SD `/dev/mmcblk1p1`, never eMMC.
Slot tests cover interrupted staging, corruption and backed-up retirement;
run `make check`. Responsive rollback worked; cold/endurance acceptance is
separate. Preserve remote access and obtain approval before reboot or changing
active graphics. See [recovery procedures](RECOVERY.md).
