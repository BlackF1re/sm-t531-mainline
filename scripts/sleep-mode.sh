#!/usr/bin/env bash
# Select a system suspend policy; does not suspend or measure battery life.
set -euo pipefail
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
parameter=/sys/module/cpuidle_qcom_spm/parameters/l2_sleep_mode
case ${1:-status} in
 status)
  cat /sys/power/state /sys/power/mem_sleep
  [[ ! -r $parameter ]] || printf 'L2 selector: %s\n' "$(cat "$parameter")"
  exit;;
 s2idle) state=s2idle; l2=0;;
 shallow) state=shallow; l2=0;;
 standalone) state=deep; l2=0;;
 retention) state=deep; l2=1;;
 gdhs) state=deep; l2=2;;
 rpm) state=deep; l2=3;;
 *) echo 'Usage: t531-sleep-mode [status|s2idle|shallow|standalone|retention|gdhs|rpm]' >&2; exit 2;;
esac
[[ $EUID == 0 ]]
[[ -w $parameter ]]
grep -qw "$state" /sys/power/mem_sleep
[[ $(systemctl show systemd-suspend.service -p ActiveState --value) == inactive ]]
# Serialize policy changes. A selector is stored by tmpfiles at each boot.
exec 9>/run/lock/t531-sleep-policy.lock
flock -w 5 9
install -d /etc/systemd/sleep.conf.d /etc/tmpfiles.d
file=$(mktemp /etc/systemd/sleep.conf.d/.t531.XXXXXX)
printf '[Sleep]\nAllowSuspend=yes\nAllowHibernation=no\nAllowHybridSleep=no\nAllowSuspendThenHibernate=no\nSuspendState=mem\nMemorySleepMode=%s\n' "$state" > "$file"
chmod 644 "$file"
mv "$file" /etc/systemd/sleep.conf.d/40-t531-mode.conf
file=$(mktemp /etc/tmpfiles.d/.t531.XXXXXX)
printf 'w %s - - - - %s\n' "$parameter" "$l2" > "$file"
chmod 644 "$file"
mv "$file" /etc/tmpfiles.d/t531-sleep-mode.conf
printf '%s' "$l2" > "$parameter"
printf '%s' "$state" > /sys/power/mem_sleep
printf 'Suspend policy: %s; L2 selector: %s. System remains awake.\n' "$state" "$l2"
