# microSD / SDHCI2

* Native root uses `mmcblk1p2`, ext4, label T531_ROOT. Boot is `mmcblk1p1`, 48 MiB
  ext2, label T531_BOOT. This SD path is independent of Android userspace.
* GPIO38 card-detect IRQ78 exceeded3million interrupts and mmc1 generated
  hundreds of thousands of wake events. Suspend aborted during filesystem
  sync with−EBUSY; globally masking IRQs was not a valid graphics fix.
* Patch 0130 removes `cd-gpios` and selects `broken-cd` polling. Retain SD data/
  power IRQs and socket removability. CD wake count became0;16-MiB random
  write/fsync/full hash readback passed (~2.608s). Root-device hot removal and
  general hotplug/card/signal-mode/endurance acceptance remain incomplete.
