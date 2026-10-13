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
# The automatic zImage estimate stalled multi_v7 at handoff on this board.
# The same kernel booted with initrd/DT above a tested 64 MiB image allowance.
load_status=0
kexec -d -l /newroot/zImage --image-size=0x04000000 --dtb=/sys/firmware/fdt \
    --initrd=/newroot/initramfs.cpio.gz --append="$cmdline" \
    > /run/t531-kexec.log 2>&1 || load_status=$?
cat /run/t531-kexec.log
cd /
umount /newroot
trap - EXIT
# Preserve segment addresses and first-stage evidence before leaving this kernel.
if mount -t ext4 -o rw LABEL=T531_ROOT /newroot; then
    mkdir -p /newroot/var/log
    { cat /proc/cmdline; cat /run/t531-kexec.log; dmesg; } > /newroot/var/log/t531-bootstrap.log
    # Keep the preceding kernel's persistent records before the next boot
    # reuses the same ramoops area. Do not erase the pstore source.
    for record in /sys/fs/pstore/*; do
        [ -f "$record" ] || continue
        mkdir -p /newroot/var/log/t531-pstore
        cp "$record" /newroot/var/log/t531-pstore/
    done
    sync
    umount /newroot
fi
[ "$load_status" -eq 0 ] || exit "$load_status"
echo 'Second-stage kernel loaded from read-only microSD'
[ "$mode" = --load ] || exec kexec -e
