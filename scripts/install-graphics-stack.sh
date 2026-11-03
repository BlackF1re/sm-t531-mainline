#!/usr/bin/env bash
# Install the single qualified stack; never restart or suspend the session.
set -Eeuo pipefail
project=$(cd "$(dirname "$0")/.." && pwd)
[[ $EUID == 0 && $# == 3 ]] || { echo "Usage (root): $0 MESA_DIRECTORY QT_GUI_LIBRARY MOBILESHELL_PLUGIN" >&2; exit 2; }
tr '\0' '\n' < /proc/device-tree/compatible | grep -qx samsung,matisse3g
lock=$project/config/graphics-stack.lock.json
mesa=$(realpath "$1"); qt_source=$(realpath "$2"); plugin_source=$(realpath "$3")
lib=/usr/lib/arm-linux-gnueabihf/qt6/qml/org/kde/plasma/private/mobileshell/libmobileshellplugin.so
exec 8>/run/lock/t531-graphics-install.lock
flock -w 10 8
mapfile -t pins < <(python3 - "$lock" "$qt_source" "$plugin_source" "$lib" "$mesa" <<'PY'
import hashlib,json,pathlib,struct,subprocess,sys
lock,qt,plugin,installed,mesa=map(pathlib.Path,sys.argv[1:]); d=json.loads(lock.read_text())
assert subprocess.check_output(['dpkg-query','-W','-f=${Version}','plasma-mobile'],text=True)==d['plasma_mobile_package']
files={p for glob in ('libEGL_mesa.so*','libgallium*.so','libgbm.so*') for p in mesa.glob(glob)}
files.add(mesa/'gbm/dri_gbm.so')
manifest=''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  ./'+str(p.relative_to(mesa))+'\n'
                 for p in sorted(files,key=lambda p:str(p.relative_to(mesa))) if p.is_file() and not p.is_symlink())
assert 'mesa-'+hashlib.sha256(manifest.encode()).hexdigest()[:16]==d['mesa_bundle'], 'Unqualified Mesa bundle'

for p,key in ((qt,'qt_gui_sha256'),(plugin,'mobileshell_sha256')):
 b=p.read_bytes(); assert hashlib.sha256(b).hexdigest()==d[key], p
 assert b[:6]==b'\x7fELF\x01\x01' and struct.unpack_from('<H',b,18)[0]==40,p
backup=installed.with_name(installed.name+'.t531-original')
for p,key in ((backup if backup.exists() else installed,'mobileshell_original_sha256'),):
 assert hashlib.sha256(p.read_bytes()).hexdigest()==d[key],p
print(d['qt_gui_sha256']);print(d['mobileshell_sha256']);print(d['qt_gui_version'])
PY
)
[[ ${#pins[@]} == 3 ]]
qt=/opt/t531-graphics/qt-${pins[0]:0:16}
plugin=/opt/t531-graphics/mobileshell-${pins[1]:0:16}
install -d -m755 "$qt" "$plugin"
for pair in "$qt_source:$qt/libQt6Gui.so.${pins[2]}" "$plugin_source:$plugin/libmobileshellplugin.so"; do
 source=${pair%%:*}; destination=${pair#*:}
 if [[ -e $destination ]]; then cmp "$source" "$destination"; else
  install -m644 "$source" "$destination.new"
  mv "$destination.new" "$destination"
 fi
 chown root:root "$destination"
done
ln -sfn "libQt6Gui.so.${pins[2]}" "$qt/libQt6Gui.so.6"
bash "$project/scripts/install-mesa-shell.sh" "$mesa" "$qt"
owner=$(dpkg-divert --listpackage "$lib")
if [[ -z $owner ]]; then
 dpkg-divert --local --add --rename --divert "$lib.t531-original" "$lib"
else
 [[ $owner == LOCAL && $(dpkg-divert --truename "$lib") == "$lib.t531-original" ]]
fi
if ! cmp -s "$plugin/libmobileshellplugin.so" "$lib"; then
 install -m644 "$plugin/libmobileshellplugin.so" "$lib.new"
 mv "$lib.new" "$lib"
fi
install -Dm644 "$lock" /etc/t531/graphics-stack.lock.json
sync -f /etc/t531
printf 'Qualified stack installed. Restart Plasma to load it.\n'
