#!/usr/bin/env bash
# Unified MSM activation, deliberately delayed until remote access is ready.
set -euo pipefail
[[ $EUID == 0 ]]
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
[[ -x /usr/local/libexec/t531-drm-probe ]]
# This tablet's Wi-Fi service owns sshd; ssh.service may be inactive.
for ((attempt=0; attempt<45; attempt++)); do
    ss -ltnH '( sport = :22 )' | grep -q LISTEN && break
    sleep 1
done
ss -ltnH '( sport = :22 )' | grep -q LISTEN
# Do not unload or reconfigure an already running split driver.
if [[ -r /sys/module/msm/parameters/separate_gpu_kms ]]; then
    [[ $(cat /sys/module/msm/parameters/separate_gpu_kms) == N ]] || {
        echo 'Split MSM is loaded; a separately approved boot is required' >&2
        exit 1
    }
fi
modprobe arm_smmu
if [[ -e /proc/device-tree/soc/display-subsystem@fd900000/dsi@fd922800/bridge@0/enable-gpios ]]; then
    modprobe tc358764
else
    # Older SD slots need the firmware-powered bridge fallback.
    modprobe tc358764 firmware_power=1
fi
# Board PHY settings and topology live in one modprobe configuration.
modprobe msm
[[ $(cat /sys/module/msm/parameters/separate_gpu_kms) == N ]]
install -d -m755 /run/t531-graphics
/usr/local/libexec/t531-drm-probe --require-unified --wait 20 > /run/t531-graphics/device.json.new
mv /run/t531-graphics/device.json.new /run/t531-graphics/device.json
echo 'Unified Adreno 305 / MDP5 atomic DRM device ready.'
