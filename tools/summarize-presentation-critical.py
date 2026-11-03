#!/usr/bin/env python3
"""Correlate presentation intervals with outstanding MSM GPU jobs.

Retirement is a software notification; results are correlations, not exclusive
frame ownership or hardware execution timing. Restrict to one active CRTC.
"""
import argparse
import re,json,statistics,collections
from pathlib import Path
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('events',type=Path)
args=parser.parse_args()
source=args.events.read_text()
if re.search(r'PERF_RECORD_LOST|LOST \d+',source):
 raise SystemExit('INVALID: lost trace events')
pat=re.compile(r'^\s*(.*?)\s+(\d+)\s+\[\d+\]\s+([\d.]+):\s+(\w+):(\w+):\s+(.*)$')
jobs={};done=[];presents=[];flush=[];vblank=[];prev=None
for line in source.splitlines():
 m=pat.match(line)
 if not m:continue
 comm,pid,t,group,event,data=m.groups();t=float(t)
 if event=='msm_gpu_submit':
  ident=int(re.search(r'id=(\d+)',data)[1]);assert ident not in jobs
  jobs[ident]=dict(submit=t,owner=comm,tid=int(re.search(r'pid=(\d+)',data)[1]))
 elif event=='msm_gpu_submit_retired':
  j=jobs.pop(int(re.search(r'id=(\d+)',data)[1]),None)
  if j:
   assert j['tid']==int(re.search(r'pid=(\d+)',data)[1])
   j.update(end=t,start=max(j['submit'],prev) if prev else j['submit']);done.append(j)
  prev=t
 elif event=='drm_vblank_event_delivered':presents.append(t)
 elif event=='msm_atomic_flush_commit':flush.append(t)
 elif event=='drm_vblank_event':vblank.append(t)
def quant(x):
 x=sorted(x)
 return dict(n=len(x),p50=statistics.median(x),p95=x[int((len(x)-1)*.95)]) if x else None
if not done or len(presents)<2:
 raise SystemExit('No complete jobs/presentation intervals')
rows=[]
for a,b in zip(presents,presents[1:]):
 if not .010<b-a<.060:continue
 deadline=a+1/60-.0004
 pending=[j for j in done if j['submit']<=deadline<j['end']]
 owners=collections.Counter()
 for j in done:
  if j['start']<b and j['end']>a:owners[j['owner']]+=max(0,min(j['end'],b)-max(j['start'],a))*1000
 rows.append(dict(ms=(b-a)*1000,pending=sorted(set(j['owner'] for j in pending)),flushed=any(a<f<=deadline for f in flush),owner_ms=dict(owners)))
def group(rr):
 if not rr:return dict(frames=0)
 return dict(frames=len(rr),pending_gpu_frames=sum(bool(r['pending']) for r in rr),pending_owners=dict(collections.Counter(o for r in rr for o in r['pending'])),flushed_by_deadline=sum(r['flushed'] for r in rr),estimated_service_ms_per_interval={o:sum(r['owner_ms'].get(o,0) for r in rr)/len(rr) for o in sorted(set(o for r in rr for o in r['owner_ms']))})
r=dict(limitation='Deadline = previous presentation + 1/60 - 0.4 ms. Pending means submitted but not retired; jobs can belong to following frames. This does not establish which job blocked a particular framebuffer. Retirement-gap service includes notification/scheduling; not hardware GPU timestamps.',short=group([r for r in rows if r['ms']<25]),late=group([r for r in rows if r['ms']>=25]),vblank_interval_ms=quant([(b-a)*1000 for a,b in zip(vblank,vblank[1:]) if b-a<.1]),jobs={o:quant([(j['end']-j['submit'])*1000 for j in done if j['owner']==o]) for o in sorted(set(j['owner'] for j in done))},unretired=len(jobs))
print(json.dumps(r,indent=2))
