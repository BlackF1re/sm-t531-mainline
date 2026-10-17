#!/usr/bin/env python3
"""Summarize single-CRTC MSM commit/fence timings without treating waits as CPU work."""
import argparse
import collections
import json
import re
import statistics
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('events', type=Path, help='Lossless perf script recording')
args = parser.parse_args()
text = args.events.read_text()
if re.search(r'PERF_RECORD_LOST|LOST \d+|lost.*\d+.*(?:event|sample)', text, re.I):
    raise SystemExit('INVALID: trace contains lost events')
pattern = re.compile(r'\s(\d+) \[\d+\]\s+([\d.]+):\s+(\w+):(\w+):\s+(.*)')
fence_key = re.compile(r'context=(\d+) seqno=(\d+)')
active = {}
waits = {}
completed = []
fence_durations = collections.defaultdict(list)
unmatched_presents = 0
matched_presents = 0
for line in text.splitlines():
    match = pattern.search(line)
    if not match:
        continue
    tid, stamp, system, event, fields = match.groups()
    tid, stamp = int(tid), float(stamp)
    if event == 'msm_atomic_commit_tail_start':
        if tid in active:
            raise SystemExit('INVALID: overlapping atomic tails on one thread')
        active[tid] = dict(start=stamp, async_commit='async=1' in fields,
                           mask=fields.split('crtc_mask=')[-1])
    elif event == 'msm_atomic_flush_commit' and tid in active:
        active[tid]['flush'] = stamp
    elif event == 'msm_atomic_commit_tail_finish':
        commit = active.pop(tid, None)
        if commit is not None:
            commit['finish'] = stamp
            completed.append(commit)
    elif event == 'drm_vblank_event_delivered':
        candidates = [c for c in active.values() if c['mask'] == '1' and
                      'flush' in c and 'present' not in c and not c['async_commit']]
        if len(candidates) == 1:
            candidates[0]['present'] = stamp
            matched_presents += 1
        else:
            unmatched_presents += 1
    elif event in ('dma_fence_wait_start', 'dma_fence_wait_end'):
        key = fence_key.search(fields)
        if not key:
            raise SystemExit('INVALID: unrecognized fence event format')
        key = (tid, *key.groups())
        if event.endswith('start'):
            if key in waits:
                raise SystemExit('INVALID: duplicate fence wait start')
            waits[key] = (stamp, fields.split('driver=')[1].split()[0])
        elif key in waits:
            start, driver = waits.pop(key)
            if stamp < start:
                raise SystemExit('INVALID: reversed fence timestamps')
            fence_durations[driver].append((stamp-start)*1000)


def stats(values):
    values = sorted(values)
    return dict(samples=len(values), p50_ms=statistics.median(values),
                p95_ms=values[int((len(values)-1)*.95)], maximum_ms=max(values)) if values else None


if not completed:
    raise SystemExit('No complete MSM atomic commits')
flushed = [c for c in completed if 'flush' in c and not c['async_commit']]
presented = [c for c in flushed if 'present' in c]
print(json.dumps(dict(
    evidence='Single CRTC, unique active flushed atomic tail at presentation; not optical timing.',
    commit_prepare=stats([(c['flush']-c['start'])*1000 for c in flushed]),
    flush_to_presentation=stats([(c['present']-c['flush'])*1000 for c in presented]),
    fence_waits={driver: stats(values) for driver, values in fence_durations.items()},
    matched_presents=matched_presents, unmatched_presents=unmatched_presents,
    incomplete_atomic_tails=len(active), incomplete_fence_waits=len(waits),
    limitation='Initial modesets are included. Fence waits include scheduling and are not CPU execution or pure GPU execution.'
), indent=2))
