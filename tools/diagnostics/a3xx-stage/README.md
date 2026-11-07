# Historical intrusive A3xx stage trace

Preserved 2026-11-06 from `.work/gpu-stage-build/`: this patch is the exact
`.before` → `.diag` difference for fd3_context.c and freedreno_gmem.c;
`analyze.py` is the original parser, unchanged. Target: Mesa 25.0.7 and A305B.
This is research instrumentation, deliberately outside the production patch
series. It samples PWR1 with CP_REG_TO_MEM after CP_WAIT_FOR_IDLE and converts
cycles at a fixed 450 MHz (20/9 ns). It adds tile load/store trace scopes.
It alters synchronization: results are cumulative GPU busy time, **not FPS or
uninstrumented latency**. Do not use at another GPU frequency unchanged.

`python3 analyze.py TRACE.json RESULT.json` recovers only complete render passes
from a potentially unclosed trace. No missing records are reconstructed.
Accepted aggregates and limitations live in
[GPU experiments](../../../Porting%20Notes/gpu-experiments.md); raw traces are not duplicated here.
Old hardcoded build/deploy scripts and full Mesa source snapshots are omitted.
