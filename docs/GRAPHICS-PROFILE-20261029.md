# Unified DRM follow-up: 2026-10-29

State: PARTIAL. No new performance fix or sustained 60-FPS acceptance is claimed.
The owner requested measurement of the current shell, retaining its existing
experimental cache plugin. These results must not replace the stock-shell
35.5-FPS result in [UNIFIED_DRM.md](UNIFIED_DRM.md).

## Device and test conditions

VERIFIED_DEVICE: unified2, one MSM card/render device, hardware FD305,
1280×800 at 59.999 Hz. GPU 450 MHz, CPU 1.1904 GHz and requested GPU AXI
266.67 MHz during load. GPU runtime power was temporarily held on for a
startup control; this is not a production power-management fix. Existing
private Qt/Mesa and the restored LOCAL-diverted shell cache plugin were loaded.
No shell plugin or animation change was made after the owner requested keeping
this variant. Ten scripted drawer open/close cycles were used per trace.

A first startup had black display and unresponsive SSH exec channels while
ping/authentication continued. After physical reset, pstore was empty. A second
startup with a pre-opened diagnostic logger completed. It observed cold page
I/O waits in KWin/ksplash and WCN36xx BMPS response waits; this does not prove
the cause of the first failure or establish a GPU power-management fix.

## Measurements

- Atomic trace: 51.26 active presentation events/s; p50 16.670 ms,
  p95 33.342 ms, p99 33.438 ms; 15.94% intervals above 25 ms.
- Atomic tail preparation: median 0.089 ms, p95 0.137 ms, maximum 0.187 ms.
  Flush-to-presentation median 2.105 ms, p95 16.226 ms includes scanout waiting.
- Scheduler trace: 125 intervals between 25 and 75 ms; 112 had at least one
  submitted GPU job not yet retired 0.4 ms before the next nominal VBlank.
  This is correlation, not exclusive attribution to a particular render pass.
- Wake-to-run p95: shell main 0.069 ms, KWin 0.129 ms, active render threads
  0.110/0.313 ms. Rare larger outliers still exist.
- PRIME imports in KWin: 1,743 calls; median 0.015 ms, p95 0.030 ms.
- Active QSG thread WAIT_FENCE: median wall time 4.247 ms versus 0.047 ms
  on CPU. Waiting must not be described as CPU rendering.
- The same thread made 49,282 GEM_MADVISE calls (374.88 ms total wall time)
  and 1,384 GPU submit ioctls (393.04 ms total), over 22 seconds. They are
  measurable overheads, but do not reproduce the old 6-ms-per-frame import.
- User CPU samples primarily show normal scene processing and Mesa command/
  resource preparation, not a single software rasterizer hotspot. A separate
  all-mode CPU sample includes printk work; its sampled share is insufficient
  to explain the whole deficit.

GPU submit-to-retire and retirement-gap estimates include queueing/notification
latency. A3xx emits zero hardware start/end fields in these traces. They cannot
identify SP, TP, RB or GMEM execution time independently.

## Controlled offscreen reproduction

Same installed private Mesa, FD305, 1280×800, no compositor window or swap,
40 measured frames per case, `glFinish`, rendered pixel validation. Numbers
include driver and completion-wait overhead; they are not hardware timestamps.

| Target / shader, blended layers | 1 layer | 2 layers | 4 layers |
|---|---:|---:|---:|
| Linear / sampled texture | 9.00 ms | 11.43 ms | 16.35 ms |
| Linear / nearest texture | 8.70 ms | 11.16 ms | 16.07 ms |
| Linear / constant color | 7.41 ms | 9.71 ms | 14.37 ms |
| Linear / sampled, reordering enabled | 9.02 ms | 11.42 ms | 16.30 ms |
| Private tiled / sampled texture | 7.65 ms | 10.03 ms | 14.91 ms |
| Linear 640×400 / sampled texture | 2.15 ms | 2.83 ms | 4.20 ms |

