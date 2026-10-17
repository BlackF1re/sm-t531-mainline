#!/usr/bin/env bash
# Explicit native activation after SSH; firmware bridge power is diagnostic.
set -euo pipefail
[[ $EUID == 0 ]]
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
grep -qw 't531.native_kms=1' /proc/cmdline
[[ -r /usr/lib/arm-linux-gnueabihf/dri/msm-kms_dri.so ]] || {
    echo 'Install t531-mesa-msm-kms before activating split native graphics'
    exit 1
}
modprobe arm_smmu
modprobe tc358764 firmware_power=1
modprobe msm separate_gpu_kms=1 matisse_lp11_reset=1 matisse_defer_video=1 \
    matisse_phy_profile=7
display=/dev/dri/by-path/platform-fd900100.display-controller-card
renderer=/dev/dri/by-path/platform-fdb00000.gpu-render
for ((attempt=0; attempt<20; attempt++)); do
    [[ ! -c $display || ! -c $renderer ]] || break
    sleep 1
done
[[ -c $display && -c $renderer ]]
card=$(basename "$(readlink -f "$display")")
# Fixed LVDS panels can remain "unknown" until the first mode probe.
[[ -r /sys/class/drm/$card-LVDS-1/status ]]
[[ $(cat "/sys/class/drm/$card-LVDS-1/status") != disconnected ]]
echo 'Native MDP5/DSI and separate Adreno render node are ready.'
