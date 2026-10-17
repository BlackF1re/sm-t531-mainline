#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
work=$PWD/.work/mesa-msm-kms
package=$work/package
artifacts=$PWD/.work/artifacts/current
install -d "$package/DEBIAN" "$package/usr/lib/arm-linux-gnueabihf/dri" \
    "$package/usr/share/doc/t531-mesa-msm-kms" "$artifacts"
"${CROSS_COMPILE:-arm-linux-gnueabihf-}gcc" -Os -fPIC -shared \
    -Wl,-soname,msm-kms_dri.so tools/mesa-msm-kms/entry.c -ldl \
    -o "$package/usr/lib/arm-linux-gnueabihf/dri/msm-kms_dri.so"
cat >"$package/DEBIAN/control" <<'CONTROL'
Package: t531-mesa-msm-kms
Version: 0.20261014-1
Architecture: armhf
Maintainer: BlackF1re <55582873+BlackF1re@users.noreply.github.com>
Depends: libc6 (>= 2.34), libgl1-mesa-dri (>= 25.0)
Section: libs
Priority: optional
Description: Mesa platform entry for native split Qualcomm MSM KMS
 Delegates msm-kms to the installed generic platform DRI extension entry.
 Ordinary Adreno clients retain the normal msm Freedreno driver selection.
CONTROL
cp tools/mesa-msm-kms/COPYING "$package/usr/share/doc/t531-mesa-msm-kms/copyright"
SOURCE_DATE_EPOCH=1790985600 dpkg-deb --root-owner-group -b "$package" \
    "$artifacts/t531-mesa-msm-kms_0.20261014-1_armhf.deb"