Thus substantial cost exists independently of KWin, overlays and presentation
scheduling; it scales closely with pixel count. Reordering and nearest sampling
alone do not resolve it. Private target tiling saves about 1.4 ms here but is
not a safe replacement for the required interoperable linear Wayland buffer.
The existing shared-image layout safeguard remains necessary. These sequential
short tests do not establish isolated-cause confidence intervals.

## Next measurement

Build the bounded A305 counter diagnostic for the exact running unified2
release. Kernel symbols are rebuilt normally from the retained patched source
and saved config; no forced vermagic or relaxed modpost checks. The diagnostic
has not been loaded. After inspecting the build, measure validated SP/TP/RB
stall and memory counters alongside the same gestures, with restoration of
owned selectors. Counter definitions are available in Mesa's retained
`src/freedreno/registers/adreno/a3xx.xml`; earlier device limitations in the
counter interpretations still apply. A zero/uncalibrated transaction counter
must not be used to infer average memory latency.

Private raw traces and scripts: `.work/device-evidence/20261029-next/`.
Device originals: `/var/tmp/t531-unified-20261029-*`.
Build status/log: `.work/gpu-counter-build/`. The tested session was accepted;
this does not promote its production boot or claim cold-boot reliability.

## Bounded hardware counters, same shell variant

The exact-release counter module was built, loaded only for bounded samples,
and unloaded. Readback verified all 24 owned selector registers and both VBIF
configuration registers returned to zero. No operating clocks or voltages were changed.

Two drawer runs measured 51.58 and 51.24 presentation events/s. In the expanded
run, counter totals divided by GPU busy cycles were: RB active 75.36%,
RB stalled by MARB 58.70%, SP ALU active 25.71%, SP waiting for TP 15.62%,
PC working 1.79%. These are overlapping hardware event counts, not an exclusive
wall-time partition. VBIF RAM-wait events were 1.11% of GPU busy counts;
clock domains/event definitions differ, so this is not 1.11% of frame time
or proof that all memory accesses are fast. TP latency transaction counts
remained zero and were not used to calculate latency. Fragment half-ALU
instructions were zero; the Mesa shader-capability path restricts automatic
FP16 lowering to later generations. FP16 was not enabled experimentally.

Independent offscreen runs reproduced the RB/MARB pressure. GMEM: RB active
96.75%, MARB stall 36.96%, four blended texture layers 16.44 ms. Sysmem:
RB active 99.94%, MARB stall 80.00%, four layers 42.31 ms. This rejects bypassing
GMEM as an optimization, but does not prove a driver bug solely from stalls.

A private paired Mesa cross-build tests one concrete BSP difference:
`PACKER_TIMER_ENABLE` in the A305B GMEM resolve path. Samsung enables it in
its GMEM context-save resolve; Mesa's corresponding ordinary resolve omits it.
The candidate is [kept separately](../patches/candidates/mesa/0001-a305b-resolve-packer-timer.patch)
and is not part of the production patch series. Context-save behavior is not
proof of equivalent normal-frame performance. Pixel checks, unchanged control
behavior and a paired performance comparison remain required. The cross-build
uses native host tools and 16 ARM compiler jobs, not QEMU compilation.

New raw device captures: `/var/tmp/t531-unified-20261029-counters*` and
`/var/tmp/t531-unified-20261029-counter-offscreen/`; host copies remain private
alongside the previous traces. Candidate build monitor: `.work/mesa-rb-build/`.

## Follow-up controls: no demonstrated GUI improvement

The resolve `PACKER_TIMER_ENABLE` candidate passed pixel checks but was rejected
as a performance fix: twelve short interleaved runs, with submission traces
excluding foreign GPU jobs, gave median run means of 16.42055 ms for control
and 16.42520 ms for candidate. It remains outside the production series.

The separate fragment-mediump candidate enables existing half-precision compiler
support only on A305B fragment shaders; it does not lower highp precision.
Arithmetic, branches, sqrt, loops, highp cancellation, texture formats and shared
KMS images passed bounded pixel checks. A four-layer arithmetic-heavy synthetic
scene improved from 65.7–66.1 to 38.3–38.4 ms. This is not a GUI result.

