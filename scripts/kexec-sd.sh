#!/bin/sh
set -eu
export PATH=/bin:/sbin
mode=${1:---exec}
case "$mode" in --load|--exec) ;; *) echo 'Usage: kexec-sd.sh [--load|--exec]'; exit 1;; esac
mkdir -p /newroot
mounted=
for attempt in $(seq 1 20); do
    if mount -t ext2 -o ro LABEL=T531_BOOT /newroot; then
        mounted=yes
        break
    fi
    sleep 1
done
[ "$mounted" = yes ] || { echo 'SD boot partition unavailable'; exit 1; }
trap 'umount /newroot' EXIT
cd /newroot
[ -s zImage ] && [ -s initramfs.cpio.gz ] && [ -s kexec.cmdline ]
# Verify exactly the two loaded files, never execute card content as a script.
[ "$(wc -l < kernel.sha256)" -eq 2 ]
awk 'NF != 2 || ($2 != "zImage" && $2 != "initramfs.cpio.gz") {bad=1}
     {seen[$2]++} END {exit bad || seen["zImage"] != 1 || seen["initramfs.cpio.gz"] != 1}' kernel.sha256
sha256sum -c kernel.sha256
cmdline=$(cat kexec.cmdline)
case "$cmdline" in *t531.kexec*) echo 'Refusing a recursive kexec command line'; exit 1;; esac
# Reuse lk2nd's live DT: it includes actual RAM and inherited framebuffer data.
kexec -l /newroot/zImage --dtb=/sys/firmware/fdt \
    --initrd=/newroot/initramfs.cpio.gz --append="$cmdline"
cd /
umount /newroot
trap - EXIT
echo 'Second-stage kernel loaded from read-only microSD'
[ "$mode" = --load ] || exec kexec -e
