#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
work=$PWD/.work/mesa-simpledrm
a=$PWD/.work/artifacts/current
commit=c5b82318a9d065f37d7f4ec90e272721288797b5
base=https://raw.githubusercontent.com/AsteroidOS/meta-asteroid/$commit/recipes-graphics/mesa-dri-simpledrm/mesa-dri-simpledrm
mkdir -p "$work" "$a"
for name in mesa-dri-simpledrm.c COPYING; do
    [ -f "$work/$name" ] || curl -fL "$base/$name" -o "$work/$name"
done
(cd "$work"; sha256sum -c <<'SUMS'
8d8e608d067823bab77e21bb0ba3cf68cd990482f68c3032c69add787d9ae7f3  mesa-dri-simpledrm.c
e7abdcb3b8be5a847a06f5827b667b5307cdb5fed188b798f2621291bc0b300b  COPYING
SUMS
)
# Adapt only the library directory to Debian armhf multiarch layout.
sed 's@/usr/lib/dri/@/usr/lib/arm-linux-gnueabihf/dri/@' \
    "$work/mesa-dri-simpledrm.c" > "$work/adapter.c"
pkg=$work/package
mkdir -p "$pkg/DEBIAN" "$pkg/usr/lib/arm-linux-gnueabihf/dri" \
    "$pkg/usr/share/doc/t531-mesa-simpledrm"
"${CROSS_COMPILE:-arm-linux-gnueabihf-}gcc" -Os -fPIC -shared \
    -Wl,-soname,simpledrm_dri.so "$work/adapter.c" -ldl \
    -o "$pkg/usr/lib/arm-linux-gnueabihf/dri/simpledrm_dri.so"
cp "$work/COPYING" "$pkg/usr/share/doc/t531-mesa-simpledrm/copyright"
cat > "$pkg/DEBIAN/control" <<'CONTROL'
Package: t531-mesa-simpledrm
Version: 0.20261012-1
Architecture: armhf
Maintainer: BlackF1re <55582873+BlackF1re@users.noreply.github.com>
Depends: libc6 (>= 2.34), libgl1-mesa-dri (>= 25.0)
Section: libs
Priority: optional
Description: Existing Mesa KMSRO entry point for simpledrm
 Delegates the simpledrm DRI entry point to Mesa's generic KMSRO loader.
 GPU rendering is provided by the installed Mesa drivers.
CONTROL
SOURCE_DATE_EPOCH=1790985600 dpkg-deb --root-owner-group -b "$pkg" \
    "$a/t531-mesa-simpledrm_0.20261012-1_armhf.deb"