An authorized, automatically reverted plasmashell-only trial retained the same
cache plugin, Qt, KWin, kernel and display settings. Visible output was confirmed
correct by the owner. Presentation rate was 50.73/s versus 51.51/s immediately
before the trial; p95 remained approximately 33.35 ms. Hardware counters recorded
zero fragment half-ALU instructions during the GUI workload. Consequently this
candidate has not established a GUI benefit and is not a production fix. Original
Plasma libraries were restored automatically and verified in process mappings.

A subsequent control held CPU and GPU minimum frequencies at their existing
stock maxima (1,190,400 kHz and 450 MHz) for one drawer measurement. It produced
51.21 presentation events/s, p95 33.386 ms and 16.42% of intervals above 25 ms.
This does not explain the deficit through frequency ramping. The previous minima
(300,000 kHz and 19 MHz) were restored. This is a diagnostic constraint, not an
argument for permanently pinning clocks.

Command-buffer snapshots are collected separately from frame-time measurements:
the debugfs RD producer can block while data is read. The narrow decoder counts
emitted commands including conditional tile paths, not executed pixels or GPU
wall time. Initial snapshots show small offscreen passes with color and depth
stores; their presence alone does not establish that these dominate GUI cost.
A larger bounded capture is required before attributing the remaining deficit.

## Expanded command census and reordering regression

A bounded RD snapshot captured 192 complete submissions (14,517,272 bytes), with
no missing indirect buffers in the decoder. Large repeated QSG submissions have
48 emitted color-resolve tiles and zero depth resolves. One recurring submission
has 245 render packets and 352 WAIT_FOR_IDLE packets after IB expansion. In the
active QSG thread, 21,888 waits precede CP_LOAD_STATE; 19,512 of these load direct
vertex-shader constants. This identifies a concrete synchronization path for
investigation, not its measured execution cost. Conditional tile execution must
be accounted for before interpreting these as actual hardware event counts.
The existing wait cannot simply be deleted: constant writes have pipeline
hazards. Investigate redundant state uploads and correct state lifetime first.

Removing only `inorder` from plasmashell's existing `FD_MESA_DEBUG` passed the
isolated queued-texture checks but failed in the actual GUI. QSGRenderThread
aborted at `A3XX_RB_MRT_BUF_INFO_COLOR_BUF_PITCH` with `val & 0x1f` nonzero.
The automatic return restored `inorder,ttile`, original Mesa and a running shell;
KWin and the kernel remained unchanged. The attempted presentation measurements
are invalid because shell restarts overlapped them. No FPS improvement is claimed.
The systemd core was truncated and did not provide a usable symbolized stack.

A separate diagnostic-only incremental Mesa build records MRT layout facts
immediately before this existing assertion, retaining the assertion, memory
initialization and synchronization. It removes the unrelated FP16 candidate
from its build workspace. No diagnostic Mesa has been deployed. Build monitor:
`.work/mesa-pitch-build/{status,build.log}`. Older completed control/candidate
artifacts remain immutable. This is not yet a corrective driver patch.

The invalid-pitch diagnostic build completed successfully with native ARM
cross-compilation. A bounded, automatically reverted private-library trial was
started solely to collect the failed layout values; frame timing from such a
failure run is not a performance comparison.

The diagnostic reproduced the failure with `bin_w=0`, `stride=1`, width 80,
height 1, bind 0x10 (`PIPE_BIND_VERTEX_BUFFER`), cpp 1 and row pitch 1. Source
inspection ties this to buffer layouts (`fdl_layout_buffer`) having no image
row pitch, while A3xx format capabilities advertise buffer render targets.
Reordered busy DISCARD_RANGE uploads consult `is_renderable` and may therefore
choose an invalid staging framebuffer blit. The retained 3D copy path itself
already documents that buffer render targets are unsupported.

