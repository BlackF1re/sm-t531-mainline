#!/usr/bin/env bash
# Stage immutable ARM libraries and configure Plasma; the running session stays up.
set -euo pipefail
project=$(cd "$(dirname "$0")/.." && pwd)
[[ $EUID == 0 && $# == 2 ]] || { echo "Usage (root): $0 MESA_LIBRARY_DIRECTORY QT_LIBRARY_DIRECTORY" >&2; exit 2; }
tr '\0' '\n' < /proc/device-tree/compatible | grep -qx samsung,matisse3g
source_dir=$(realpath "$1"); qt_dir=$(realpath "$2")
[[ $qt_dir =~ ^/[a-zA-Z0-9_./+-]+$ && -r $qt_dir/libQt6Gui.so.6 ]]
desktop_user=${T531_DESKTOP_USER:-t531}
[[ $(id -u "$desktop_user") == 1000 ]]
desktop_home=$(getent passwd "$desktop_user" | cut -d: -f6)
install -d -m755 /opt/t531-graphics
stage=$(mktemp -d /opt/t531-graphics/.mesa-stage.XXXXXX)
trap 'rm -rf "$stage"' EXIT
for pattern in 'libEGL_mesa.so*' 'libgallium*.so' 'libgbm.so*'; do
    mapfile -t files < <(compgen -G "$source_dir/$pattern")
    ((${#files[@]}))
    cp -a -- "${files[@]}" "$stage/"
done
install -d -m755 "$stage/gbm"
cp -a "$source_dir/gbm/dri_gbm.so" "$stage/gbm/"
python3 - "$stage" <<'PY'
import pathlib,struct,sys
root=pathlib.Path(sys.argv[1])
for path in root.rglob('*'):
    if path.is_symlink():
        assert path.resolve().is_relative_to(root), f'External library symlink: {path}'
    if path.is_file():
        data=path.read_bytes()[:20]
        assert data[:6]==b'\x7fELF\x01\x01' and struct.unpack_from('<H',data,18)[0]==40, path
PY
(cd "$stage"; find . -type f ! -name libraries.sha256 -print0 | sort -z | xargs -0 sha256sum) > "$stage/libraries.sha256"
identity=$(sha256sum "$stage/libraries.sha256" | cut -c1-16)
destination=/opt/t531-graphics/mesa-$identity
printf '{"file_format_version":"1.0.0","ICD":{"library_path":"%s/libEGL_mesa.so.0"}}\n' "$destination" > "$stage/egl.json"
chown -R root:root "$stage"
find "$stage" -type d -exec chmod 755 {} +
find "$stage" -type f -exec chmod 644 {} +
if [[ -e $destination ]]; then
    cmp "$stage/libraries.sha256" "$destination/libraries.sha256"
    cmp "$stage/egl.json" "$destination/egl.json"
    (cd "$destination"; sha256sum --quiet -c libraries.sha256)
else
    mv "$stage" "$destination"
fi
# Check real service-user access before changing its loader configuration.
for library in libEGL_mesa.so.0 libgbm.so.1 gbm/dri_gbm.so; do
    setpriv --reuid=1000 --regid="$(id -g "$desktop_user")" --init-groups \
        test -r "$destination/$library"
done
override_dir=$desktop_home/.config/systemd/user/plasma-plasmashell.service.d
override=$override_dir/90-t531-private-graphics.conf
backup=/var/lib/t531/mesa-install/$identity
install -d -m700 "$backup"
if [[ -f $override && ! -e $backup/previous-shell.conf ]]; then
    cp -a "$override" "$backup/previous-shell.conf"
fi
install -d -m755 "$override_dir"
sed -e "s|@MESA_LIBRARY_DIR@|$destination|g" -e "s|@QT_LIBRARY_DIR@|$qt_dir|g" \
    "$project/config/t531-mesa-shell.conf" > "$backup/shell.conf"
install -m644 "$backup/shell.conf" "$override.new"
mv "$override.new" "$override"
if [[ -S /run/user/1000/bus ]]; then
    setpriv --reuid=1000 --regid="$(id -g "$desktop_user")" --init-groups \
        env XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
        systemctl --user daemon-reload
fi
printf 'Plasma Mesa installed: %s\nRestart the Plasma session to load it.\n' "$destination"
