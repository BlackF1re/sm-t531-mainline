#!/usr/bin/env python3
"""Presentation bursts for manual gestures; idle gaps are not animation FPS."""
import argparse
import json
import re
import statistics

parser = argparse.ArgumentParser()
parser.add_argument("events")
parser.add_argument("--metrics")
parser.add_argument("--gap-ms", type=float, default=100)
args = parser.parse_args()
events = []
pattern = re.compile(r"\s(\d+)\s+\[\d+\]\s+([\d.]+):\s+(\S+):\s*(.*)")
for line in open(args.events):
    match = pattern.search(line)
    if match:
        pid, stamp, name, data = match.groups()
        events.append((int(pid), float(stamp), name, data))
bursts = []
for _, stamp, name, _ in events:
    if name != "drm:drm_vblank_event_delivered":
        continue
    if not bursts or stamp - bursts[-1][-1] > args.gap_ms / 1000:
        bursts.append([])
    bursts[-1].append(stamp)
bursts = [burst for burst in bursts if len(burst) >= 4]
intervals = [(b-a)*1000 for burst in bursts for a, b in zip(burst, burst[1:])]
if not intervals:
    raise SystemExit("No sustained presentations: repeat the gesture recording")
ordered = sorted(intervals)
result = {
    "kind": "Native DRM presentation bursts during manual gestures; not optical FPS",
    "idle_gap_threshold_ms": args.gap_ms,
    "limitation": "Gaps over the threshold may be pauses or severe jank; no per-gesture boundaries",
    "active_fps": 1000 / statistics.mean(intervals),
    "frame_interval": {
        "samples": len(intervals), "p50_ms": statistics.median(intervals),
        "p95_ms": ordered[int((len(ordered)-1)*.95)],
        "p99_ms": ordered[int((len(ordered)-1)*.99)],
        "over_25ms_percent": 100*sum(i > 25 for i in intervals)/len(intervals),
    },
    "bursts": [{"start": b[0], "seconds": b[-1]-b[0], "frames": len(b),
                "fps": (len(b)-1)/(b[-1]-b[0])} for b in bursts],
}
gpu = []
for _, _, name, data in events:
    if name == "drm_msm_gpu:msm_gpu_devfreq_status":
        values = {k: int(v) for k, v in re.findall(r"(total|busy)=(\d+)", data)}
        if values.get("total", 0) > 0 and values["busy"] <= values["total"]:
            gpu.append(values)
if gpu:
    result["gpu_busy_percent_recording"] = 100*sum(s["busy"] for s in gpu)/sum(s["total"] for s in gpu)
if args.metrics:
    rows = [json.loads(line) for line in open(args.metrics)]
    if rows and rows[0]["oom_kill"] != rows[-1]["oom_kill"]:
        raise SystemExit("INVALID: OOM during recording")
    rows = [r for r in rows if events[0][1] <= r["time"] <= events[-1][1]]
    if len(rows) > 1:
        delta = [b-a for a, b in zip(rows[0]["cpu_ticks"], rows[-1]["cpu_ticks"])]
        result["cpu_busy_percent_recording_all_cores"] = 100*(sum(delta)-delta[3]-delta[4])/sum(delta)
        for key in ("cpu_khz", "gpu_hz", "axi_hz"):
            values = [r[key] for r in rows if r.get(key) is not None]
            if values:
                result[key+"_median"] = statistics.median(values)
print(json.dumps(result, indent=2))