[Candidate 0003](../patches/candidates/mesa/0003-a3xx-buffer-render-target.patch)
rejects PIPE_BUFFER render-target/depth-stencil capability on A3xx. This uses the
existing synchronized buffer mapping/copy behavior rather than emitting invalid
MRT state; it does not remove assertions or cache synchronization. The incremental
build passed. A separate device test runs pixel checks and a bounded real-shell
reordering trial, checks PID/library/environment before and after measurement,
and restores the original shell with an independent 240-second return timer.
Status/log: `/var/lib/t531/mesa-reorder-20261029/{status,test.log}`.
Until that result is collected, correctness and performance remain unverified;
this candidate is not included in the production series.

## Isolating constant-update cost

The corrected buffer-capability candidate completed its real-shell reordering
trial without the preceding MRT-pitch abort. It did not improve presentation:
50.617/s, p95 33.362 ms, p99 33.445 ms, 17.43% intervals above 25 ms. Original
libraries and `inorder,ttile` were verified restored. This is a bounded regression
check, not complete hardware validation or grounds for promoting the candidate.

`fd2d-bench` now optionally repeats draws (`FD2D_DRAW_REPEATS`, 1–64) and changes
a live vertex uniform between draws (`FD2D_UNIFORM_UPDATES`). The shift affects
only texture coordinates; the reference blue channel remains spatially constant.
Default behavior is unchanged. A paired static/changing/changing/static test
uses 64 blended draws at 32×32 and 1280×800 on the installed original Mesa,
with the same shaders, geometry and pixel work for each size. It records kernel
submission/retirement/frequency events to identify foreign GPU activity. CPU/GPU
minimum rates are temporarily set to their existing stock maxima to avoid ramp
confounding and restored by EXIT trap; the systemd job has a 180-second limit.

These glFinish wall times include API/driver overhead; they are not hardware
GPU timestamps. Their difference tests aggregate uniform-update overhead before
attributing frame-budget loss specifically to WAIT_FOR_IDLE. No synchronization
commands are removed. Device job status/log:
`/var/lib/t531/mesa-state-cost-20261029/{status,test.log}`;
raw results: `/var/tmp/t531-state-cost-20261029/`.

### Constant-update result

The paired state-cost test completed and restored the clock minima. At 32×32,
mean run times were 0.7698 ms static versus 0.9675 ms changing (difference
0.1977 ms). Trace startup missed the early small-buffer cases, so absence of
foreign GPU activity cannot be established for them.

At 1280×800, changing runs took 166.3184 and 165.7477 ms. The final static run
took 163.6833 ms; all three had no overlapping foreign GPU submissions and
recorded only 450 MHz frequency events. The first static run overlapped seven
QSG and six KWin submissions and is excluded from the clean comparison. The
clean difference is approximately 2.350 ms for 64 fullscreen blended draws.
This is a synthetic 64-layer workload, not a 6 FPS GUI result. It includes API
and driver overhead and cannot be assigned exclusively to hardware waits.

The small-buffer result and existing pixel-scaling controls do not support
constant uploads as the dominant explanation. Conversely, a tile renderer
replays draw commands per tile, so simply multiplying a whole-screen per-draw
cost by the expanded command count would double-count tile coverage.

An additional short pixel-path control compares clear-only and four/eight layers
of constant-color versus sampled-texture output at fixed stock CPU/GPU maxima.
It preserves framebuffer output and pixel checks, including the clear-only zero
reference. No color-store, cache operation or synchronization is discarded.

### Pixel-path result and interpretation limits

All ten fixed-rate pixel controls passed the blue-channel check, had no
intersecting foreign GPU submissions, and recorded only 450 MHz GPU events.
Two-run mean times (1280×800, original installed Mesa, no GUI restart):

| Workload | Run 1 | Run 2 |
| --- | ---: | ---: |
| Clear-only with valid output | 5.106 ms | 5.033 ms |
| Four constant-color blended layers | 14.480 ms | 14.473 ms |
| Four textured blended layers | 16.522 ms | 16.514 ms |
| Eight constant-color blended layers | 23.699 ms | 23.644 ms |
| Eight textured blended layers | 26.293 ms | 26.317 ms |

