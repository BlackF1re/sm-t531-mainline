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
backup=/mnt/sd-root/var/lib/t531/native-kms-rollback
cd "$backup"
sha256sum -c boot-files.sha256
sha256sum -c modules.sha256
for file in zImage initramfs.cpio.gz kernel.sha256 kexec.cmdline; do
    cp "$backup/$file" "/mnt/sd-boot/$file.new"
    cmp "$backup/$file" "/mnt/sd-boot/$file.new"
done
sed -e 's/zImage$/zImage.new/' -e 's/initramfs.cpio.gz$/initramfs.cpio.gz.new/' \
    kernel.sha256 > /mnt/sd-boot/rollback-staged.sha256
cd /mnt/sd-boot
sha256sum -c rollback-staged.sha256
for file in zImage initramfs.cpio.gz kernel.sha256 kexec.cmdline; do
    mv "$file.new" "$file"
done
sha256sum -c kernel.sha256
# The release string is shared by diagnostic configurations. Replace the
# complete tree so modules made built-in cannot leave obsolete .ko files.
module_stage=/mnt/sd-root/var/lib/t531/modules-restore.$$
mkdir "$module_stage"
tar -xzf "$backup/modules.tar.gz" -C "$module_stage"
version=7.2.9-dirty
new="$module_stage/lib/modules/$version"
[ -f "$new/modules.dep" ]
[ -f "$new/modules.builtin" ]
current="/mnt/sd-root/lib/modules/$version"
previous="/mnt/sd-root/var/lib/t531/modules-before-restore.$$"
[ ! -e "$previous" ]
if [ -d "$current" ]; then
    mv "$current" "$previous"
fi
if ! mv "$new" "$current"; then
    [ ! -d "$previous" ] || mv "$previous" "$current"
    exit 1
fi
rm -rf "$module_stage"
cp "$backup/config/environment.conf" /mnt/sd-root/etc/environment.d/60-t531-graphics.conf
cp "$backup/config/sddm.conf" /mnt/sd-root/etc/systemd/system/sddm.service.d/20-t531-graphics.conf
rm -f /mnt/sd-root/home/t531/.config/systemd/user/plasma-kwin_wayland.service.d/40-t531-native-loader.conf
sync
cd /
umount-sd
trap - EXIT
echo 'Verified SD fallback restored. Run boot-sd to start it.'
