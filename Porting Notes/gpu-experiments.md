# GPU performance: results worth preserving

Remaining driver/hardware root cause is **UNKNOWN**. Do not repeat rejected
controls as established fixes. This baseline uses one MSM DRM device with
Adreno305B/MDP5; the old expensive cross-device PRIME path is already fixed.
Active GPU450MHz,AXI266.67MHz and DDR533.33MHz were independently measured;
correct active clocks do not prove optimal contention or sleep policy.

## Findings and rejected explanations

| Control / observation | Result | Interpretation |
|---|---|---|
| Native fullscreen direct scanout | ~59.993 presentations/s | Scanout can sustain 60 Hz; not desktop composition FPS |
| Warm unified drawer | ~50–51/s, 16.67/33.35-ms intervals | Repeated missed deadlines remain |
| Stage trace, BGRA8+D24S8, 1280×800/72 tiles | Up to 30.22 ms busy/pass | Intrusive diagnostic, not production latency |
| Largest separated pass | 26.77 ms, 21.62 in draw IBs | State/clears/shaders/pixels/stalls, not ALU alone |
| 91-draw pass | 23.301 ms =19.183 draw +3.477 stores +0.641 other | Removing every store would not meet 16.67 ms under this instrumentation |
| Second store-bracketed pass | 23.848 ms; draw18.380, stores5.122 | Same limit; no tile loads in these examples |
| FP32→FP16 color export | Solid16-layer ~41.6→24.1 ms | Real synthetic contributor; whole-stack A/B/A 50.100/51.083/49.420/s does not solve GUI pacing |
| RGB565 target | Lower intercept, similar per-layer slope | Not proof all memory traffic is cheap |
| No blending / 4 full MOV→1 | Per-layer slope largely unchanged | Does not isolate a final ALU/blend/DDR defect |
| Scissor-aware IB culling | Sparse synthetic ~31–32→24–27 ms; GUI50.763/49.687/50.329 | No GUI improvement; not promoted |
| Compact private image allocation | −19.15% measured target allocation; same ~14.9-ms render | Main correctness/memory improvement, not 60-FPS fix |
| Tile-layout candidate0004 | Offscreen17.05→15.50ms; GUI51.171→51.292/s, p99 worsened in one pair | Not promoted; no reliable GUI gain |
| Local QoS Bypass | ~34.05 vs34.37/s on older stack | No demonstrated gain |
| Requested core/AXI rate sweeps | Physical clocks did not change | Not a valid frequency-isolation experiment |
| CPU tile packing/staging | Some CPU preparation improved; presentation did not | Do not promote as throughput solution |

Earlier split-stack tiled-vs-linear four-layer AB-A: 25.55→15.91→25.41 ms;
texture path is expensive, but that stack differs from current unified/cache.
Clear folding executed40times but GUI ABA50.877/50.619/50.554/s and submit/
retire timing did not improve; it remained disabled. TWO_QUADS vs FOUR_QUADS
fragment thread size and exponent-one shader controls gave no reliable GUI
solution. Per-draw full-state IB and KWin tiling candidates were rejected.
Coverage-reduction
on the active desktop visibly corrupted pixels and was stopped; future
pixel-changing diagnostics must be offscreen. Scissor culling compares complete
images/query behavior rather than assuming preserved coverage is sufficient.

## Correlation and measurement traps

* Nonintrusive busy counter is stationary with no pending work and follows
  submit/retire: real GPU activity consumes many missed intervals.
* 22-s nonintrusive batch link: 1352 uniquely linked jobs, 50.312 events/s;
  1280×800/91-draw jobs median service ~21.8 ms, five-draw jobs 7.845 ms.
  No 1280×1280 pass was linked in that recording. Coalescing/IRQ latency mean
  retirement service is not an exact isolated GPU-pass timestamp.
* 112 late intervals in a warmed critical trace were not flushed by nominal
  deadline. Plane-mask sampling perturbs timing and cannot prove every commit.
* RB/MARB pressure counters overlap; do not sum them as wall time or infer
  broken DDR/OCMEM solely from a high stall percentage. Unsupported zero GMEM
  counters do not establish zero traffic. HLSQ registers are unsafe to probe.
* Intrusive stage code uses PWR1/CP_REG_TO_MEM after WAIT_FOR_IDLE; conversion
  at 450 MHz is 20/9 ns per tick. Preserve complete records only. Method:
  `tools/diagnostics/a3xx-stage`; bounded counters: `tools/native-gpu-counters`.
* Use identical visible workload, warmed/cold classification, clocks, overlays,
  shell/plugin and library identities; require original/modified/original plus
  complete image validation. Presentation bursts exclude >100-ms gaps, so do
  not use their mean alone; inspect p95/p99, long stalls and process/journal health.
* Run `tools/auto-drawer.py` only with a verified visible unlocked drawer;
  screen-coordinate gestures/power-key events can target the wrong state.

## Android control

Preserved Android uses KGSL/Qualcomm GLES V@84 and SurfaceFlinger/HWC. One home
screen hands wallpaper RGB888, launcher/statusbar RGBA8888 to MDP5: not proof
all animations use the same composition. Identical offscreen shader/FBO tests:
1280×800, no depth, 5 warmups/40 glFinish samples; four solid/sample layers
6.3684/8.1979 ms, sixteen 20.2741/26.2982 ms. Only one blue pixel was checked;
JNI vs C, pbuffer vs surfaceless and compiler/layout differ. Linux min-rate
controls do not prove Android minimum rates were pinned. Android DSI pixel/byte
76.333/57.250 MHz vs historical Linux74.240/55.680 is a separate timing issue,
not an explanation of offscreen cost. No Android internal layout/stream capture.

## Reproduction boundary

Only accepted fixes are selected in `patches/mesa`; rejected candidate source
is available in Git`43648a2`. Historical report snapshots remain retrievable
from Git`e865aba`, not as active test results. Preserve the workload, image
checks and attribution limits above when designing a new comparison.
