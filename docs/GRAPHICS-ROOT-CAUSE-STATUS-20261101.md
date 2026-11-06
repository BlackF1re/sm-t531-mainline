# Root-cause status, 2026-11-01

The exact driver/hardware root cause is **not yet established**. A measured
bottleneck is not sufficient to claim a particular cache, memory bus, register
or shader-compiler defect.

## Established observations

* The accepted unified GPU/KMS stack presents at approximately 50–51 events/s
  during the automated drawer workload. Normal intervals are 16.67 ms; missed
  intervals are commonly 33.35 ms. This is DRM presentation timing, not optical
  measurement of distinct displayed images.
* Cross-device PRIME overhead has already been removed. Old import timing was
  around 6.2 ms; unified timing is around 0.015–0.030 ms.
* Nonintrusive busy-counter sampling shows real GPU work occupying most of
  many missed intervals. Independent submit/retire alignment validates the
  counter: it is effectively stationary with no pending GPU work.
* Private, intrusive GPU stage tracing localizes expensive work to plasmashell
  render passes, including 1280x800 BGRA8 + D24S8 in 72 GMEM tiles. One capture
  reaches 30.22 ms of GPU busy time per pass. A second capture separates draw
  execution: the largest pass is 26.77 ms, of which 21.62 ms is inside draw IBs.
  The latter includes state, embedded clears, shaders, pixel processing and
  associated stalls. It is not a measurement of ALU time alone.
* FP32 fragment color output is a demonstrated contributor: forcing FP16
  reduces a constant-color 16-layer test from about 41.6 to 24.1 ms. However,
  the same intervention across both shell and compositor gives
  50.100 / 51.083 / 49.420 events/s in A/B/A, with execution counters confirming
  the intervention. Therefore that explanation alone is insufficient.
* Halving color-target storage to RGB565 reduces a mostly fixed cost, without
  materially changing the per-layer slope. Disabling blending or reducing the
  solid shader from four full MOV instructions to one also leaves that slope
  approximately unchanged. These are controlled synthetic results, not proof
  that GUI memory access is universally cheap.

## Claims the evidence does not support

* RB stall MARB is an overlapping pressure counter, not proof that DDR or OCMEM
  bandwidth is misconfigured.
* Requested core/AXI frequency sweeps did not change the measured physical
  clocks. They cannot separate shader throughput from memory throughput.
* Unsupported/zero GMEM channel counters cannot establish absence of traffic.
* The stock Android 60 FPS observation is not an identical-workload comparison.
  It does not by itself establish that Linux has a defective GPU driver.

## Method and reproducibility

`graphics-gpu-stages-20261101.json` contains stage aggregates and examples.
The private instrumentation reads PWR1 through the BSP-supported A3xx
CP_REG_TO_MEM packet and converts cycles at the verified 450 MHz physical
clock. CP_WAIT_FOR_IDLE precedes each sample. It changes synchronization and
therefore **must not be used as an FPS benchmark** or as exact production pass
latency. Complete records are recovered from a potentially unclosed trace;
missing records are not reconstructed.

The instrumentation diff and original analyzer are preserved in
[`tools/diagnostics/a3xx-stage`](../tools/diagnostics/a3xx-stage/README.md).
The aggregates above are the retained results; duplicate source snapshots and
raw captures under `.work/gpu-stage-build/` are disposable. Production libraries
were not overwritten by that historical experiment.
See also `GRAPHICS-PIXEL-ISOLATION-20261101.md` for the controlled experiments
and rejected explanations.

To name an exact root cause still requires a targeted intervention in the
remaining expensive draw work that removes deadline misses, with original /
modified / original validation. Current evidence does not justify presenting
“slow video memory”, “FP32 exports”, or “GMEM copies” as that final diagnosis.

A third diagnostic brackets tile stores explicitly. A complete 1280x800 pass
with 91 draws takes 23.301 ms: 19.183 ms in draw IBs, 3.477 ms in tile stores,
0.641 ms elsewhere. Another pass takes 23.848 ms: 18.380 ms draw, 5.122 ms
stores. Thus eliminating every measured store would still leave these draw
workloads above 16.67 ms under instrumentation. This is evidence against
explaining the entire deficit as tile writeback; it is not an extrapolation of
production FPS from an intrusive trace. No tile-load events appear in these
examples; the generic callback is bracketed only when batch->restore is set.

After the bounded stage trials, the original shell Mesa mapping was verified
again; the full-stack precision test had already restored original KWin Mesa.

## Nonintrusive batch identification and interrupted coverage diagnostic

CPU metadata links userspace batches through deferred-submit coalescing and
monotonic ioctl brackets to kernel submit/retire events. In the measured
22-second drawer capture, 1352 kernel jobs were linked uniquely. Presentation
was 50.312 events/s. Jobs containing a 1280x800, 91-draw pass had median
service about 21.8 ms; 434 five-draw jobs had median 7.845 ms. These are
retirement-derived whole-job estimates, including coalesced tiny passes and
notification latency, not exact hardware timestamps. No linked 1280x1280
pass occurred in this measurement, so earlier square-pass frequency does
not explain its missed presentations. See graphics-batch-links-20261101.json.

A following diagnostic reduced per-draw scissor coverage to separate pixel
work from command/state overhead. It visibly corrupted the active desktop.
The user reported artifacts; the experiment was stopped immediately, its
service and return timer stopped, diagnostic drop-in removed, and original
plasmashell Mesa mapping and absence of FD3_DIAG flags verified after restart.
Unified DRM remained valid at 1280x800 / 59.999 Hz. This interrupted trial
is not an accepted performance result or an optimization. Future diagnostics
that change pixels must run offscreen, not on the active desktop.

## Image-preserving command culling

Candidate 0007 omits complete, self-contained scissor groups that cannot
intersect a GMEM tile, without changing fragment coverage or precision.
Grouped offscreen ABBA checks compare 63,460,020 components byte for byte,
including true and empty occlusion queries. Sparse synthetic workloads improve
from roughly 31–32 to 24–27 ms. The grouped GUI A/B/A instead gives
50.763 / 49.687 / 50.329 presentation events/s, with p95 around 33.3 ms.
It is not promoted; original Mesa mapping was verified after rollback.
Command culling alone therefore does not solve the measured GUI bottleneck.

The query test separately exposed an undersized buffer in
fd_resource_resize(), corrected in candidate 0008. It is a correctness defect,
with no demonstrated connection to this GUI's missed frame deadlines.

An offline examination of the older RD trace finds LESS depth comparisons
rather than universally ALWAYS comparisons. Omitting depth tests or treating
the depth attachment as unused would therefore be unjustified.
