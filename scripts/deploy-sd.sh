#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[ $# = 1 ] && [ -n "$1" ] || { echo 'Usage: make deploy-sd BOOT_MOUNT=/mounted/ext2'; exit 1; }
mountpoint -q "$1" || { echo 'Destination must be an existing mount'; exit 1; }
[ "$(findmnt -n -o FSTYPE --target "$1")" = ext2 ] || { echo 'lk2nd requires ext2'; exit 1; }
[ "$(findmnt -n -o TARGET --target "$1")" = "$(realpath "$1")" ] || { echo 'Pass the mount root'; exit 1; }
[ ! -e "$1/extlinux/extlinux.conf" ] || { echo 'Existing boot configuration; refusing overwrite'; exit 1; }
a=.work/artifacts/current
(cd "$a"; sha256sum -c SHA256SUMS)
mkdir -p "$1/extlinux"
cp "$a/zImage" "$a/qcom-msm8226-samsung-matisse3g.dtb" "$a/initramfs.cpio.gz" \
   "$a/kernel.sha256" "$a/kexec.cmdline" "$1/"
cp "$a/extlinux.conf" "$1/extlinux/"
sync
