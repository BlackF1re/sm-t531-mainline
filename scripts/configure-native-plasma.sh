#!/usr/bin/env bash
# Switch only graphics device selection; run after accepted native scanout.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run as root on SM-T531'; exit 1; }
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
backup=/var/lib/t531/native-desktop-config
environment=/etc/environment.d/60-t531-graphics.conf
sddm=/etc/systemd/system/sddm.service.d/20-t531-graphics.conf
loader=/home/t531/.config/systemd/user/plasma-kwin_wayland.service.d/40-t531-native-loader.conf
case ${1:-activate} in
    restore)
        cd "$backup"
        sha256sum -c files.sha256
        install -m644 environment.conf "$environment"
        install -m644 sddm.conf "$sddm"
        rm -f "$loader"
        systemctl daemon-reload
        exit 0
        ;;
    activate) ;;
    *) echo 'Usage: configure-native-plasma.sh [activate|restore]'; exit 2;;
esac
device=/dev/dri/by-path/platform-fd900100.display-controller-card
[[ -c $device ]]
card=$(basename "$(readlink -f "$device")")
[[ -r /sys/class/drm/$card-LVDS-1/status ]]
[[ $(cat "/sys/class/drm/$card-LVDS-1/status") != disconnected ]]
if [[ -c /dev/dri/by-path/platform-fdb00000.gpu-render &&
      ! -r /usr/lib/arm-linux-gnueabihf/dri/msm-kms_dri.so ]]; then
    echo 'Install the t531-mesa-msm-kms package before selecting split native KMS'
    exit 1
fi
if systemctl is-active --quiet sddm || pgrep -x kwin_wayland >/dev/null; then
    echo 'Stop the graphical session before switching its device selection'
    exit 1
fi
[[ -f $environment && -f $sddm ]]
grep -q '^KWIN_DRM_DEVICES=' "$environment"
grep -q '^Environment=KWIN_DRM_DEVICES=' "$sddm"
if [[ ! -d $backup ]]; then
    install -d -m700 "$backup"
    install -m600 "$environment" "$backup/environment.conf"
    install -m600 "$sddm" "$backup/sddm.conf"
    (cd "$backup"; sha256sum environment.conf sddm.conf >files.sha256)
fi
(cd "$backup"; sha256sum -c files.sha256)
sed -e '/^MESA_LOADER_DRIVER_OVERRIDE=/d' \
    -e "s|^KWIN_DRM_DEVICES=.*|KWIN_DRM_DEVICES=$device|" "$environment" >"$environment.new"
sed -e '/^Environment=MESA_LOADER_DRIVER_OVERRIDE=/d' \
    -e "s|^Environment=KWIN_DRM_DEVICES=.*|Environment=KWIN_DRM_DEVICES=$device|" "$sddm" >"$sddm.new"
chmod 644 "$environment.new" "$sddm.new"
mv "$environment.new" "$environment"
mv "$sddm.new" "$sddm"
# Use the msm-kms entry; overrides also affect KWin's QML and child processes.
rm -f "$loader"
systemctl daemon-reload
echo 'Native device selected. Start SDDM after stopping the held KMS test.'
