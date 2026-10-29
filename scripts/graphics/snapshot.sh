#!/bin/bash
# Read-only microSD boot snapshot; does not change boot/config/module state.
set -Eeuo pipefail
[[ $EUID == 0 ]]
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
[[ $(blkid -s LABEL -o value /dev/mmcblk1p1) == T531_BOOT ]]
[[ $(cat /sys/class/block/mmcblk1p1/size) == 98304 ]]
[[ $(findmnt -rn -o SOURCE /) == /dev/mmcblk1p2 ]]
[[ $(blkid -s LABEL -o value /dev/mmcblk1p2) == T531_ROOT ]]
! findmnt -rn -S /dev/mmcblk1p1 >/dev/null
base=/var/lib/t531/graphics-baselines
id=$(date -u +%Y%m%dT%H%M%SZ)
dest=$base/$id
[[ ! -e $dest ]]
[[ $(df --output=avail -B1 /var/lib/t531 | tail -1) -gt 1073741824 ]]
install -d -m700 "$dest/boot" "$dest/meta"
printf '%s\n' "$(uname -r)" > "$dest/kernel.release"
release=$(cat "$dest/kernel.release")
[[ $release =~ ^[0-9][a-zA-Z0-9._+-]+$ ]]
[[ -d /lib/modules/$release ]]
# A nested module bind mount makes on-disk and running module provenance differ.
if findmnt -rn -o TARGET | grep -Eq '^/(usr/)?lib/modules/'; then
 echo 'Module bind mount found: resolve provenance before snapshotting' >&2;exit 1
fi
point=$(mktemp -d /run/t531-boot-snapshot.XXXXXX)
trap 'umount "$point" 2>/dev/null || true; rmdir "$point" 2>/dev/null || true' EXIT
mount -t ext2 -o ro /dev/mmcblk1p1 "$point"
(cd "$point"; sha256sum -c kernel.sha256)
cp -a "$point/." "$dest/boot/"
umount "$point"; rmdir "$point"; trap - EXIT
paths=(etc/modprobe.d/msm.conf etc/environment.d/60-t531-graphics.conf
 etc/systemd/system/t531-native-graphics.service etc/systemd/system/t531-native-graphics.service.d
 etc/systemd/system/t531-native-kms-recovery.service
 etc/systemd/system/sddm.service.d
 usr/local/sbin/t531-start-native-graphics usr/local/sbin/t531-graphics-rollback
 home/t531/.config/systemd/user/plasma-kwin_wayland.service.d
 home/t531/.config/systemd/user/plasma-plasmashell.service.d home/t531/.config/kdeglobals
 etc/modules-load.d)
printf '%s\n' "${paths[@]}" > "$dest/meta/config-paths.txt"
existing=()
for p in "${paths[@]}"; do [[ ! -e /$p && ! -L /$p ]] || existing+=("$p"); done
printf '%s\n' "${existing[@]}" > "$dest/meta/config-existing.txt"
tar -C / -czf "$dest/config.tar.gz" -- "${existing[@]}"
nice -n 19 tar -C / -czf "$dest/modules.tar.gz" -- "lib/modules/$release"
uname -a > "$dest/meta/uname.txt"
cat /proc/cmdline > "$dest/meta/cmdline.txt"
findmnt -rn -o TARGET,SOURCE,FSTYPE > "$dest/meta/mounts.txt"
dpkg-divert --list > "$dest/meta/diversions.txt"
dpkg-query -W 'plasma-mobile' 'kwin*' 'libqt6gui6*' 'libgl1-mesa-dri*' 'libegl-mesa0*' 'libgbm1*' > "$dest/meta/packages.txt"
modinfo -F vermagic msm > "$dest/meta/msm.vermagic"
[[ $(cut -d' ' -f1 "$dest/meta/msm.vermagic") == "$release" ]]
# Preserve exact libraries affected by earlier trials, including their originals.
libs=(usr/lib/arm-linux-gnueabihf/qt6/qml/org/kde/plasma/private/mobileshell/libmobileshellplugin.so)
[[ ! -e /${libs[0]}.t531-original ]] || libs+=("${libs[0]}.t531-original")
tar -C / -czf "$dest/graphics-libraries.tar.gz" -- "${libs[@]}"
(cd "$dest"; find boot meta -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > files.sha256; sha256sum kernel.release config.tar.gz modules.tar.gz graphics-libraries.tar.gz >> files.sha256; sha256sum -c files.sha256 > verify.log)
tar -tzf "$dest/modules.tar.gz" >/dev/null
tar -tzf "$dest/config.tar.gz" >/dev/null
touch "$dest/COMPLETE"
sync -f "$dest"
printf '%s\n' "$dest"
