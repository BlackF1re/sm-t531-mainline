#!/usr/bin/env python3
"""Submit-to-retire latency includes queueing; it is not GPU execution time."""
import argparse
import collections
import json
import re
import statistics

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("events", help="perf script output with MSM submit/retired events")
args = parser.parse_args()
pending = {}
samples = collections.defaultdict(list)
pattern = re.compile(r"\s([\d.]+):\s+drm_msm_gpu:msm_gpu_submit(_retired)?:\s+id=(\d+) pid=(\d+)")
for line in open(args.events):
    match = pattern.search(line)
    if not match:
        continue
    stamp, retired, job, tid = match.groups()
    stamp = float(stamp)
    if not retired:
        pending[job] = (stamp, tid)
    elif job in pending:
        start, submitted_tid = pending.pop(job)
        if tid != submitted_tid or stamp < start:
            raise SystemExit("INVALID: mismatched submission/retirement")
        samples[tid].append((stamp-start)*1000)
if not samples:
    raise SystemExit("No complete GPU jobs; recording cannot establish queue latency")
result = {"kind": __doc__, "unretired_at_record_end": len(pending), "threads": []}
for tid, values in sorted(samples.items()):
    ordered = sorted(values)
    result["threads"].append({"submitter_tid": int(tid), "jobs": len(values),
        "mean_ms": statistics.mean(values), "p50_ms": statistics.median(values),
        "p95_ms": ordered[int((len(ordered)-1)*.95)],
        "p99_ms": ordered[int((len(ordered)-1)*.99)]})
print(json.dumps(result, indent=2))
