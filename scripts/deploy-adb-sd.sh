#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[ "${FORMAT_SD:-}" = yes ] || { echo 'Formatting erases both microSD partitions. Set FORMAT_SD=yes after preserving its data.'; exit 1; }
serial=${ADB_SERIAL:-$(adb -d get-serialno)}
[[ "$serial" != unknown ]] || { echo 'No USB tablet'; exit 1; }
adb_cmd=(adb -s "$serial")
bb=/data/local/tmp/t531-tools/busybox
boot=/data/local/tmp/t531-boot
root=/data/local/tmp/t531-root
[ "$("${adb_cmd[@]}" shell getprop ro.product.model | tr -d '\r')" = SM-T531 ]
"${adb_cmd[@]}" exec-out id | rg -q 'uid=0'
# This operation supports the identified external SDC2 slot only, never mmcblk0.
"${adb_cmd[@]}" exec-out 'cat /sys/class/mmc_host/mmc1/mmc*:*/type' | tr -d '\r' | rg -qx SD
sectors=$("${adb_cmd[@]}" exec-out cat /sys/class/block/mmcblk1/size | tr -d '\r')
[ "$sectors" = 30253056 ] || { echo 'Different card: re-inspect size and partition layout'; exit 1; }
[ "$("${adb_cmd[@]}" exec-out cat /sys/class/block/mmcblk1p1/start | tr -d '\r')" = 2048 ]
[ "$("${adb_cmd[@]}" exec-out cat /sys/class/block/mmcblk1p1/size | tr -d '\r')" = 98304 ]
[ "$("${adb_cmd[@]}" exec-out cat /sys/class/block/mmcblk1p2/start | tr -d '\r')" = 100352 ]
[ "$("${adb_cmd[@]}" exec-out cat /sys/class/block/mmcblk1p2/size | tr -d '\r')" = 30152704 ]
a=.work/artifacts/current
(cd "$a"; sha256sum -c SHA256SUMS)
[ -s "$a/debian-armhf.tar.gz" ]
"${adb_cmd[@]}" shell mkdir -p /data/local/tmp/t531-tools
"${adb_cmd[@]}" push .work/busybox/usr/bin/busybox "$bb"
"${adb_cmd[@]}" shell chmod 700 "$bb"
remote() {
    local result
    result=$("${adb_cmd[@]}" exec-out "$bb sh -c 'set -e; $1; echo T531_OK'")
    printf '%s\n' "$result"
    [[ "$result" == *T531_OK ]] || { echo 'Tablet operation failed'; exit 1; }
}
# Ask vold to release its FAT volume before any block write.
"${adb_cmd[@]}" shell vdc volume unmount public:179,65 || true
mounts=$("${adb_cmd[@]}" exec-out cat /proc/mounts)
if printf '%s\n' "$mounts" | rg -q 'mmcblk1|/dev/block/vold/public:179,65'; then
    echo 'Card remains mounted: stop before formatting'; exit 1
fi
remote "/system/bin/mke2fs -t ext2 -L T531_BOOT /dev/block/mmcblk1p1"
remote "/system/bin/mke2fs -t ext4 -L T531_ROOT /dev/block/mmcblk1p2"
remote "mkdir -p $boot $root; $bb mount -t ext2 /dev/block/mmcblk1p1 $boot; $bb mount -t ext4 /dev/block/mmcblk1p2 $root"
"${adb_cmd[@]}" push "$a/zImage" "$a/qcom-msm8226-samsung-matisse3g.dtb" "$a/initramfs.cpio.gz" \
    "$a/kernel.sha256" "$a/kexec.cmdline" "$boot/"
remote "mkdir -p $boot/extlinux"
"${adb_cmd[@]}" push "$a/extlinux.conf" "$boot/extlinux/extlinux.conf"
# Old adbd does not propagate exec-in exit status: persist the result remotely.
remote 'rm -f /data/local/tmp/t531-rootfs-result'
"${adb_cmd[@]}" exec-in "$bb sh -c '$bb gzip -dc | $bb tar -xpf - -C $root; echo \$? > /data/local/tmp/t531-rootfs-result'" < "$a/debian-armhf.tar.gz"
for attempt in $(seq 1 120); do
    result=$("${adb_cmd[@]}" exec-out cat /data/local/tmp/t531-rootfs-result 2>/dev/null | tr -d '\r')
    if [[ "$result" =~ ^[0-9]+$ ]]; then break; fi
    sleep 1
done
[ "$result" = 0 ] || { echo 'Rootfs extraction failed or did not finish'; exit 1; }
remote "test -x $root/sbin/init; test -x $root/usr/sbin/sshd; sync"
remote "$bb umount $root; $bb umount $boot"
echo 'Debian and diagnostic extlinux boot files deployed to the verified microSD.'
