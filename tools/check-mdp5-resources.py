#!/usr/bin/env python3
"""Check live MDP5 pipe ownership and SMP reservation consistency (read only)."""
import json,pathlib,re,sys
p=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else '/sys/kernel/debug/dri/0/state')
s=p.read_text();owners={};plane=None
for line in s.splitlines():
 m=re.match(r'plane\[\d+\]: (\S+)',line)
 if m:plane=m[1]
 m=re.match(r'\s*hwpipe=(\S+)',line)
 if m and m[1]!='(null)':
  pipe=m[1]
  assert pipe not in owners, f'{pipe} assigned to both {owners.get(pipe)} and {plane}'
  owners[pipe]=plane
reservations={}
for pipe,client,blocks,owner in re.findall(r'^(\w+):(\d+)\s+(\d+)\s+(\S+)',s,re.M):
 if owner!='(null)':
  assert owners.get(pipe)==owner, f'{pipe} SMP owner {owner}, plane owner {owners.get(pipe)}'
  reservations[pipe]=reservations.get(pipe,0)+int(blocks)
for pipe,owner in owners.items():
 assert reservations.get(pipe,0)>0, f'{pipe} owned by {owner} without SMP buffers'
print(json.dumps({'owners':owners,'smp_blocks':reservations,'consistent':True}))
