#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
a=$PWD/.work/artifacts/current
work=$PWD/.work
# The installed bootstrap passes its live DT to kexec. An Android v0
# container preserves the appended DT through kexec-tools' zImage loader.
# ARM's decompressor then selects the appended, updated board DT.
cp "$a/qcom-msm8226-samsung-matisse3g.dtb" "$work/sd-kernel.dtb"
# RAM banks verified from the SM-T531 bootloader's live device tree.
fdtput -t x "$work/sd-kernel.dtb" /memory@0 reg 0 40000000 40000000 20000000
cmdline='console=tty0 console=ttyMSM0,115200 loglevel=7 clk_ignore_unused msm.separate_gpu_kms=1 root=LABEL=T531_ROOT rootwait rw t531.stage=second'
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
