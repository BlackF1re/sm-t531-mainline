#!/usr/bin/env bash
# Record real touch gestures, without changing Plasma animation settings.
set -euo pipefail
umask 077
[[ $EUID == 0 ]]
tr '\0' '\n' </proc/device-tree/compatible | grep -qx samsung,matisse3g
exec 9>/run/lock/t531-graphics-profile.lock
flock -n 9 || { echo 'Another graphics recording is active'; exit 1; }
project=$(realpath "$(dirname "$0")/..")
out=${1:?Usage: profile-drawer.sh NEW_OUTPUT_DIRECTORY [SECONDS]}
seconds=${2:-15}
[[ $seconds =~ ^[0-9]+$ && $seconds -ge 5 && $seconds -le 60 ]]
[[ ! -e $out ]]
mkdir -p "$out"
python3 "$project/tools/graphics-path.py" --require-unlocked --expect native-kms >"$out/graphics-path.json"
record= sampler=
cleanup() {
    for pid in "$record" "$sampler"; do
        [[ -z $pid ]] || kill "$pid" 2>/dev/null || true
    done
    wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM
# /proc/uptime includes suspend, whereas printk timestamps do not. Use a
# kernel-generated marker so error filtering keeps working after resume.
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
' "$marker" >"$out/kernel-start.txt"
events=drm:drm_vblank_event_delivered,drm_msm_gpu:msm_gpu_devfreq_status,drm_msm_gpu:msm_gpu_submit,drm_msm_gpu:msm_gpu_submit_retired,drm_msm_gpu:msm_gpu_suspend,drm_msm_gpu:msm_gpu_resume,drm_msm_gpu:msm_gpu_freq_change
pages=64
case ${T531_PROFILE_ATOMIC:-0} in
    0) ;;
    1)
        events+=,drm_msm_atomic:*,dma_fence:dma_fence_wait_start,dma_fence:dma_fence_wait_end,dma_fence:dma_fence_signaled,drm:drm_vblank_event_queued
        pages=256
        ;;
    *) echo 'T531_PROFILE_ATOMIC must be 0 or 1'; exit 2 ;;
esac
printf '%s\n' "$events" >"$out/trace-events.txt"
# Match userspace CLOCK_MONOTONIC phase/action timestamps explicitly.
printf 'CLOCK_MONOTONIC\n' >"$out/trace-clock.txt"
perf record --clockid mono -a -m"$pages" -e "$events" \
    -o "$out/events.perf" -- sleep "$seconds" >"$out/perf.log" 2>&1 &
record=$!
python3 "$project/tools/sample-graphics.py" "$seconds" >"$out/metrics.jsonl" &
sampler=$!
echo "Recording $seconds seconds: repeatedly open and close the drawer now."
wait "$record"; record=
wait "$sampler"; sampler=
dmesg >"$out/kernel-after.txt"
python3 "$project/tools/summarize-display-errors.py" "$out/kernel-start.txt" \
    "$out/kernel-after.txt" >"$out/display-health.json"
python3 - "$out/kernel-start.txt" "$out/kernel-after.txt" <<'PY'
import pathlib, re, sys
start = float(pathlib.Path(sys.argv[1]).read_text())
for line in pathlib.Path(sys.argv[2]).read_text().splitlines():
    stamp = re.match(r"\[\s*([0-9.]+)\]", line)
    if stamp and float(stamp[1]) >= start and any(s in line for s in (
        "hangcheck detected gpu lockup", "hangcheck recover!",
        "timeout waiting to drain ringbuffer", "Unable to handle kernel",
    )):
        raise SystemExit("INVALID: GPU/kernel fault during recording")
PY
perf script -i "$out/events.perf" >"$out/events.txt" 2>"$out/perf-script.log"
if grep -Eiq 'PERF_RECORD_LOST|LOST [0-9]+|lost.*[0-9]+.*(event|sample)' \
        "$out/events.txt" "$out/perf-script.log"; then
    echo 'INVALID: lost trace events; preserve this recording as failed evidence'
    exit 1
fi
python3 "$project/tools/graphics-path.py" --require-unlocked --compare "$out/graphics-path.json" >"$out/graphics-path-after.json"
python3 "$project/tools/summarize-gpu-queue.py" "$out/events.txt" >"$out/gpu-queue.json"
python3 "$project/tools/summarize-drawer.py" "$out/events.txt" \
    --metrics "$out/metrics.jsonl" >"$out/summary.json"
cat "$out/summary.json"
cat "$out/display-health.json"
