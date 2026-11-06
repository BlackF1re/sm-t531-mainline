#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
sysroot=${DRM_SYSROOT:?Set DRM_SYSROOT to an armhf userspace sysroot}
mkdir -p ../build/sm-t531/artifacts/tools
PKG_CONFIG_SYSROOT_DIR="$sysroot" PKG_CONFIG_LIBDIR="$sysroot/usr/lib/arm-linux-gnueabihf/pkgconfig:$sysroot/usr/share/pkgconfig" \
 pkg-config --cflags --libs libdrm > ../build/sm-t531/drm-probe.flags
read -r -a flags < ../build/sm-t531/drm-probe.flags
for source in probe shared-iova; do
    output=$source
    [[ $source != probe ]] || output=t531-drm-probe
    ${CROSS_COMPILE:-arm-linux-gnueabihf-}gcc --sysroot="$sysroot" -O2 -Wall -Wextra -Werror "tools/drm-device/$source.c" "${flags[@]}" -o "../build/sm-t531/artifacts/tools/$output"
done
