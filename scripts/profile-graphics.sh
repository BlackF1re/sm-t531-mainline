#!/usr/bin/env bash
# Run on SM-T531 as root; copy tools/ alongside this script's parent directory.
set -euo pipefail
umask 077
[[ $EUID == 0 ]] || { echo 'Run as root on the tablet'; exit 1; }
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
exec 9>/run/lock/t531-graphics-profile.lock
flock -n 9 || { echo 'Another graphics recording is active'; exit 1; }
project=$(realpath "$(dirname "$0")/..")
destination=${1:?Usage: profile-graphics.sh OUTPUT_DIRECTORY}
[[ ! -e $destination ]] || { echo 'Choose a new output directory'; exit 1; }
mkdir -p "$destination"
destination=$(realpath "$destination")
command -v perf >/dev/null
user_uid=$(id -u t531)
workload=${GRAPHICS_WORKLOAD_QML:-$project/tools/frame-load.qml}
[[ -S /run/user/$user_uid/wayland-0 ]] || { echo 'No running Wayland session'; exit 1; }
runuser -u t531 -- test -r "$workload" || {
    echo 'Workload QML is not readable by the session user'; exit 1;
}
path_args=()
[[ -z ${GRAPHICS_PRESENTATION_PATH:-} ]] || path_args=(--expect "$GRAPHICS_PRESENTATION_PATH")
python3 "$project/tools/graphics-path.py" --require-unlocked "${path_args[@]}" > "$destination/graphics-path.json"
compositor_pid=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["compositor_pid"])' "$destination/graphics-path.json")
presentation_path=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["presentation_path"])' "$destination/graphics-path.json")
echo "$compositor_pid" > "$destination/compositor-pid.txt"
record_pid= sampler_pid= workload_pid=
cleanup() {
    for pid in "$workload_pid" "$record_pid" "$sampler_pid"; do
        [[ -z $pid ]] || kill "$pid" 2>/dev/null || true
    done
    wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM
uname -r > "$destination/kernel.txt"
# BOOTTIME includes suspend; printk timestamps use active kernel time.
# Obtain the filtering boundary from printk itself after any resume.
marker=$(cat /proc/sys/kernel/random/uuid)
printf '<6>t531-graphics-profile-start %s\n' "$marker" >/dev/kmsg
dmesg | python3 -c '
import re, sys
marker = "t531-graphics-profile-start " + sys.argv[1]
found = [re.match(r"\[\s*([0-9.]+)\]", line)[1]
         for line in sys.stdin if marker in line and re.match(r"\[\s*([0-9.]+)\]", line)]
if not found:
    raise SystemExit("Cannot locate kernel start marker")
print(found[-1])
' "$marker" > "$destination/kernel-start.txt"
cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor > "$destination/governor.txt"
# Include pre-created t531 kprobe events only when available. No global trace changes.
events=drm:drm_vblank_event_delivered
for event in blit blit_end update update_end wait wait_end; do
    if [[ -d /sys/kernel/tracing/events/t531/$event ]]; then
        events+=,t531:$event
    fi
done
if [[ -d /sys/kernel/tracing/events/drm_msm_gpu/msm_gpu_devfreq_status ]]; then
    events+=,drm_msm_gpu:msm_gpu_devfreq_status
fi
if [[ ${GRAPHICS_GPU_SUBMITS:-0} == 1 ]]; then
    for event in msm_gpu_submit msm_gpu_submit_retired; do
        if [[ -d /sys/kernel/tracing/events/drm_msm_gpu/$event ]]; then
            events+=,drm_msm_gpu:$event
        fi
    done
fi
printf 'CLOCK_MONOTONIC\n' >"$destination/trace-clock.txt"
perf record --clockid mono -a -m 64 -e "$events" -o "$destination/events.perf" -- sleep 35 \
    > "$destination/perf.log" 2>&1 &
record_pid=$!
python3 "$project/tools/sample-graphics.py" 35 > "$destination/metrics.jsonl" &
sampler_pid=$!
sleep 2
python3 -c 'import time; print(time.monotonic())' > "$destination/start.txt"
# Diagnostic processes terminate even when a compositor/client stops responding.
runuser -u t531 -- timeout 30s env XDG_RUNTIME_DIR="/run/user/$user_uid" \
    WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=wayland QSG_RHI_BACKEND=opengl \
    QSG_INFO=1 \
    FD_MESA_DEBUG="${GRAPHICS_FD_MESA_DEBUG-inorder}" \
    /usr/lib/qt6/bin/qmlscene "$workload" \
    > "$destination/workload.log" 2>&1 &
workload_pid=$!
workload_status=0
wait "$workload_pid" || workload_status=$?
echo "$workload_status" > "$destination/workload-exit.txt"
# A cold Qt startup can delay its quit timer. The bounded timeout is expected;
# other failures are not. DRM samples below still must form a valid workload.
[[ $workload_status == 0 || $workload_status == 124 ]] || {
    echo 'Workload failed; inspect workload.log'; exit 1;
}
workload_pid=
wait "$record_pid"; record_pid=
wait "$sampler_pid"; sampler_pid=
dmesg > "$destination/kernel-after.txt"
python3 "$project/tools/summarize-display-errors.py" "$destination/kernel-start.txt" \
    "$destination/kernel-after.txt" > "$destination/display-health.json"
python3 - "$destination/kernel-start.txt" "$destination/kernel-after.txt" <<'PY'
import pathlib, re, sys
start = float(pathlib.Path(sys.argv[1]).read_text())
failures = []
for line in pathlib.Path(sys.argv[2]).read_text().splitlines():
    stamp = re.match(r"\[\s*([0-9.]+)\]", line)
    if stamp and float(stamp[1]) >= start and any(s in line for s in (
        "hangcheck detected gpu lockup", "hangcheck recover!",
        "timeout waiting to drain ringbuffer", "Unable to handle kernel",
    )):
        failures.append(line)
if failures:
    print("INVALID: GPU/kernel fault during recording", file=sys.stderr)
    print("\n".join(failures[:8]), file=sys.stderr)
    raise SystemExit(1)
PY
perf script -i "$destination/events.perf" > "$destination/events.txt" 2> "$destination/perf-script.log"
if grep -Eiq 'PERF_RECORD_LOST|LOST [0-9]+|lost.*[0-9]+.*(event|sample)' \
        "$destination/events.txt" "$destination/perf-script.log"; then
    echo 'INVALID: lost trace events; preserve this recording as failed evidence'
    exit 1
fi
python3 "$project/tools/graphics-path.py" --require-unlocked --compare "$destination/graphics-path.json" > "$destination/graphics-path-after.json"
python3 "$project/tools/summarize-graphics.py" "$destination/events.txt" \
    --metrics "$destination/metrics.jsonl" --start "$(cat "$destination/start.txt")" \
    --presentation-path "$presentation_path" \
    > "$destination/summary.json"
cat "$destination/summary.json"
cat "$destination/display-health.json"
