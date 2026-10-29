#!/usr/bin/env python3
"""Summarize one-thread raw ioctl traces; times include scheduling delays."""
import json
from pathlib import Path
import re
import statistics
import sys
enter = re.compile(r'\s(\d+)\s+\[\d+\]\s+([\d.]+):\s+raw_syscalls:sys_enter:\s+NR 54 \(([^)]+)\)')
leave = re.compile(r'\s(\d+)\s+\[\d+\]\s+([\d.]+):\s+raw_syscalls:sys_exit:\s+NR 54 = (\S+)')
active = {}
values = {}
failed = {}
for line in Path(sys.argv[1]).read_text().splitlines():
    m=enter.search(line)
    if m:
        pid, stamp, args = m.groups()
        fd, cmd, *_ = [int(a.strip(),16) for a in args.split(',')]
        active[pid]=(float(stamp),fd,cmd)
        continue
    m=leave.search(line)
    if m:
        pid, stamp, result = m.groups()
        if pid not in active: continue
        start,fd,cmd=active.pop(pid)
        if cmd != 0xc00c642e: continue
        key=f'fd={fd}'
        if result!='0':failed[key]=failed.get(key,0)+1
        else:values.setdefault(key,[]).append((float(stamp)-start)*1000)
result={}
for key,v in values.items():
    ordered=sorted(v)
    result[key]={'count':len(v),'total_ms':sum(v),'median_ms':statistics.median(v),
                 'p95_ms':ordered[int((len(v)-1)*.95)],'max_ms':max(v),'failed':failed.get(key,0)}
print(json.dumps({'kind':'PRIME_FD_TO_HANDLE wall times by fd','imports':result},indent=2))
