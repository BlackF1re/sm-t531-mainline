#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
project=$PWD
work=${WORK_DIR:-$project/.work}
linux=${KERNEL_SRC:-$work/linux}
out=${KERNEL_OUT:-$work/out}
artifacts=${ARTIFACTS_DIR:-$work/artifacts/current}
commit=5fce161649b4d779d1b76d9fcd52dc77779774b8
tag=v7.2.9
cross=${CROSS_COMPILE:-arm-linux-gnueabihf-}
profile=${1:-main}
case "$profile" in
    main)
        defconfig=multi_v7_defconfig; prefix=; required=config/kernel.fragment
        [[ ${NATIVE_KMS:-1} == 1 ]] || { echo "Main supports only native unified DRM" >&2; exit 1; }
        export NATIVE_KMS=1
        export NATIVE_ICC=${NATIVE_ICC:-$NATIVE_KMS}
        ;;
    bootstrap) defconfig=qcom_defconfig; prefix=bootstrap-; required=config/bootstrap.fragment;;
    *) echo 'Usage: build.sh [main|bootstrap]'; exit 1;;
esac
export KBUILD_BUILD_USER=builder KBUILD_BUILD_HOST=t531
export KBUILD_BUILD_TIMESTAMP='2026-10-03 00:00:00 UTC' KBUILD_BUILD_VERSION=1
export SOURCE_DATE_EPOCH=1790985600
export LC_ALL=C TZ=UTC
mkdir -p "$work" "$artifacts"
if [ ! -e "$linux/.git" ]; then
    git clone --depth 1 --branch "$tag" https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git "$linux"
