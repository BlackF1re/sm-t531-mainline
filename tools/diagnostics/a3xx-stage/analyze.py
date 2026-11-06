import json,re,sys,collections,statistics
s=open(sys.argv[1]).read();dec=json.JSONDecoder();rows=[]
for m in re.finditer(r'\{\s*"events"\s*:',s):
 try:b,_=dec.raw_decode(s,m.start())
 except ValueError:continue
 ev=b['events']; st=next((e for e in ev if e['event']=='start_render_pass'),None);en=next((e for e in ev if e['event']=='end_render_pass'),None)
 if not st or not en:continue
 row=dict(st['params']);row['ms']=(int(en['time_ns'])-int(st['time_ns']))/1e6;row['stages_ms']={};starts={}
 for e in ev:
  n=e['event'];t=int(e['time_ns'])
  if n.startswith('start_'):starts[n[6:]]=t
  if n.startswith('end_') and n[4:] in starts:
   name=n[4:];row['stages_ms'][name]=row['stages_ms'].get(name,0)+(t-starts.pop(name))/1e6
 row['flush']=next((e['params'] for e in ev if e['event']=='flush_batch'),{})
 rows.append(row)
g=collections.defaultdict(list)
for r in rows:g[(r['width'],r['height'],r['nbins'],r['zs_format'])].append(r)
print('complete_passes',len(rows))
for k,rs in sorted(g.items(),key=lambda kv:sum(r['ms'] for r in kv[1]),reverse=True)[:12]:
 print(k,'n',len(rs),'total',round(sum(r['ms'] for r in rs),2),'median',round(statistics.median(r['ms'] for r in rs),2),'max',round(max(r['ms'] for r in rs),2),'stage_totals',dict((n,round(sum(r['stages_ms'].get(n,0) for r in rs),2)) for n in sorted(set(n for r in rs for n in r['stages_ms']))))
print('largest',json.dumps(sorted(rows,key=lambda r:r['ms'],reverse=True)[:5],indent=2))
json.dump({'scope':'Intrusive WFI stage trace; cumulative GPU busy time, not wall time or FPS. Complete batches recovered from possibly unclosed JSON.','passes':rows},open(sys.argv[2],'w'),indent=2)
