#!/usr/bin/env bash
# Install the SM-T531 sleep policy; no suspend/battery test is started.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $EUID == 0 ]]
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
[[ -w /sys/module/cpuidle_qcom_spm/parameters/l2_sleep_mode ]]
install -Dm755 scripts/sleep-mode.sh /usr/local/sbin/t531-sleep-mode
install -Dm644 scripts/80-t531-bms-poll-no-wakeup.rules \
 /etc/udev/rules.d/80-t531-bms-poll-no-wakeup.rules
# Polling battery telemetry must not report a synthetic wakeup event.
if [[ -w /sys/class/power_supply/pm8226-bms/power/wakeup ]]; then
 echo disabled > /sys/class/power_supply/pm8226-bms/power/wakeup
fi
/usr/local/sbin/t531-sleep-mode "${1:-s2idle}"
