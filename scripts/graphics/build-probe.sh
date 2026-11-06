#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source scripts/lib/host-paths.sh
t531_host_paths
sysroot=${DRM_SYSROOT:?Set DRM_SYSROOT to an armhf userspace sysroot}
mkdir -p "$work/artifacts/tools"
PKG_CONFIG_SYSROOT_DIR="$sysroot" PKG_CONFIG_LIBDIR="$sysroot/usr/lib/arm-linux-gnueabihf/pkgconfig:$sysroot/usr/share/pkgconfig" \
 pkg-config --cflags --libs libdrm > "$work/drm-probe.flags"
read -r -a flags < "$work/drm-probe.flags"
for source in probe shared-iova; do
    output=$source
    [[ $source != probe ]] || output=t531-drm-probe
    ${CROSS_COMPILE:-arm-linux-gnueabihf-}gcc --sysroot="$sysroot" -O2 -Wall -Wextra -Werror "tools/drm-device/$source.c" "${flags[@]}" -o "$work/artifacts/tools/$output"
done