The four-to-eight-layer increment is about 2.30 ms per full-screen solid layer
and 2.45 ms per textured layer. Texture removal saves about 2.04 ms at four
layers, while substantial cost remains with a trivial fragment shader. Earlier
paired blend-on/off runs showed similar GMEM times, so alpha blending arithmetic
alone is not established as the cause. These controls and the RB counters point
to the pixel/color path rather than CPU imports or heavy shader arithmetic, but
do not prove the exact physical bandwidth limit or identify a faulty register.

A separate routing check found clear-only output around 5.03–5.04 ms by default,
4.32–5.03 ms with forced GMEM, and 2.67–2.92 ms with forced sysmem. This narrow
case can benefit from bypass; it contradicts interpreting the default clear-only
time as pure resolve cost. Source inspection finds the older fallback heuristic
rejects bypass whenever `batch->cleared` is nonzero. This may be suboptimal for
clear-only passes, but globally forcing sysmem is already rejected by the
four-layer test (approximately 42 ms versus 16.4 ms). A correct optimization
would need to distinguish clear-only/sparse passes and demonstrate that such
passes materially contribute to the actual shell workload before promotion.

Clock minima were restored to 19 MHz GPU and 300 MHz CPU. KWin PID 766 and
plasmashell PID 7241 remained running. These results do not establish 60 FPS.

## Bounded clear-only batch census preparation

Before changing routing heuristics, a private diagnostic adds a count of draws
emitted by the full-clear helper to each live batch, ignoring classification
across a flush. An opt-in atomic counter limits diagnostics to 4096 batches per
process. It records dimensions, draw/clear counts and buffer/reason masks without
changing routing, framebuffer output or synchronization. Diagnostic timings are
not performance measurements. The private source patch is outside the production
series; build status/log is `.work/mesa-clear-census-build/{status,build.log}`.
No shell-specific logic is introduced. The running device has not been changed
by this build. Candidate 0003 remains present in the private build workspace;
the intended census uses the original `inorder,ttile` flags for comparability.

### Clear census device result and warm-up evidence

The bounded real-shell census completed and original libraries were verified
restored (plasmashell PID 8653, original private Gallium, `inorder,ttile`, no
census environment). KWin was not restarted. The gesture window contains 3427
batch records: 4 only-full-clear-helper batches, 1923 mixed clear/draw batches,
954 other draw batches and 546 empty fence batches. Empty batches are recorded
before their later automatic promotion to nondraw and must not be counted as
pixel processing. All four clear-only batches also clear depth/stencil (mask
0x7); a color-clear-only routing optimization is not supported as a material
steady-state GUI fix by this capture.

Journal monotonic timestamps matched to gesture marks show large 2048-wide
framebuffer batches concentrated in cycles 1–3 (65, 215, 330). None occurred in
cycles 4–8; cycle 9 had five and cycle 10 none. This supports warm-up-related
initial work, not a continuous whole-atlas bottleneck. Texture dimensions alone
are not transferred bytes: a private follow-up diagnostic logs actual source
and destination blit rectangles and formats, bounded to 4096 lines and with no
routing or synchronization changes. Build status/log:
`.work/mesa-blit-census-build/{status,build.log}`. It has not been deployed.

The owner observed initial drawer stutter and later smoother cycles. This is
consistent with the warm-up distribution; instrumented logging affects timing,
so neither this observation nor the census establishes production FPS.

### Blit rectangles and GMEM layout candidate

The follow-up device trial completed and restored original Mesa (shell PID 9228).
It recorded 952 copies covering 264146 destination pixels in total, including
615 atlas-sized destination resources. Common boxes were 18×1, 1×16 and 16×16.
Thus large atlas allocation sizes do not indicate continuous whole-atlas copies;
this capture does not support that as the steady-state bottleneck.

Source inspection found a bounded driver optimization candidate in GMEM tile
selection: the alternating-axis heuristic plus a single neighbor adjustment can
miss a layout with fewer aligned actual tiles. For a 1280×800 RGBA+packed-depth
case in 128 KiB, its 160×96 tiles require 8×9=72 tiles; legal 256×64 tiles require
5×13=65. This changes neither attachment formats nor the memory capacity limit.

