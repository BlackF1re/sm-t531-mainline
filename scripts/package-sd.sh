#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
a=${ARTIFACTS_DIR:-$PWD/../build/sm-t531/artifacts/current}
a=$(realpath "$a")
work=${WORK_DIR:-$PWD/../build/sm-t531}
[[ ${NATIVE_KMS:-1} == 1 ]] || { echo "SD production supports only native unified DRM" >&2; exit 1; }
NATIVE_KMS=1
# The installed bootstrap passes its live DT to kexec. An Android v0
# container preserves the appended DT through kexec-tools' zImage loader.
# ARM's decompressor then selects the appended, updated board DT.
cp "$a/qcom-msm8226-samsung-matisse3g.dtb" "$work/sd-kernel.dtb"
# Supply the per-device factory identity privately, as boot firmware normally
# would. Never put a tablet's Bluetooth address in the public board DTS.
bt_node=/soc/remoteproc@fb204000/smd-edge/wcnss/bluetooth
if fdtget "$work/sd-kernel.dtb" "$bt_node" compatible >/dev/null 2>&1; then
    python3 "$PWD/tools/set-bluetooth-address.py" "$work/sd-kernel.dtb" \
        "${BT_ADDRESS_FILE:-$PWD/../private/FIRMWARE/board-data/bluetooth-address}"
fi
# RAM banks verified from the SM-T531 bootloader's live device tree.
fdtput -t x "$work/sd-kernel.dtb" /memory@0 reg 0 40000000 40000000 20000000
cmdline='console=tty0 loglevel=7 sysctl.kernel.sysrq=0 root=LABEL=T531_ROOT rootwait rw t531.stage=second'
if [ "${NATIVE_KMS:-0}" = 1 ]; then
    cmdline+=' t531.native_kms=1 drm_kms_helper.fbdev_emulation=0 systemd.unit=multi-user.target modprobe.blacklist=msm,arm_smmu'
fi
if [[ -n ${GRAPHICS_TRIAL_ID:-} ]]; then
    [[ $GRAPHICS_TRIAL_ID =~ ^[a-zA-Z0-9_-]+$ ]]
    cmdline=${cmdline/t531.native_kms=1/t531.native_kms=0}
    cmdline+=" t531.graphics_trial=$GRAPHICS_TRIAL_ID"
fi
fdtput -t s "$work/sd-kernel.dtb" /chosen bootargs "$cmdline"
# The immutable bootstrap uses --image-size=0x04000000, loading the
# ramdisk at 0x04008000. Its appended DT must describe that same ramdisk.
size=$(stat -c %s "$a/initramfs.cpio.gz")
fdtput -t x "$work/sd-kernel.dtb" /chosen linux,initrd-start 4008000
fdtput -t x "$work/sd-kernel.dtb" /chosen linux,initrd-end "$(printf '%x' "$((0x04008000 + size))")"
cat "$a/zImage" "$work/sd-kernel.dtb" > "$work/zImage-dtb"
mkbootimg --header_version 0 --pagesize 2048 --base 0 \
    --kernel_offset 0x00008000 --ramdisk_offset 0x04008000 \
    --tags_offset 0x04100000 --board matisse3g \
    --kernel "$work/zImage-dtb" --cmdline "$cmdline" \
    --output "$a/sd-kernel.img"
printf '%s\n' "$cmdline" > "$a/kexec.cmdline"
# Keep the bootstrap's existing filename contract; deploy sd-kernel.img
# under the name zImage, and retain the genuine zImage in host artifacts.
(cd "$a"; sha256sum sd-kernel.img | sed 's/  sd-kernel.img$/  zImage/';
 sha256sum initramfs.cpio.gz) > "$a/sd-kernel.sha256"
