#!/usr/bin/env python3
"""Separate opening/closing presentations using the uinput tool's timestamps."""
import argparse
import json
import re
import statistics

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("events")
parser.add_argument("actions")
args = parser.parse_args()
pattern = re.compile(r"\s\d+\s+\[\d+\]\s+([\d.]+):\s+drm:drm_vblank_event_delivered:")
flips = sorted(float(m[1]) for line in open(args.events) if (m := pattern.search(line)))
actions = [json.loads(line) for line in open(args.actions)]
rows = []
groups = {"open": [], "close": []}
for i, action in enumerate(actions):
    start = action["time"]
    end = min(start + 1.2, actions[i+1]["time"]) if i+1 < len(actions) else start + 1.2
    times = [t for t in flips if start <= t < end]
    intervals = [(b-a)*1000 for a, b in zip(times, times[1:])]
    row = {"action": action["action"], "cycle": action["cycle"],
           "input_write_time": start, "presentations_in_window": len(times),
           "first_present_after_input_ms": (times[0]-start)*1000 if times else None,
           "last_present_after_input_ms": (times[-1]-start)*1000 if times else None}
    if intervals:
        ordered = sorted(intervals)
        row.update(interval_p50_ms=statistics.median(intervals),
                   interval_p95_ms=ordered[int((len(ordered)-1)*.95)],
                   presentation_fps=1000/statistics.mean(intervals))
        groups[action["action"]].extend(intervals)
    rows.append(row)
summary = {}
for kind, intervals in groups.items():
    if not intervals:
        continue
    ordered = sorted(intervals)
    latencies = [r["first_present_after_input_ms"] for r in rows
                 if r["action"] == kind and r["first_present_after_input_ms"] is not None]
    summary[kind] = {"interval_samples": len(intervals),
                     "presentation_fps": 1000/statistics.mean(intervals),
                     "interval_p50_ms": statistics.median(intervals),
                     "interval_p95_ms": ordered[int((len(ordered)-1)*.95)],
                     "first_present_after_input_p50_ms": statistics.median(latencies)}
print(json.dumps({"limitation": "Action labels assume the panel was closed initially and were not independently verified for each toggle. Input timestamps precede uinput writes; first presentation is a scheduling proxy, not optical latency. Windows are 1.2s, without dropping long gaps or proving which surface changed.",
                  "summary": summary, "actions": rows}, indent=2))
