#!/bin/bash
# Install only after separate approval. Every boot write is confined to the SD.
set -Eeuo pipefail
[[ $EUID == 0 ]]
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
state=/var/lib/t531/graphics-ab
pending=$state/pending
exec 9>/run/lock/t531-graphics-ab.lock
flock -w 30 9
verify_baseline() {
 baseline=$(cat "$state/baseline")
 [[ $baseline =~ ^/var/lib/t531/graphics-baselines/[0-9TZ]+$ ]]
 (cd "$baseline"; sha256sum -c files.sha256 >/dev/null)
 [[ $(cat "$baseline/kernel.release") =~ ^[0-9][a-zA-Z0-9._+-]+$ ]]
}
boot_mount() {
 [[ $(blkid -s LABEL -o value /dev/mmcblk1p1) == T531_BOOT ]]
 [[ $(cat /sys/class/block/mmcblk1p1/size) == 98304 ]]
 [[ $(findmnt -rn -o SOURCE /) == /dev/mmcblk1p2 ]]
 ! findmnt -rn -S /dev/mmcblk1p1 >/dev/null
 point=$(mktemp -d /run/t531-graphics-boot.XXXXXX)
 mount -t ext2 /dev/mmcblk1p1 "$point"
 trap 'umount "$point"; rmdir "$point"' EXIT
}
slot() {
 python3 - "$point" "$@" <<'PY'
import sys
sys.path.insert(0, '/usr/local/lib/t531-graphics-ab')
import slots
root, action, *args = sys.argv[1:]
getattr(slots, action)(root, *args)
PY
}
restore_config() {
 # The snapshot lists whole directories, preserving all overrides and absences.
 # The recovery guard is deliberately outside these snapshotted paths.
 while IFS= read -r path; do
  case $path in
   etc/modprobe.d/msm.conf|etc/environment.d/60-t531-graphics.conf|etc/systemd/system/t531-native-graphics.service|etc/systemd/system/t531-native-graphics.service.d|etc/systemd/system/t531-native-kms-recovery.service|etc/systemd/system/sddm.service.d|usr/local/sbin/t531-start-native-graphics|usr/local/sbin/t531-graphics-rollback|home/t531/.config/systemd/user/plasma-kwin_wayland.service.d|home/t531/.config/systemd/user/plasma-plasmashell.service.d|home/t531/.config/kdeglobals|etc/modules-load.d) rm -rf -- "/$path";;
   *) echo "Refusing unexpected snapshot path: $path" >&2; exit 1;;
  esac
 done < "$baseline/meta/config-paths.txt"
 tar -C / -xzf "$baseline/config.tar.gz"
 if [[ -f $state/restore-panel-diversion ]]; then
  library=/usr/lib/arm-linux-gnueabihf/qt6/qml/org/kde/plasma/private/mobileshell/libmobileshellplugin.so
  if [[ $(dpkg-divert --listpackage "$library") != LOCAL ]]; then
   dpkg-divert --local --add --divert "$library.t531-original" "$library"
  fi
  python3 - "$baseline/graphics-libraries.tar.gz" <<'PYRESTORE'
import os, pathlib, shutil, sys, tarfile
name='usr/lib/arm-linux-gnueabihf/qt6/qml/org/kde/plasma/private/mobileshell/libmobileshellplugin.so'
with tarfile.open(sys.argv[1]) as archive:
 for member in archive.getmembers():
  if member.name not in (name, name+'.t531-original') or not member.isfile():
   raise SystemExit('Unexpected library archive member')
 for member in archive.getmembers():
  path=pathlib.Path('/')/member.name
  temporary=path.with_name(path.name+'.t531-restore')
  with archive.extractfile(member) as source, temporary.open('wb') as target:
   shutil.copyfileobj(source,target); target.flush(); os.fsync(target.fileno())
  temporary.chmod(member.mode & 0o777)
  os.replace(temporary,path)
