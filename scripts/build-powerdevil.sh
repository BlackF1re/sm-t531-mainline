#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
project=$PWD
work=$project/.work/powerdevil
root=$project/.work/rootfs
artifacts=$project/.work/artifacts/current
snapshot=https://snapshot.debian.org/archive/debian/20261003T000000Z/
[ -f "$root/etc/debian_version" ] || { echo 'Run make rootfs first'; exit 1; }
[ "$(sudo chroot "$root" dpkg --print-architecture)" = armhf ]
mkdir -p "$work" "$artifacts"
sources=$root/etc/apt/sources.list.d/t531-powerdevil-build.list
mountpoint=$root/tmp/t531-powerdevil
[ ! -e "$sources" ] || { echo 'Temporary source list already exists'; exit 1; }
sudo chroot "$root" dpkg-query -W '-f=${binary:Package} ${db:Status-Status}\n' \
    | awk '$2 != "not-installed" && $2 != "config-files" { print $1 }' | sort > "$work/packages-before-build.txt"
cleanup() {
    result=$?
    trap - EXIT
    sudo chroot "$root" dpkg-query -W '-f=${binary:Package} ${db:Status-Status}\n' \
        | awk '$2 != "not-installed" && $2 != "config-files" { print $1 }' | sort > "$work/packages-after-build.txt"
    mapfile -t added < <(comm -13 "$work/packages-before-build.txt" "$work/packages-after-build.txt")
    if [ "${#added[@]}" -gt 0 ]; then
        sudo chroot "$root" env DEBIAN_FRONTEND=noninteractive apt-get -y purge "${added[@]}" || result=1
    fi
    sudo chroot "$root" apt-get clean
    sudo python3 -c 'import pathlib,sys; pathlib.Path(sys.argv[1]).unlink()' "$sources"
    if mountpoint -q "$mountpoint"; then sudo umount "$mountpoint"; fi
    sudo rmdir "$mountpoint" 2>/dev/null || true
    exit "$result"
}
trap cleanup EXIT
sudo mkdir -p "$mountpoint"
sudo mount --bind "$work" "$mountpoint"
printf 'deb-src [check-valid-until=no] %s trixie main\n' "$snapshot" | sudo tee "$sources" >/dev/null
sudo chroot "$root" apt-get update
sudo chroot "$root" env DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends build-dep powerdevil
if [ ! -f "$work/powerdevil-6.3.6/CMakeLists.txt" ]; then
    sudo chroot "$root" /bin/sh -c 'cd /tmp/t531-powerdevil; apt-get source powerdevil=4:6.3.6-1'
fi
(cd "$work"; sha256sum -c <<'SUMS'
c8d8fe8c4dc0991e813fae3ed66c1c942f963d88e859395825a947257331aaf2  powerdevil_6.3.6.orig.tar.xz
fa96d2b170fea4ea637a75721dd52e6463ee1828e8234183c7d15efc42ff6724  powerdevil_6.3.6-1.debian.tar.xz
SUMS
)
for patch in "$project"/patches/powerdevil/*.patch; do
    if ! sudo env GIT_CEILING_DIRECTORIES="$work" git -C "$work/powerdevil-6.3.6" apply --reverse --check "$patch" 2>/dev/null; then
        sudo env GIT_CEILING_DIRECTORIES="$work" git -C "$work/powerdevil-6.3.6" apply --check "$patch"
        sudo env GIT_CEILING_DIRECTORIES="$work" git -C "$work/powerdevil-6.3.6" apply "$patch"
    fi
done
sudo chroot "$root" cmake -S /tmp/t531-powerdevil/powerdevil-6.3.6 -B /tmp/t531-powerdevil/out \
    -DBUILD_TESTING=OFF -DKDE_INSTALL_LIBDIR=lib/arm-linux-gnueabihf \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_SKIP_RPATH=ON
sudo chroot "$root" cmake --build /tmp/t531-powerdevil/out \
    --target powerdevil_suspendsessionaction --parallel "${JOBS:-8}"
pkg=$work/package
mkdir -p "$pkg/DEBIAN" "$pkg/usr/lib/t531-powerdevil/powerdevil/action" \
    "$pkg/usr/share/doc/t531-powerdevil-suspend"
install -m 644 "$work/out/bin/powerdevil/action/powerdevil_suspendsessionaction.so" \
    "$pkg/usr/lib/t531-powerdevil/powerdevil/action/"
cat > "$pkg/usr/share/doc/t531-powerdevil-suspend/copyright" <<'COPYRIGHT'
Source: https://invent.kde.org/plasma/powerdevil
Version: 6.3.6, Debian source 4:6.3.6-1
Copyright: 2010 Dario Freddi
Upstream suspend transition fix: Myrrh Periwinkle, commit
 1935d5e405f126c1a517af7bcf623138d3cb7261
License: GPL-2.0-or-later

COPYRIGHT
cat "$work/powerdevil-6.3.6/LICENSES/GPL-2.0-or-later.txt" >> \
    "$pkg/usr/share/doc/t531-powerdevil-suspend/copyright"
cat > "$pkg/DEBIAN/control" <<'CONTROL'
Package: t531-powerdevil-suspend
Version: 0.20261013-1
Architecture: armhf
Maintainer: BlackF1re <55582873+BlackF1re@users.noreply.github.com>
Depends: powerdevil (>= 4:6.3.6), powerdevil (<< 4:6.4~), libpowerdevilcore2, libkworkspace6-6, libkf6idletime6, libkf6coreaddons6, libqt6dbus6, libqt6core6t64 (>= 6.8.2), libstdc++6, libc6
Section: kde
Priority: optional
Description: PowerDevil suspend action with upstream transition guard
 Backports upstream commit 1935d5e405f126c1a517af7bcf623138d3cb7261.
 Uses the Qt plugin search path without replacing Debian-owned files.
CONTROL
SOURCE_DATE_EPOCH=1790985600 dpkg-deb --root-owner-group -b "$pkg" \
    "$artifacts/t531-powerdevil-suspend_0.20261013-1_armhf.deb"