fi
[ "$(git -C "$linux" rev-parse HEAD)" = "$commit" ] || { echo 'Wrong Linux base'; exit 1; }
# Match an exact patch prefix before applying any pending patches. Later
# patches can modify files created by earlier ones, so individual reverse
# checks are insufficient for repeat builds.
patches=("$project"/patches/linux/*.patch)
export GIT_INDEX_FILE="$work/source-check.index"
applied_prefix=-1
git -C "$linux" read-tree HEAD
if git -C "$linux" diff --quiet &&
   [ -z "$(git -C "$linux" ls-files --others --exclude-standard)" ]; then
    applied_prefix=0
fi
for ((candidate=${#patches[@]}; applied_prefix<0 && candidate>=0; candidate--)); do
    git -C "$linux" read-tree HEAD
    for ((i=0; i<candidate; i++)); do
        git -C "$linux" apply --cached "${patches[i]}"
    done
    if git -C "$linux" diff --quiet &&
       [ -z "$(git -C "$linux" ls-files --others --exclude-standard)" ]; then
        applied_prefix=$candidate
        break
    fi
done
[ "$applied_prefix" -ge 0 ] || { echo 'Source changes outside the recorded patch prefixes'; exit 1; }
for ((i=applied_prefix; i<${#patches[@]}; i++)); do
    git -C "$linux" apply --check "${patches[i]}"
    git -C "$linux" apply "${patches[i]}"
    git -C "$linux" apply --cached "${patches[i]}"
done
git -C "$linux" diff --quiet || { echo 'Source changes outside the recorded patches'; exit 1; }
unset GIT_INDEX_FILE
km=(make -C "$linux" O="$out" ARCH=arm CROSS_COMPILE="$cross")
[[ -z ${KERNEL_LOCALVERSION:-} ]] || km+=(LOCALVERSION="$KERNEL_LOCALVERSION")
"${km[@]}" "$defconfig"
"$linux/scripts/kconfig/merge_config.sh" -m -O "$out" "$out/.config" "$project/config/kernel.fragment"
if [ "$profile" = bootstrap ]; then
    "$linux/scripts/kconfig/merge_config.sh" -m -O "$out" "$out/.config" "$project/config/bootstrap.fragment"
fi
if [ "${NATIVE_KMS:-0}" = 1 ]; then
    "$linux/scripts/kconfig/merge_config.sh" -m -O "$out" "$out/.config" "$project/config/native-kms.fragment"
fi
if [ "${NATIVE_ICC:-0}" = 1 ]; then
    "$linux/scripts/kconfig/merge_config.sh" -m -O "$out" "$out/.config" "$project/config/native-icc.fragment"
fi
if [ "${GRAPHICS_TRACE:-0}" = 1 ]; then
    "$linux/scripts/kconfig/merge_config.sh" -m -O "$out" "$out/.config" "$project/config/graphics-trace.fragment"
fi
"${km[@]}" olddefconfig
required_fragments=("$project/$required")
# Profile fragments override earlier settings, as merge_config.sh does.
if [ "${NATIVE_KMS:-0}" = 1 ]; then
    required_fragments+=("$project/config/native-kms.fragment")
fi
if [ "${NATIVE_ICC:-0}" = 1 ]; then
    required_fragments+=("$project/config/native-icc.fragment")
fi
if [ "${GRAPHICS_TRACE:-0}" = 1 ]; then
    required_fragments+=("$project/config/graphics-trace.fragment")
fi
python3 - "$out/.config" "${required_fragments[@]}" <<'PY'
import sys
cfg=set(open(sys.argv[1]).read().splitlines())
required={}
for path in sys.argv[2:]:
    for line in open(path):
        setting=line.strip()
        if setting.startswith('CONFIG_'):
            required[setting.split('=', 1)[0]]=setting
        elif setting.startswith('# CONFIG_') and setting.endswith(' is not set'):
            required[setting.split()[1]]=setting
missing=[]
for setting in required.values():
    if setting.startswith('CONFIG_'):
        if setting not in cfg: missing.append(setting)
    else:
        symbol=setting.split()[1]
        # Invisible symbols are omitted by Kconfig when their parent is off.
        if any(line.startswith(symbol+'=') and line != symbol+'=n' for line in cfg):
            missing.append(setting)
if missing: raise SystemExit('Unresolved required config: '+', '.join(missing))
PY
dtb=qcom-msm8226-samsung-matisse3g.dtb
if [ "${NATIVE_ICC:-0}" = 1 ] && [ "${NATIVE_KMS:-0}" != 1 ]; then
    echo 'NATIVE_ICC requires NATIVE_KMS=1'; exit 1
fi
if [ "${NATIVE_KMS:-0}" = 1 ]; then
    [ "$profile" = main ] || { echo 'Native KMS requires main profile'; exit 1; }
    dtb=qcom-msm8226-samsung-matisse3g-native.dtb
    if [ "${NATIVE_ICC:-0}" = 1 ]; then
        dtb=qcom-msm8226-samsung-matisse3g-native-icc.dtb
    fi
fi
targets=(zImage "qcom/$dtb")
[ "$profile" = bootstrap ] || targets+=(modules)
"${km[@]}" -j"${JOBS:-$(nproc)}" "${targets[@]}"
python3 "$project/tools/check-boot-layout.py" "$out/System.map" "$out/.config" \
    "$out/arch/arm/boot/zImage" \
    "$out/arch/arm/boot/dts/qcom/$dtb"
if [ "$profile" = main ]; then
    "${km[@]}" INSTALL_MOD_PATH="$artifacts/modules" INSTALL_MOD_STRIP=1 modules_install
    (cd "$artifacts/modules";
        find lib/modules -type f -print0 | LC_ALL=C sort -z |
            xargs -0 sha256sum > modules.files.sha256)
fi
cp "$out/arch/arm/boot/zImage" "$artifacts/${prefix}zImage"
cp "$out/arch/arm/boot/dts/qcom/$dtb" "$artifacts/qcom-msm8226-samsung-matisse3g.dtb"
cp "$out/.config" "$artifacts/${prefix}kernel.config"
cp "$project/boot/extlinux.conf.in" "$artifacts/extlinux.conf"
"$project/scripts/build-initramfs.sh" "$profile"
if [ "$profile" = bootstrap ]; then
    staging=$work/bootstrap-root
    mkdir -p "$staging/extlinux"
    cp "$artifacts/bootstrap-zImage" "$artifacts/bootstrap-initramfs.cpio.gz" \
       "$artifacts/qcom-msm8226-samsung-matisse3g.dtb" "$staging/"
    cp "$project/boot/bootstrap-extlinux.conf.in" "$staging/extlinux/extlinux.conf"
    find "$staging" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
    rm -f "$artifacts/bootstrap-boot.ext2"
    truncate -s $((10*1024*1024-512*1024)) "$artifacts/bootstrap-boot.ext2"
    E2FSPROGS_FAKE_TIME=$SOURCE_DATE_EPOCH mke2fs -q -t ext2 -F -b 1024 -I 256 -m 0 \
        -U 53100000-8226-4000-8000-000000000001 \
        -E hash_seed=53100000-8226-4000-8000-000000000001 \
        -L T531_BOOTSTRAP -d "$staging" "$artifacts/bootstrap-boot.ext2"
    e2fsck -fn "$artifacts/bootstrap-boot.ext2"
    (cd "$artifacts"; sha256sum bootstrap-zImage bootstrap-initramfs.cpio.gz \
        bootstrap-boot.ext2 qcom-msm8226-samsung-matisse3g.dtb > bootstrap-SHA256SUMS)
    printf 'Bootstrap artifacts: %s\n' "$artifacts"
    exit 0
fi
if [[ ${SD_ONLY:-0} == 1 ]]; then
    "$project/scripts/package-sd.sh"
    make -s -C "$linux" O="$out" ARCH=arm CROSS_COMPILE="$cross" ${KERNEL_LOCALVERSION:+LOCALVERSION="$KERNEL_LOCALVERSION"} kernelrelease > "$artifacts/kernel.release"
    (cd "$artifacts"; sha256sum sd-kernel.img sd-kernel.sha256 initramfs.cpio.gz kexec.cmdline kernel.release kernel.config qcom-msm8226-samsung-matisse3g.dtb > SHA256SUMS)
    printf 'SD-only artifacts (no bootloader image): %s\n' "$artifacts"
    exit 0
fi
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
    --cmdline 'console=tty0 sysctl.kernel.sysrq=0 loglevel=8 ignore_loglevel clk_ignore_unused' \
    --output "$artifacts/diagnostic-boot.img"
(cd "$artifacts"; sha256sum zImage initramfs.cpio.gz > kernel.sha256)
printf '%s\n' 'console=tty0 sysctl.kernel.sysrq=0 loglevel=7 clk_ignore_unused t531.stage=second' \
    > "$artifacts/kexec.cmdline"
"$project/scripts/package-sd.sh"
(cd "$artifacts"; sha256sum zImage *.dtb initramfs.cpio.gz lk2nd-msm8226.img \
    diagnostic-boot.img sd-kernel.img sd-kernel.sha256 kernel.sha256 kexec.cmdline > SHA256SUMS)
printf 'Artifacts: %s\n' "$artifacts"
