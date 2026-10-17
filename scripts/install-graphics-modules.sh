#!/bin/sh
# Read a checksummed module-tree archive on stdin; never mix configurations.
set -eu
[ "$(id -u)" = 0 ]
tr '\000' '\n' < /proc/device-tree/compatible | grep -qx samsung,matisse3g
version=7.2.9-dirty
stage=$(mktemp -d /var/lib/t531/modules-stage.XXXXXX)
trap 'rm -rf "$stage"' EXIT
tar -xzf - -C "$stage"
(cd "$stage"; sha256sum -c modules.files.sha256 >/dev/null)
new="$stage/lib/modules/$version"
[ -f "$new/modules.builtin" ]
[ -f "$new/modules.order" ]
current="/lib/modules/$version"
previous="/var/lib/t531/modules-before-install.$$"
[ ! -e "$previous" ]
if [ -d "$current" ]; then
    mv "$current" "$previous"
fi
if ! mv "$new" "$current"; then
    [ ! -d "$previous" ] || mv "$previous" "$current"
    exit 1
fi
if ! depmod -a "$version"; then
    mv "$current" "$stage/failed-modules"
    [ ! -d "$previous" ] || mv "$previous" "$current"
    depmod -a "$version"
    exit 1
fi
echo "Installed verified modules for $version; previous tree: $previous"