[Candidate 0004](../patches/candidates/mesa/0004-a3xx-minimize-gmem-tiles.patch)
searches legal column counts and binary-searches the smallest fitting row count,
using the existing alignment/size validation. It keeps the original shape on
ties and is restricted to A3xx. Allocation remains cached by the existing GMEM
key. It does not remove memory clears, stores, synchronization or correctness
checks. Hardware binning behavior and pixel correctness still require device
checks before interpreting any performance result. Private diagnostic census
changes are removed from this build; buffer-capability candidate 0003 remains.
Build status/log: `.work/mesa-tile-build/{status,build.log}`.

Candidate 0004 built successfully. A bounded device job now runs format/shared
pixel checks (including 1023×769), a depth-tested/discarded-depth offscreen ABBA
comparison, warmed original-shell measurements, then warmed candidate-shell
measurements and automatic library restoration. The depth benchmark preserves
LEQUAL depth testing and color checks, discarding only transient depth/stencil
before finishing, as in the Qt window path. CPU/GPU minimum frequencies are
fixed to stock maxima only inside the offscreen comparison and restored before
GUI profiling. Runtime status/log:
`/var/lib/t531/mesa-tile-20261029/{status,test.log}`. The shell candidate has an
independent 240-second return timer; the parent diagnostic job is limited to
420 seconds. No kernel, KWin, Wi-Fi or shell plugin changes are part of this test.
Results are pending; a lower tile count is not a 60 FPS claim.

### Candidate 0004 device comparison result (collected 2026-10-30)

The pixel checks and bounded shell trial completed. The depth-tested offscreen
ABBA means were 17.0463 / 15.5035 / 15.5609 / 17.0272 ms (control / candidate /
candidate / control), approximately 8.8% faster for this synthetic workload.
Those runs did not collect an independent foreign-submit trace, so they are
paired evidence rather than complete isolation of GPU execution cost.

The warmed real-shell comparison showed no material improvement: presentation
rate 51.171 → 51.292/s; p95 33.386 → 33.341 ms; p99 33.419 → 50.003 ms;
intervals above 25 ms 16.30% → 15.48%. One pair cannot establish a p99 regression
or a reliable GUI gain. A synthetic case now below 16.67 ms is not proof that
the actual interface meets the frame budget. Candidate 0004 remains unpromoted.

Original Mesa and `inorder,ttile` were verified in running shell PID 9984 after
automatic return. Clock minima were 19 MHz GPU / 300 MHz CPU. No kernel or KWin
change occurred. Private result archive: `tile-result.tar.gz` in the existing
20261029-next evidence directory.

## Warmed presentation critical-path follow-up, 2026-10-30

Reanalysis of the saved tile-control traces separates GPU submission owners.
Retirement-gap service estimates (not hardware execution timestamps) for the
original control show 91 large KWin jobs, median 12.596 ms / p95 14.918 ms,
versus 736 large QSG jobs, median 8.032 ms / p95 21.867 ms. During 534 short
presentation intervals (10–25 ms), estimated overlap averages 9.26 ms QSG and
0.70 ms KWin. During 104 long intervals (25–55 ms), it averages 24.22 ms QSG
and 6.21 ms KWin. The candidate shows the same pattern. This association does
not prove that changing plane assignment causes the extra composition.

The next bounded read-only capture records warmed GPU/atomic/fence events,
actual vblank events and 20 ms DRM plane-state samples. It changes no kernel,
Mesa, KWin settings or clock constraints. Plane reads may perturb timing and
are sampling observations, not an exact atomic-commit history. Existing kernel
has no kprobe_events interface, so the diagnostic does not add a kernel or
pretend to obtain exact per-commit plane probes. Struct offsets were compiled
from the matching source/config only for investigation; no module was loaded.
The installed MSM module SHA256 matches the retained current artifact.

Status/log: `/var/lib/t531/pipeline-critical-20261030/{status,test.log}`;
raw output `/var/tmp/t531-pipeline-critical-20261030*`.
