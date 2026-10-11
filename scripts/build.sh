#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
project=$PWD
work=$project/.work
linux=$work/linux
out=$work/out
artifacts=$work/artifacts/current
commit=5fce161649b4d779d1b76d9fcd52dc77779774b8
tag=v7.2.9
cross=${CROSS_COMPILE:-arm-linux-gnueabihf-}
export KBUILD_BUILD_USER=builder KBUILD_BUILD_HOST=t531
export KBUILD_BUILD_TIMESTAMP='2026-10-03 00:00:00 UTC' KBUILD_BUILD_VERSION=1
export SOURCE_DATE_EPOCH=1790985600
export LC_ALL=C TZ=UTC
mkdir -p "$work" "$artifacts"
if [ ! -d "$linux/.git" ]; then
    git clone --depth 1 --branch "$tag" https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git "$linux"
fi
[ "$(git -C "$linux" rev-parse HEAD)" = "$commit" ] || { echo 'Wrong Linux base'; exit 1; }
# Never reset source modifications: accept only the exact recorded patch state.
for patch in "$project"/patches/linux/*.patch; do
    if git -C "$linux" apply --reverse --check "$patch" 2>/dev/null; then
        continue
    fi
    git -C "$linux" apply --check "$patch"
    git -C "$linux" apply "$patch"
done
# Compare against an independent index containing only the approved patches.
export GIT_INDEX_FILE="$work/source-check.index"
git -C "$linux" read-tree HEAD
for patch in "$project"/patches/linux/*.patch; do git -C "$linux" apply --cached "$patch"; done
git -C "$linux" diff --quiet || { echo 'Source changes outside the recorded patches'; exit 1; }
[ -z "$(git -C "$linux" ls-files --others --exclude-standard)" ] || { echo 'Unexpected untracked Linux source'; exit 1; }
unset GIT_INDEX_FILE
km=(make -C "$linux" O="$out" ARCH=arm CROSS_COMPILE="$cross")
"${km[@]}" multi_v7_defconfig
"$linux/scripts/kconfig/merge_config.sh" -m -O "$out" "$out/.config" "$project/config/kernel.fragment"
"${km[@]}" olddefconfig
python3 - "$out/.config" "$project/config/kernel.fragment" <<'PY'
import sys
cfg=set(open(sys.argv[1]).read().splitlines())
missing=[s.strip() for s in open(sys.argv[2]) if s.startswith('CONFIG_') and s.strip() not in cfg]
if missing: raise SystemExit('Unresolved required config: '+', '.join(missing))
PY
"${km[@]}" -j"${JOBS:-8}" zImage qcom/qcom-msm8226-samsung-matisse3g.dtb modules
"${km[@]}" INSTALL_MOD_PATH="$artifacts/modules" INSTALL_MOD_STRIP=1 modules_install
cp "$out/arch/arm/boot/zImage" "$artifacts/"
cp "$out/arch/arm/boot/dts/qcom/qcom-msm8226-samsung-matisse3g.dtb" "$artifacts/"
cp "$out/.config" "$artifacts/kernel.config"
cp "$project/boot/extlinux.conf.in" "$artifacts/extlinux.conf"
# Pinned static Debian armhf BusyBox; no host-architecture binary in initramfs.
url='https://deb.debian.org/debian/pool/main/b/busybox/busybox-static_1.37.0-6+b9_armhf.deb'
sha=8b35210e08d559ecc0ddb660dd96f6f9694f69eb27f1dc608f5eeda56d94509e
mkdir -p "$work/busybox"
if [ ! -f "$work/busybox.deb" ]; then curl -fL "$url" -o "$work/busybox.deb"; fi
echo "$sha  $work/busybox.deb" | sha256sum -c -
dpkg-deb -x "$work/busybox.deb" "$work/busybox"
# gen_init_cpio writes device nodes without root privileges.
python3 - "$work" "$project" > "$work/initramfs.list" <<'PYLIST'
import subprocess,sys
work,project=sys.argv[1:]
for directory in ['bin','sbin','dev','proc','sys','run','tmp','newroot']:
    print(f'dir /{directory} 755 0 0')
print('nod /dev/console 600 0 0 c 5 1')
print('nod /dev/null 666 0 0 c 1 3')
print(f'file /init {project}/scripts/init 755 0 0')
print(f'file /init-usblog {project}/scripts/init-usblog 755 0 0')
print(f'file /bin/busybox {work}/busybox/usr/bin/busybox 755 0 0')
apps=subprocess.check_output(['qemu-arm',work+'/busybox/usr/bin/busybox','--list'],text=True)
for app in sorted(apps.split()):
    if app != 'busybox': print(f'slink /bin/{app} busybox 777 0 0')
PYLIST
"$out/usr/gen_init_cpio" -t "$SOURCE_DATE_EPOCH" "$work/initramfs.list" | gzip -n -9 > "$artifacts/initramfs.cpio.gz"
url='https://github.com/msm8916-mainline/lk2nd/releases/download/23.1/lk2nd-msm8226.img'
[ -f "$artifacts/lk2nd-msm8226.img" ] || curl -fL "$url" -o "$artifacts/lk2nd-msm8226.img"
echo "3e94879473e6136bda826949474525b8d3b9d20365258ba3347878affe7f23bc  $artifacts/lk2nd-msm8226.img" | sha256sum -c -
# lk2nd accepts a single appended mainline DTB without Qualcomm board IDs.
cat "$artifacts/zImage" "$artifacts/qcom-msm8226-samsung-matisse3g.dtb" > "$work/zImage-dtb"
# Match lk2nd extlinux placement, leaving decompression room below initramfs.
ramdisk_offset=$(( (0x03200000 - $(stat -c %s "$artifacts/initramfs.cpio.gz")) / 4096 * 4096 ))
tags_offset=$((ramdisk_offset - 0x00200000))
mkbootimg --header_version 0 --pagesize 2048 --base 0x00000000 \
    --kernel_offset 0x00008000 --ramdisk_offset "$ramdisk_offset" --tags_offset "$tags_offset" \
    --board matisse3g --kernel "$work/zImage-dtb" --ramdisk "$artifacts/initramfs.cpio.gz" \
    --cmdline 'earlycon console=tty0 console=ttyMSM0,115200 loglevel=8 ignore_loglevel lk2nd.pass-ramoops' \
    --output "$artifacts/diagnostic-boot.img"
(cd "$artifacts"; sha256sum zImage *.dtb initramfs.cpio.gz lk2nd-msm8226.img diagnostic-boot.img > SHA256SUMS)
printf 'Artifacts: %s\n' "$artifacts"
