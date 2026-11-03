# Pixel pipeline isolation, 2026-11-01

The exact low-level defect causing the GUI's missed deadlines is **not yet
established**. These new controls narrow the independent pixel-processing cost;
they do not prove a faulty GMEM clock, a particular register, or an inherent
hardware limit. Read with `GRAPHICS-INVESTIGATION-20261101.md`.

## Controlled findings

Original installed Mesa, unified2, offscreen linear 1280×800, stock CPU/GPU
maxima requested, 40 measured frames after five warmups, framebuffer readback.
The unchanged constant-color fragment shader disassembles to four 32-bit MOVs
and END, with no texture instructions. Repeating fullscreen draws inside one
frame separates incremental rendering cost from fixed setup/resolve cost.

| Control | 4 layers, ms | 8 layers, ms | 16 layers, ms |
| --- | ---: | ---: | ---: |
| RGBA8888, last ABBA run | 14.3715 | 23.5801 | 42.0385 |
| RGB565, first middle run | 13.0254 | 22.2490 | 40.6922 |
| RGB565, second middle run | 13.0263 | 22.2502 | 40.6902 |
| RGBA8888, blending disabled | 14.5232 | 23.5940 | 42.0544 |
| RGBA8888, blending enabled, adjacent control | 14.4356 | 23.6204 | 42.0692 |
| RGBA8888, only red defined by fragment shader | 14.5203 | 23.6149 | 42.0863 |

The red-only shader has **one MOV and END**, verified by native disassembly;
color writes are enabled for all four channels and blending is ONE/ZERO. Its
other channels are undefined, so only red is validated. This is a diagnostic
control, not a valid substitute for the desktop shader.

The incremental cost remains approximately **2.30 ms per 1,024,000 pixels**, or
445 million pixels/s. Quarter-resolution controls give approximately 0.58 ms
per additional layer. Halving framebuffer bytes reduces largely the intercept
(about 1.4 ms at full resolution), not the per-layer slope. Removing blending
or reducing four shader MOVs to one also leaves that slope unchanged.

Consequently, expensive fragment arithmetic, texture sampling and blending are
not necessary to reproduce the large incremental cost. Simple external
framebuffer-byte bandwidth is insufficient to explain this slope. Fixed-rate
raster/color processing or its local-memory service remains a candidate;
these controls do not distinguish an architectural throughput limit from a
misconfigured local path. They also do not establish the GUI's exact overdraw.

A separate constant-output FP16-capability ABBA test shows no timing gain
(16 layers approximately 42.1 ms in both modes). Capability toggling alone does
not establish half-precision lowering for this constant shader. The earlier
real GUI FP16 test already recorded zero half instructions and no benefit.

## Hardware counter limitations

A temporary matching-release module multiplexed only the two already-tested RB
selector registers, retaining the existing SP/TP/UCHE probes. Six selector modes
were sampled around 4/8/16-layer phases. It automatically restores selectors
within 30 seconds and was unloaded afterward.

For the 16-layer constant-color phase, SP active/busy is about 0.94,
full fragment instructions/busy about 0.94, SP-to-RB quads/busy about 0.234,
and RB MARB data/busy about 0.248. Full instructions/quad is about four,
consistent with the unmodified four-MOV shader. These events overlap and do
not partition elapsed time. They cannot by themselves identify a memory stall.

Both GMEM channel read/write selector pairs returned zero under rendering.
They are unvalidated on this chip; zero is **not evidence of absent traffic**.
Likewise TP latency has zero transaction counts and cannot yield a latency.

## Rejected frequency experiment

`tools/native-memory-floor/` is a bounded diagnostic ICC consumer, built against
this exact kernel release. It requests peak 6,400,000 kB/s on the existing GPU
OCMEM path, equivalent to a 400 MHz rate request for the BSP's 16-byte bus.
It auto-releases after 120 seconds and was unloaded. This requests a stock-rate
floor; it neither measures the physical OCMEM clock nor proves delivery.

With this request held, a symmetric requested GPU-rate sweep of
450/320/200/200/320/450 MHz was recorded. BSP clock-debug measurements reported
**450 MHz GPU and 266.67 MHz GPU AXI throughout**, despite CCF/devfreq reporting
the requested lower values. DDR remained about 533.33 MHz. All measurement
registers were restored. Therefore this experiment cannot establish frequency
scaling, OCMEM saturation, or the effect of lowering core frequency. Do not
infer a stuck low GPU clock from the software values.

## Evidence and validity

Public timing rows and explicit limitations: `graphics-color-controls-20261101.json`.
Private exact sources, ARM binaries, ISA dumps, scripts and raw recordings:
`.work/gpu-memory-counter-build/`, `.work/memory-floor-build/`.
The first RGBA run began before perf was ready and lacks submit coverage;
the later format cases each have 45 expected submit events and no foreign
submissions in their phase intervals. Do not call the first run isolated.
The RGBA blend controls completed readback; the subsequent RGB565 unblended
case failed its pixel check, so the full blend/format matrix is incomplete and
that failed case is excluded. No candidate was installed into the shell.

## Fence ownership follow-up

`tools/native-fence-owner/` registers a callback on the existing submit-retired
tracepoint for 30 seconds. It copies submit ID, PID and the context/sequence of
referenced user/hardware fences into a bounded memory array; it writes no GPU
registers. The initial submit-flush attempt recorded zero rows because A3xx
does not emit that event. The corrected retirement probe recorded 1748 rows,
without overflow, and was unloaded. No kernel rebuild/reboot was required.

