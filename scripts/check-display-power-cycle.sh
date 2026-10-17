#!/usr/bin/env bash
# Exercise Phosh's normal display-power API; never unload drivers or suspend.
set -euo pipefail
umask 077
[[ $EUID == 0 ]]
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
power_mode() {
    runuser -u t531 -- env XDG_RUNTIME_DIR=/run/user/1000 \
        DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
        busctl --user set-property org.gnome.Mutter.DisplayConfig \
        /org/gnome/Mutter/DisplayConfig org.gnome.Mutter.DisplayConfig PowerSaveMode i "$1"
}
if [[ ${1:-} == --on ]]; then power_mode 0; exit; fi
out=${1:?Usage: check-display-power-cycle.sh NEW_OUTPUT_DIRECTORY [CYCLES]}
cycles=${2:-1}
[[ $cycles =~ ^[1-4]$ && ! -e $out ]]
out=$(realpath -m "$out")
script=$(realpath "$0")
project=$(dirname "$(dirname "$script")")
exec 9>/run/lock/t531-graphics-profile.lock
flock -n 9
pgrep -u t531 -x phosh >/dev/null
mkdir -m700 "$out"
python3 "$project/tools/graphics-path.py" --expect native-kms >"$out/path.json"
dmesg >"$out/kernel-before.txt"
marker=$(cat /proc/sys/kernel/random/uuid)
printf '<6>t531-display-power-test %s\n' "$marker" >/dev/kmsg
dmesg | python3 -c '
import re,sys
for line in sys.stdin:
    if sys.argv[1] in line:
        print(re.match(r"\[\s*([0-9.]+)\]", line)[1])
' "$marker" >"$out/start.txt"
seconds=$((cycles * 4 + 5))
systemd-run --quiet --unit=t531-display-power-restore \
    --on-active="$((seconds + 10))s" /bin/bash "$script" --on
recorder=
cleanup() {
    [[ -z $recorder ]] || kill "$recorder" 2>/dev/null || true
    power_mode 0 || true
    systemctl stop t531-display-power-restore.timer >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM
perf record --clockid mono -a -m64 \
    -e 'drm_msm_atomic:*,printk:console,drm:drm_vblank_event_delivered' \
    -o "$out/events.perf" -- sleep "$seconds" >"$out/perf.log" 2>&1 &
recorder=$!
sleep 1
for ((cycle=0; cycle<cycles; cycle++)); do
    power_mode 3
    sleep 2
    power_mode 0
    sleep 2
done
wait "$recorder"
recorder=
dmesg >"$out/kernel-after.txt"
perf script -i "$out/events.perf" >"$out/events.txt" 2>"$out/perf-script.log"
! grep -Eiq 'PERF_RECORD_LOST|LOST [0-9]+|lost.*[0-9]+.*(event|sample)' \
    "$out/events.txt" "$out/perf-script.log"
python3 "$project/tools/summarize-display-errors.py" "$out/start.txt" \
    "$out/kernel-after.txt" >"$out/display-health.json"
cat "$out/display-health.json"
python3 - "$out/display-health.json" <<'PY'
import json,sys
if json.load(open(sys.argv[1]))['logged_mdp5_underruns']:
    raise SystemExit('Display power cycle recorded an MDP5 underrun')
PY
