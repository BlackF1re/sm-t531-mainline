#!/usr/bin/env bash
# Restore a verified SD kernel snapshot. Never opens an internal eMMC partition.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run as root on SM-T531'; exit 1; }
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
[[ $(blkid -s LABEL -o value /dev/mmcblk1p1) == T531_BOOT ]]
[[ $(cat /sys/class/block/mmcblk1p1/size) == 98304 ]]
case "${1:-original}" in
    original) backup=/var/lib/t531/graphics-rollback;;
    native) backup=/var/lib/t531/native-kms-rollback;;
    *) echo 'Usage: restore-graphics-kernel.sh [original|native]'; exit 1;;
esac
cd "$backup"
sha256sum -c boot-files.sha256
sha256sum -c modules.sha256
install -d -m 755 /run/t531-boot
mount -t ext2 /dev/mmcblk1p1 /run/t531-boot
trap 'cd /; umount /run/t531-boot' EXIT
for file in zImage initramfs.cpio.gz kernel.sha256 kexec.cmdline; do
    cp "$backup/$file" "/run/t531-boot/$file.new"
    cmp "$backup/$file" "/run/t531-boot/$file.new"
done
# Verify staged kernel/initramfs before replacing the boot files.
sed -e 's/zImage$/zImage.new/' -e 's/initramfs.cpio.gz$/initramfs.cpio.gz.new/' \
    kernel.sha256 > /run/t531-boot/rollback-staged.sha256
cd /run/t531-boot
sha256sum -c rollback-staged.sha256
for file in zImage initramfs.cpio.gz kernel.sha256 kexec.cmdline; do
    mv "$file.new" "$file"
done
sha256sum -c kernel.sha256
module_stage=$(mktemp -d /var/lib/t531/modules-restore.XXXXXX)
tar -xzf "$backup/modules.tar.gz" -C "$module_stage"
version=7.2.9-dirty
new="$module_stage/lib/modules/$version"
[[ -f $new/modules.dep && -f $new/modules.builtin ]]
current="/lib/modules/$version"
previous="/var/lib/t531/modules-before-restore.$$"
[[ ! -e $previous ]]
if [[ -d $current ]]; then
    mv "$current" "$previous"
fi
if ! mv "$new" "$current"; then
    [[ ! -d $previous ]] || mv "$previous" "$current"
    exit 1
fi
if ! depmod -a "$version"; then
    mv "$current" "$module_stage/failed-modules"
    [[ ! -d $previous ]] || mv "$previous" "$current"
    depmod -a "$version"
    exit 1
fi
rm -rf "$module_stage"
sync
cd /
umount /run/t531-boot
trap - EXIT
if [[ ${1:-original} == native ]]; then
    install -m 644 "$backup/config/environment.conf" /etc/environment.d/60-t531-graphics.conf
    install -m 644 "$backup/config/sddm.conf" /etc/systemd/system/sddm.service.d/20-t531-graphics.conf
    rm -f /home/t531/.config/systemd/user/plasma-kwin_wayland.service.d/40-t531-native-loader.conf
    systemctl daemon-reload
fi
echo 'Verified SD kernel and graphics configuration restored. Run systemctl reboot to load it.'