The warmed ten-cycle recording still gives 50.91 presentation events/s,
p95 33.346 ms and 16.94% intervals above 25 ms. Of 722 paired explicit fence
waits, only three exceed 1 ms. Those matched waits (about 1.09–1.24 ms) are
QSGRenderThread waiting on its own submissions. Many mapped atomic worker
waits on KWin fences are already signaled and last only microseconds.

This matters: the prior run's long fence waits cannot be assumed to explain
every reproduction. The ownership mapping identifies the producer of a waited
fence, but does not capture each atomic commit's framebuffer or userspace poll
waits. A coincident wait is not proof of the cause of a missed presentation.
See `graphics-fence-owners-20261101.json`; raw data and decoder are retained in
`.work/fence-owner-build/`. Physical pixel throughput remains a demonstrated
cost, but the exact driver-level cause of all GUI misses remains unresolved.

## New causal control: output precision

The previous FP16 candidate enabled fragment arithmetic support but did **not**
change A3xx fragment output lowering. In `ir3_nir.c`, the existing mediump I/O
lowering block is restricted to generation 6 and newer. Meanwhile
`a3xx/fd3_program.c` already supports half-register color output through
`A3XX_SP_FS_MRT_REG_HALF_PRECISION`.

A private diagnostic enables an output-only lowering pass by an explicit
environment flag. For the constant-color test, native ISA changes four
32-bit MOVs and an r0 color output into four 16-bit MOVs and an hr0 color output.
It preserves the target, dimensions, blend mode and draw count. Same-binary
ABBA measurements give 16-layer means of 41.53 / 23.98 / 24.23 / 41.63 ms.
The second half run overlaps nine diagnostic-dump submissions and is excluded
from isolated comparisons; the first half run has all 45 expected submits and
no foreign work. The final full run is also isolated. The incremental cost is
about 2.3 ms/layer for full output versus 1.18 ms/layer for half output.

Unlike halving target bytes or removing MOV instructions, changing the fragment
color output width nearly halves the slope. This is a causal localization of
the **synthetic** pixel bottleneck to output precision and the shader-to-color
path. It is not yet proof of the GUI's complete critical path or a production
fix. Forcing arbitrary highp outputs to half is not API-correct; the diagnostic
must not be promoted as a precision policy. The subsequent bounded GUI test
uses a separate directory and automatic restoration, and excludes depth output
from lowering. The source workspace was restored after each diagnostic build.

Raw timing/submit validation: `graphics-half-export-offscreen-20261101.json`;
exact private patch, ISA and immutable diagnostic binary:
`.work/half-export-build/`. No production Mesa library was overwritten.

The first GUI attempt did not actually lower the highp color-store semantics:
its half-instruction counter remained zero, and presentation remained near
50.8/s. Modifying variable precision after I/O lowering is insufficient for
those shaders. The attempted A/B/A recording also exceeded its bounded runtime
during shell restarts; A2 is incomplete. It is **not** a valid intervention test
of half color output. Original libraries and both temporary drop-ins were
restored and the counter module unloaded before the corrected test.

The corrected diagnostic modifies only color `store_output` I/O semantics
before the lowering pass, excluding depth and sample-mask outputs. All corrected
phases disable Mesa/Qt shader disk caches and warm ten gesture cycles. The
same temporary library is used for both flag values; half-instruction counters
must confirm that the enabled phase changes execution. Bounded shell restarts
allow SIGTERM first and finish a pending stop if necessary; an independent
rollback timer remains installed during measurement.

The corrected **plasmashell-only** A/B/A completed with the same private binary:
48.639 / 51.935 / 49.913 presentation events/s. Intervals over 25 ms were
20.75 / 13.98 / 18.60 percent; p95 remained around 33.35 ms. Half fragment
instructions were 0 / 1,567,549,604 / 0. Thus the intervention actually took
effect, unlike the earlier attempt. This is a measured contribution, but it
neither reaches 60 nor proves a single cause of all missed frames. KWin retained
its original driver during this test. Original shell libraries and temporary
drop-ins were restored afterward. See `graphics-half-export-shell-20261101.json`.

The next full-stack A/B/A changes the same output precision flag for both KWin
and plasmashell, retaining system Qt for KWin and private Qt for plasmashell.
Mesa/Qt disk caches are disabled in all phases. New process IDs, actual mapped
Mesa libraries and both process environments are validated before warming and
recording. Restarting SDDM alone leaves the user graphical services alive on
this installation; the bounded restart helper stops the graphical-session target
before restarting SDDM, so the existing compositor cannot silently remain the
control in the nominal candidate phase. All measurement starts follow fresh
process validation and ten warm gesture cycles.

The full-stack A/B/A completed: **50.100 / 51.083 / 49.420** presentation
 events/s, p95 approximately 33.35 ms in every phase. Intervals over 25 ms:
17.34 / 14.97 / 18.91 percent. Half instruction counts:
0 / 1,757,175,096 / 0. Both actual process mappings and environments were
validated. Therefore FP32 fragment color output has a measurable cost but
**does not explain the remaining failure to sustain 60**. Original libraries
were restored for both processes. See `graphics-half-export-stack-20261101.json`.

GPU-busy sampling also separates idle gaps from deadline misses. The PWR1
counter barely changes during windows with no pending GPU submissions and
approaches one busy cycle per physical clock cycle during sustained pending
work. Long presentation intervals contain substantially more GPU work than
normal intervals. This does not identify an individual hardware stage. CPU
profiling did not expose a dominant CPU-side copy or cache-maintenance hot spot.
