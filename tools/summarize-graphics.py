#!/usr/bin/env python3
"""Summarize perf script events. DRM completion is not measured optical scanout."""
import argparse
import json
import re
import statistics

p = argparse.ArgumentParser()
p.add_argument("events")
p.add_argument("--metrics")
p.add_argument("--start", type=float, help="CLOCK_MONOTONIC start of workload")
p.add_argument("--warmup", type=float, default=5)
p.add_argument("--duration", type=float, default=25)
p.add_argument("--presentation-path", choices=("simpledrm", "native-kms"),
               default="native-kms", help="KMS path used for this recording")
args = p.parse_args()
events = []
pattern = re.compile(r"\s(\d+)\s+\[\d+\]\s+([\d.]+):\s+(\S+):\s*(.*)")
for line in open(args.events):
    m = pattern.search(line)
    if m:
        pid, t, name, data = m.groups()
        events.append((int(pid), float(t), name, data))
frames = [t for _, t, n, _ in events if n == "drm:drm_vblank_event_delivered"]
if not frames:
    raise SystemExit("No DRM completions; workload/recording failed")
start = args.start if args.start is not None else frames[0]
lo, hi = start + args.warmup, start + args.duration - 1
frames = [t for t in frames if lo <= t <= hi]
if len(frames) < 3:
    raise SystemExit("Not enough frames in measurement window")

def distribution(samples):
    s = sorted(samples)
    return {"samples": len(s), "mean_ms": statistics.mean(s),
            "p50_ms": statistics.median(s), "p95_ms": s[int((len(s) - 1) * .95)],
            "p99_ms": s[int((len(s) - 1) * .99)]}

kind = ("DRM completion, synthetic simpledrm events" if args.presentation_path == "simpledrm"
        else "DRM completion, native hardware vblank; not optical measurement")
result = {"kind": kind,
          "window_seconds": hi - lo, "frames": len(frames),
          "fps": (len(frames) - 1) / (frames[-1] - frames[0]),
          "frame_interval": distribution([(b - a) * 1000 for a, b in zip(frames, frames[1:])])}
for label in ("blit", "update", "wait"):
    pending, intervals = {}, []
    for pid, t, name, _ in events:
        if name == "t531:" + label:
            pending[pid] = t
        elif name == "t531:" + label + "_end" and pid in pending:
            begin = pending.pop(pid)
            if lo <= begin <= t <= hi:
                intervals.append((t - begin) * 1000)
    if intervals:
        result[label] = distribution(intervals)
gpu_samples = []
for _, t, name, data in events:
    if name == "drm_msm_gpu:msm_gpu_devfreq_status" and lo <= t <= hi:
        values = dict((k, int(v)) for k, v in re.findall(r"(total|busy|frequency)=(\d+)", data))
        if values.get("total", 0) > 0 and values.get("busy", 0) <= values["total"]:
            gpu_samples.append(values)
if gpu_samples:
    result["gpu_busy_percent_devfreq"] = 100 * sum(r["busy"] for r in gpu_samples) / sum(r["total"] for r in gpu_samples)
    result["gpu_busy_samples"] = len(gpu_samples)
pending_jobs, job_times = {}, []
for _, t, name, data in events:
    if name not in ("drm_msm_gpu:msm_gpu_submit", "drm_msm_gpu:msm_gpu_submit_retired"):
        continue
    values = dict((k, int(v)) for k, v in re.findall(r"(id|pid)=(\d+)", data))
    key = (values.get("pid"), values.get("id"))
    if name.endswith("_submit"):
        pending_jobs[key] = t
    elif key in pending_jobs:
        begin = pending_jobs.pop(key)
        if lo <= begin <= t <= hi:
            job_times.append((t - begin) * 1000)
if job_times:
    result["gpu_submit_to_retire"] = distribution(job_times)
if args.metrics:
    rows = [json.loads(line) for line in open(args.metrics)]
    if rows and rows[-1].get("oom_kill", 0) != rows[0].get("oom_kill", 0):
        raise SystemExit("INVALID: OOM killer ran during recording")
    rows = [r for r in rows if lo <= r["time"] <= hi]
    if len(rows) > 1:
        if "mem_available_kib" in rows[0]:
            result["mem_available_kib_min"] = min(r["mem_available_kib"] for r in rows)
        delta = [b-a for a, b in zip(rows[0]["cpu_ticks"], rows[-1]["cpu_ticks"])]
        result["cpu_busy_percent_all_cores"] = 100 * (sum(delta)-delta[3]-delta[4]) / sum(delta)
        result["cpu_khz_median"] = statistics.median(r["cpu_khz"] for r in rows if r["cpu_khz"] is not None)
        result["gpu_hz_median"] = statistics.median(r["gpu_hz"] for r in rows if r["gpu_hz"] is not None)
        axi = [r["axi_hz"] for r in rows if r.get("axi_hz") is not None]
        if axi:
            result["axi_hz_median"] = statistics.median(axi)
print(json.dumps(result, indent=2))
