#!/bin/sh
# Run in the SM-T531 bootstrap USB shell. SD-only verified fallback restore.
set -eu
[ "$(id -u)" = 0 ]
tr '\000' '\n' < /proc/device-tree/compatible | grep -qx samsung,matisse3g
[ "$(cat /sys/class/block/mmcblk1p1/size)" = 98304 ]
# ext2 superblock label; rescue BusyBox intentionally has no blkid applet.
[ "$(dd if=/dev/mmcblk1p1 bs=1 skip=1144 count=16 2>/dev/null | tr -d '\000')" = T531_BOOT ]
umount-sd
mount-sd rw
trap 'cd /; sync; umount-sd' EXIT
state=/mnt/sd-root/var/lib/t531/graphics-ab
[ -d "$state" ]
cd /mnt/sd-boot/graphics-slots/golden
sha256sum -c kernel.sha256
# Unique module releases remain installed; the early guard restores config.
touch "$state/pending"
sync
cd /mnt/sd-boot
[ -L graphics-current ]
ln -s graphics-slots/golden graphics-current.rescue
mv -Tf graphics-current.rescue graphics-current
sync
cd /
umount-sd
trap - EXIT
echo 'Verified golden SD slot selected. Run boot-sd to start recovery.'
