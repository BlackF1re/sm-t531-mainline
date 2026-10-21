#!/usr/bin/env bash
# SM-T531 SD-only kernel trial. Restore the previous image on disk before
# graphics starts in the candidate boot; a subsequent reboot uses that image.
set -euo pipefail
[[ $EUID == 0 ]]
script=$(realpath "$0")
case ${1:-} in
    --restore|--rollback) ;;
    *) image=$(realpath "${1:?Missing candidate image}");;
esac
if [[ $# == 6 ]]; then
    newmodule=$(realpath "$5")
fi
module_dir=/lib/modules/$(uname -r)
module=$module_dir/kernel/drivers/gpu/drm/msm/msm.ko
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
[[ $(blkid -s LABEL -o value /dev/mmcblk1p1) == T531_BOOT ]]
[[ $(cat /sys/class/block/mmcblk1p1/size) == 98304 ]]
backup=/var/lib/t531/kernel-trial-backup
mountpoint=/run/t531-kernel-trial-boot
exec 9>/run/t531-kernel-trial.lock
flock -n 9
install -d "$mountpoint"
! findmnt -rn -S /dev/mmcblk1p1 >/dev/null
mount -t ext2 /dev/mmcblk1p1 "$mountpoint"
trap 'umount "$mountpoint"' EXIT
cd "$mountpoint"

if [[ ${1:-} == --restore || ${1:-} == --rollback ]]; then
    [[ $1 == --rollback || -f $backup/armed ]]
    (cd "$backup"; sha256sum -c saved.sha256)
    if [[ $1 == --rollback && -f $backup/kernel.release ]]; then
        module_dir=/lib/modules/$(cat "$backup/kernel.release")
        module=$module_dir/kernel/drivers/gpu/drm/msm/msm.ko
    fi
    # Restore the boot image before native graphics is allowed to start.
    cmp initramfs.cpio.gz "$backup/initramfs.cpio.gz"
    cmp kexec.cmdline "$backup/kexec.cmdline"
    cp "$backup/zImage" zImage.new
    cmp zImage.new "$backup/zImage"
    cp "$backup/kernel.sha256" kernel.sha256.new
    mv -T zImage.new zImage
    mv -T kernel.sha256.new kernel.sha256
    sha256sum -c kernel.sha256
    sync
    if [[ $1 == --rollback && -f $backup/msm.ko ]]; then
        if findmnt -rn -M "$module" >/dev/null; then
            cmp "$module" "$backup/candidate-msm.ko"
            umount "$module"
        fi
        cp "$backup/msm.ko" "$module.new"
        cmp "$module.new" "$backup/msm.ko"
        chmod 644 "$module.new"
        mv -T "$module.new" "$module"
    elif [[ -f $backup/candidate-msm.ko ]]; then
        # Keep the persistent module unchanged. This mount disappears on
        # reboot, so the previous kernel also gets its previous MSM module.
        cmp "$module" "$backup/msm.ko"
        [[ ! -d /sys/module/msm ]]
        mount --bind "$backup/candidate-msm.ko" "$module"
        cmp "$module" "$backup/candidate-msm.ko"
    fi
    if [[ $1 == --rollback && -d $backup/modules-meta ]]; then
        for file in "$backup"/modules-meta/*; do
            [[ -f $file ]] || continue
            install -m644 "$file" "$module_dir/$(basename "$file").new"
            mv -T "$module_dir/$(basename "$file").new" "$module_dir/$(basename "$file")"
        done
        depmod -a "$(uname -r)"
    fi
    rm -f "$backup/armed"
    sync
    echo 'Previous SD kernel restored for the NEXT boot; candidate remains in RAM.'
else
    [[ $# == 4 || $# == 6 ]] || {
        echo 'Usage: trial-graphics-kernel.sh IMAGE OLD_SHA NEW_SHA MSM_SHA [MODULE MODULE_SHA]'
        exit 2
    }
    [[ $2 =~ ^[a-f0-9]{64}$ && $3 =~ ^[a-f0-9]{64}$ && $4 =~ ^[a-f0-9]{64}$ ]]
    [[ $(sha256sum zImage | cut -d' ' -f1) == "$2" ]]
    [[ $(sha256sum "$image" | cut -d' ' -f1) == "$3" ]]
    [[ $(sha256sum "$module" | cut -d' ' -f1) == "$4" ]]
    if [[ $# == 6 ]]; then
        [[ $6 =~ ^[a-f0-9]{64}$ ]]
        [[ $(sha256sum "$newmodule" | cut -d' ' -f1) == "$6" ]]
        [[ $(modinfo -F vermagic "$newmodule") == "$(modinfo -F vermagic "$module")" ]]
    fi
    sha256sum -c kernel.sha256
    [[ ! -e $backup ]]
    install -d -m700 "$backup"
    cp -a zImage initramfs.cpio.gz kernel.sha256 kexec.cmdline "$backup/"
    uname -r >"$backup/kernel.release"
    install -d -m700 "$backup/modules-meta"
    for file in modules.builtin modules.builtin.modinfo modules.order; do
        [[ ! -f $module_dir/$file ]] || cp -a "$module_dir/$file" "$backup/modules-meta/"
    done
    if [[ $# == 6 ]]; then
        cp -a "$module" "$backup/msm.ko"
        cp "$newmodule" "$backup/candidate-msm.ko"
        chmod 644 "$backup/candidate-msm.ko"
    fi
    (cd "$backup"; sha256sum zImage initramfs.cpio.gz kernel.sha256 kexec.cmdline kernel.release >saved.sha256
     [[ ! -f msm.ko ]] || sha256sum msm.ko >>saved.sha256
     [[ ! -f candidate-msm.ko ]] || sha256sum candidate-msm.ko >>saved.sha256
     find modules-meta -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum >>saved.sha256
     sha256sum -c saved.sha256)
    install -d /usr/local/libexec
    install -m755 "$script" /usr/local/libexec/t531-kernel-trial-restore.new
    mv -T /usr/local/libexec/t531-kernel-trial-restore.new /usr/local/libexec/t531-kernel-trial-restore
    cat >/etc/systemd/system/t531-kernel-trial-restore.service <<'EOF'
[Unit]
Description=Restore previous SD kernel for the next boot after a one-boot trial
After=local-fs.target
Before=t531-native-graphics.service sddm.service
ConditionPathExists=/var/lib/t531/kernel-trial-backup/armed
[Service]
Type=oneshot
ExecStart=/usr/local/libexec/t531-kernel-trial-restore --restore
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable t531-kernel-trial-restore.service
    touch "$backup/armed"
    sync
    cp "$image" zImage.new
    [[ $(sha256sum zImage.new | cut -d' ' -f1) == "$3" ]]
    { printf '%s  zImage\n' "$3"; sha256sum initramfs.cpio.gz; } >kernel.sha256.new
    mv -T zImage.new zImage
    mv -T kernel.sha256.new kernel.sha256
    sha256sum -c kernel.sha256
    sync
    echo 'Candidate staged on SD. Early boot failures still require bootstrap recovery.'
fi
cd /
umount "$mountpoint"
trap - EXIT
