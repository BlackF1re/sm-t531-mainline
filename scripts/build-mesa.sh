#!/usr/bin/env bash
# Build only the recorded production Mesa series from a verified source archive.
set -euo pipefail
cd "$(dirname "$0")/.."
project=$PWD
archive=${MESA_SOURCE_ARCHIVE:?Set MESA_SOURCE_ARCHIVE to mesa-25.0.7.tar.xz}
cross=${MESA_CROSS_FILE:?Set MESA_CROSS_FILE to the armhf Meson cross file}
work=${MESA_WORK_DIR:-$project/.work/mesa-production}
meson=("${MESON_PYTHON:-python3}" -m mesonbuild.mesonmain)
archive=$(realpath "$archive"); cross=$(realpath "$cross")
[[ $(sha256sum "$archive" | cut -d' ' -f1) == 592272df3cf01e85e7db300c449df5061092574d099da275d19e97ef0510f8a6 ]]
mkdir -p "$work"
exec 9>"$work/build.lock"
flock -n 9
(cd "$project"; sha256sum patches/mesa/*.patch) > "$work/patches.new.sha256"
if [[ -d $work/source ]]; then
    cmp "$work/patches.new.sha256" "$work/patches.sha256"
    (cd "$work/source"; sha256sum --quiet -c ../source.sha256)
else
    mkdir "$work/source"
    tar -xJf "$archive" --strip-components=1 -C "$work/source"
    for patch in "$project"/patches/mesa/*.patch; do
        patch -d "$work/source" --batch --fuzz=0 -p1 < "$patch"
    done
    (cd "$work/source"; find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$work/source.sha256"
    mv "$work/patches.new.sha256" "$work/patches.sha256"
fi
if [[ ! -f $work/build/build.ninja ]]; then
    "${meson[@]}" setup "$work/build" "$work/source" --cross-file "$cross" \
        --prefix=/usr --libdir=lib/arm-linux-gnueabihf --buildtype=debugoptimized \
        --wrap-mode=nodownload -Dgallium-drivers=freedreno -Dfreedreno-kmds=msm \
        -Dvulkan-drivers= -Dplatforms=wayland -Dglx=disabled -Dglvnd=enabled \
        -Dgles1=disabled -Dgles2=enabled -Degl=enabled -Dgbm=enabled -Dllvm=disabled \
        -Dgallium-va=disabled -Dgallium-vdpau=disabled -Dvideo-codecs= \
        -Dvalgrind=disabled -Dbuild-tests=false
fi
ninja -C "$work/build" -j"${JOBS:-$(nproc)}"
DESTDIR="$work/install" "${meson[@]}" install -C "$work/build" --no-rebuild
(cd "$work/install"; find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$work/install.sha256"
printf 'Production Mesa built: %s\n' "$work/install"