PYRESTORE
 fi
 systemctl daemon-reload
 sync -f /etc
}
case ${1:-} in
 prepare)
  # Caller has installed candidate modules under a NEW release, never over old ones.
  baseline=${2:?baseline directory}; source=${3:?trial boot files}; release=${4:?candidate release}
  [[ $release =~ ^[0-9][a-zA-Z0-9._+-]+$ && $release != "$(uname -r)" ]]
  [[ -f /lib/modules/$release/modules.dep && ! -e $pending ]]
  systemctl is-enabled --quiet t531-graphics-ab-guard.service
  [[ -x /usr/local/sbin/t531-start-native-graphics && -f /usr/local/lib/t531-graphics-ab/slots.py ]]
  [[ $(modinfo -b / -k "$release" -F vermagic msm | cut -d' ' -f1) == "$release" ]]
  grep -qw t531.native_kms=0 "$source/kexec.cmdline"
  grep -q 't531.graphics_trial=' "$source/kexec.cmdline"
  install -d -m700 "$state"
  printf '%s\n' "$baseline" > "$state/baseline"
  verify_baseline
  printf '%s\n' "$release" > "$state/candidate.release"
  printf '%s\n' "$(realpath "$source")" > "$state/candidate.source"
  echo trial > "$state/phase"
  boot_mount
  for filename in zImage initramfs.cpio.gz kernel.sha256 kexec.cmdline; do
   cmp "$point/$filename" "$baseline/boot/$filename"
  done
  slot initialize golden
  trial=trial-$(sha256sum "$source/zImage" | cut -c1-12)
  slot stage "$source" "$trial"
  printf '%s\n' "$trial" > "$state/candidate.slot"
  # Persist the guard before making a trial boot selectable.
  touch "$pending"; sync -f "$state"
  slot select "$trial"
  echo 'Trial selected; no reboot performed.'
  ;;
 guard)
  [[ -e $pending ]] || exit 0
  verify_baseline; boot_mount
  # First action on EVERY pending boot: the next boot selects the old kernel.
  slot select golden
  if [[ $(uname -r) == "$(cat "$state/candidate.release")" ]] && {
   grep -q 't531.graphics_trial=' /proc/cmdline || {
    [[ $(cat "$state/phase") == production ]] && grep -qw t531.native_kms=1 /proc/cmdline;
   };
  }; then
   systemctl start t531-graphics-ab-timeout.timer
   echo 'SSH-only trial: golden boot restored; fifteen-minute rollback armed.'
  else
   restore_config
   mv "$pending" "$state/rolled-back"
   sync -f "$state"
  fi
  ;;
 recover)
  verify_baseline
  touch "$pending"; sync -f "$state"
  boot_mount; slot select golden; restore_config
  systemctl --no-block reboot
  ;;
 rollback)
  [[ -e $pending ]] || exit 0
  verify_baseline; boot_mount; slot select golden; restore_config
  # Leave pending until a golden boot completes restoration.
  systemctl --no-block reboot
  ;;
 promote)
  [[ -e $pending && $(uname -r) == "$(cat "$state/candidate.release")" ]]
  /usr/local/libexec/t531-drm-probe --require-unified
  source=${2:?production boot directory}
  grep -qw t531.native_kms=1 "$source/kexec.cmdline"
  ! grep -q 't531.graphics_trial=' "$source/kexec.cmdline"
  verify_baseline; boot_mount
  [[ $(readlink "$point/graphics-current") == graphics-slots/golden ]]
  # Reclaim the trial slot only after proving its rootfs copy still matches.
  slot retire "$(cat "$state/candidate.slot")" "$(cat "$state/candidate.source")"
  production=production-$(sha256sum "$source/zImage" | cut -c1-12)
  slot stage "$source" "$production"
  printf '%s\n' "$production" > "$state/production.slot"
  echo production > "$state/phase"
  sync -f "$state"
  slot select "$production"
  echo 'Production boot selected; confirmation is required after reboot.'
  ;;
 confirm-primary)
  # Runtime acceptance only: do not mislabel this as cold-boot validation.
  [[ -e $pending && $(uname -r) == "$(cat "$state/candidate.release")" ]]
  [[ $(cat "$state/phase") == production ]]
  /usr/local/libexec/t531-drm-probe --require-unified
  boot_mount
  slot select "$(cat "$state/production.slot")"
  echo runtime-only > "$state/acceptance"
  mv "$pending" "$state/accepted"
  sync -f "$state"
  systemctl stop t531-graphics-ab-timeout.timer
  echo 'Unified DRM selected as the normal boot; cold-boot acceptance remains pending.'
  ;;
 confirm-boot)
  [[ -e $pending && $(uname -r) == "$(cat "$state/candidate.release")" ]]
  [[ $(cat "$state/phase") == production ]]
  grep -qw t531.native_kms=1 /proc/cmdline
  /usr/local/libexec/t531-drm-probe --require-unified
  boot_mount
  slot select "$(cat "$state/production.slot")"
  mv "$pending" "$state/accepted"
  sync -f "$state"
  systemctl stop t531-graphics-ab-timeout.timer
  echo 'Unified DRM production boot accepted; golden remains an offline recovery slot.'
  ;;
 confirm-session)
  [[ -e $pending && $(uname -r) == "$(cat "$state/candidate.release")" ]]
  /usr/local/libexec/t531-drm-probe --require-unified
  systemctl stop t531-graphics-ab-timeout.timer
  # Deliberately do not promote: golden remains the next boot.
  echo 'Session accepted; golden is still the next boot. Production promotion is separate.'
  ;;
 *) echo 'Usage: t531-graphics-ab prepare BASELINE TRIAL_DIR RELEASE | guard | rollback | recover | confirm-session | promote PROD_DIR | confirm-primary | confirm-boot' >&2; exit 2;;
esac
