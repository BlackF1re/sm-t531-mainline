#!/bin/sh
set -eu
export PATH=/bin:/sbin
mounted() {
    awk -v path="$1" '$2 == path {found=1} END {exit !found}' /proc/mounts
}
mount_sd() {
    mode=${1:-ro}
    case "$mode" in ro|rw) ;; *) echo 'Usage: mount-sd [ro|rw]'; return 1;; esac
    mkdir -p /mnt/sd-boot /mnt/sd-root
    mounted /mnt/sd-boot || mount -t ext2 -o "$mode" LABEL=T531_BOOT /mnt/sd-boot
    root_mode=$mode
    [ "$mode" != ro ] || root_mode=ro,noload
    mounted /mnt/sd-root || mount -t ext4 -o "$root_mode" LABEL=T531_ROOT /mnt/sd-root
}
unmount_sd() {
    cd /
    for path in /mnt/sd-boot /mnt/sd-root /mnt/internal-boot; do
        mounted "$path" && umount "$path" || {
            mounted "$path" && return 1
            :
        }
    done
    if [ -f /run/internal-boot-loop ]; then
        losetup -d "$(cat /run/internal-boot-loop)"
        rm /run/internal-boot-loop
    fi
}
case "$(basename "$0")" in
    mount-sd) mount_sd "${1:-ro}";;
    umount-sd) unmount_sd;;
    mount-internal-boot)
        grep -q 'SM-T531' /proc/device-tree/model
        [ "$(cat /sys/class/block/mmcblk0p14/start)" = 209536 ]
        [ "$(cat /sys/class/block/mmcblk0p14/size)" = 20480 ]
        mkdir -p /mnt/internal-boot
        mounted /mnt/internal-boot && exit 0
        loop=$(losetup -f)
        losetup -r -o 524288 "$loop" /dev/mmcblk0p14
        mount -t ext2 -o ro "$loop" /mnt/internal-boot || { losetup -d "$loop"; exit 1; }
        echo "$loop" > /run/internal-boot-loop
        ;;
    save-logs)
        unmount_sd
        mount_sd rw
        destination=/mnt/sd-root/var/log/t531-rescue
        mkdir -p "$destination/pstore"
        dmesg > "$destination/bootstrap-dmesg.log"
        cat /proc/cmdline > "$destination/bootstrap-cmdline"
        for record in /sys/fs/pstore/*; do
            [ -f "$record" ] || continue
            cp "$record" "$destination/pstore/"
        done
        sync
        unmount_sd
        echo "Saved logs on T531_ROOT at /var/log/t531-rescue"
        ;;
    boot-sd)
        mkdir /run/t531-kexec.lock 2>/dev/null || { echo 'Another SD boot is in progress'; exit 1; }
        trap 'rmdir /run/t531-kexec.lock' EXIT
        unmount_sd
        /bin/sh /kexec-sd.sh --exec
        ;;
    *) echo 'Commands: boot-sd, mount-sd [ro|rw], umount-sd, mount-internal-boot, save-logs'; exit 1;;
esac
