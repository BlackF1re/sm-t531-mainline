# Graphics-path investigation, 2026-11-01

The remaining presentation deficit is reproduced on unified2. This investigation
does not change desktop effects, animation durations, the cache plugin, Qt,
Mesa routing, kernel, clocks or voltages. No corrective driver patch is promoted.
The exact driver/hardware mechanism behind the RB/MARB pressure remains open.

## Recovered work and its applicability

Read alongside `GRAPHICS-PROFILE-20261029.md`, `UNIFIED_DRM.md`,
`GRAPHICS-BOTTLENECK.md` and `MEMORY-BUS.md`. The October 15 Phosh/split
measurements describe an older stack. The October 29–30 unified/cache-plugin
measurements are the relevant comparison for today's configuration.
Private sources, raw traces, ABBA tests, command decoders and build workspaces
survive under `.work/device-evidence/20261029-next/`, `.work/diagnostics/`,
`.work/pipeline-critical-20261030/` and `.work/mesa-*-build/`.

The original outstanding next step was the warmed presentation-critical trace,
not another unvalidated Mesa speedup. Its saved result has 112 late intervals,
none flushed by the nominal deadline, and an invariant sampled plane mask 3.
Plane sampling perturbs timing and does not prove every commit's assignment.
The new recording avoids this sampler.

## Fresh measurements

One lossless 22-second atomic/GPU/fence/VBlank recording and ten automated drawer
cycles give 50.260 presentation events/s, p95 33.371 ms and 17.55% of measured
burst intervals above 25 ms. Raw data:
`/var/tmp/t531-critical-20261101/` on the device and
`.work/device-evidence/20261101-critical/` on the host.

`graphics-atomic-20261101.json` reports 670 complete commits: tail preparation
p50 0.093 / p95 0.135 / max 0.193 ms. Flush-to-presentation p50 1.699 / p95
16.091 ms includes waiting for scanout. There are 103 drm_sched fence waits,
p50 4.814 / p95 13.871 / max 21.469 ms. This is waiting, not CPU rendering.

`graphics-critical-20261101.json` separates 545 short and 115 long intervals
(10–60 ms; idle gaps excluded). At previous presentation + 16.667 - 0.4 ms,
107 of 115 long intervals have submitted, unretired GPU jobs; 98 have QSG jobs
and 28 KWin jobs, with overlap. Zero long intervals have a flush by that deadline.
Short intervals have 542/545 timely flushes. Their pending-job count is also
substantial (362/545), so an outstanding job alone is not proof of the blocking
framebuffer's owner: the producer can already be rendering the next frame.

Retirement-gap service estimates per interval are QSG 9.04 / KWin 0.70 ms in
short intervals versus QSG 24.70 / KWin 5.73 ms in long intervals. These include
notification/scheduling and cannot be interpreted as hardware execution time
or used to add up an exclusive per-frame critical path. VBlank median is
16.670 ms; p95 16.766 ms. The panel is not running intentionally at 30 Hz.

A separate bounded counter run reproduces RB active 75.44%, RB MARB stall
59.02%, SP ALU active 25.60%, SP waiting for TP 16.13%, PC working 1.86%,
VBIF RAM-wait events 1.07%, each divided by GPU busy counts. These overlap and
some counters have different clock domains; they are not a wall-time partition.
TP latency transactions remain zero, invalidating average-latency calculations.
See `graphics-counters-20261101.json`. Matching-release module unloaded;
24 owned selectors and two VBIF controls read back zero. No fault/underrun was
detected by the atomic profiler. No permanent counter instrumentation remains.

## What actually contributes

| Contributor | Evidence | Status |
| --- | --- | --- |
| Cross-device import/allocation | Old split imports around 6.2 ms; unified around 0.015–0.030 ms, large allocation collapse | Real historical cause, removed from current normal topology |
| Pixel/color processing and local memory traffic | Independent 1280×800 offscreen four solid layers 14.48 ms, textured 16.52 ms; eight 23.67/26.31 ms; quarter pixel count near quarter time; recurring RB/MARB pressure | Confirmed substantial cost outside the desktop/presentation path; exact hardware/driver subcause unresolved |
| Additional composition and serialization of two producers | QSG and KWin share ring0; long intervals associate with more work from both; scheduler fence waits and missing timely flush | Confirmed workload and contention contributor; exact fence-to-buffer causal chain still needed |
| Linear interoperable output / tile stores and pass overhead | Private tiled output saves about 1.4 ms; legal tile-selection candidate improves depth synthetic case 8.8% | Measured costs; these candidates did not demonstrate GUI improvement |

The table distinguishes a measured cost from a driver defect. Rendering several
layers on finite hardware is not by itself proof of misconfiguration. Stock
Android's reported smoothness is not a matched rendering-workload measurement:
we do not yet have an equal-workload proprietary-driver comparison that assigns
the remaining difference exclusively to Freedreno.

## Exclusions and rejected shortcuts

- Current CPU imports and atomic register preparation are too small to explain
  the recurring lost refresh interval. Scheduler wake delays were sub-ms in
  the retained traces; fence wall time must not be counted as CPU shader work.
- Active core/CPU/DDR/AXI rates were physically cross-checked in retained work.
  Fixed stock CPU/GPU maxima did not resolve the GUI deficit. This does not
  measure today's physical OCMEM frequency or all power transitions.
- Four-layer sysmem bypass was approximately 42 ms versus 16.4 ms GMEM.
  Globally bypassing GMEM worsens this workload.
- Packer-timer candidate: no paired gain. Fragment FP16: large synthetic gain,
  no GUI half instructions and no GUI improvement. Constant updates: small
  compared with pixel cost. Clear-only batches: only four among 3427 records.
- Large atlas resource dimensions were misleading: 952 recorded copies covered
  only 264146 destination pixels, not repeated full-atlas copies.
- Reordering without buffer capability correction triggers an actual invalid
  buffer render-target pitch. Candidate 0003 fixes the tested capability error;
  its bounded GUI trial showed no speedup. Removing waits/assertions is unsafe.
- The seven MDP SMP blocks cannot accept three fullscreen RGBA planes requiring
  nine. This is a genuine overlay resource limit, not justification to disable
  rejection checks or assume all content can be scanned out directly.

## Remaining discriminating investigations

1. **Local color/GMEM path.** Determine whether MARB stalls arise primarily in
   raster writes, depth traffic, tile load/store or resolve. Match counters to
   controlled passes with the same attachment layouts and valid full output.
   The existing four-layer solid test already eliminates complex shaders as a
   sufficient explanation. Do not equate low VBIF RAM-wait counts with healthy
   OCMEM bandwidth.
2. **OCMEM actual rate and configuration.** The live idle ICC snapshot requests
   3.6 GB/s maximum, not a physical-clock reading. The retained BSP's debug mux
   lists GPU AXI/core but no OCMEM selector. Identify a supported observable
   before adding a guessed mux. Compare under-load ICC/RPM aggregation and
   OCMEM region/interleave configuration with the exact BSP. No evidence yet
   warrants raising an operating rate or claiming a stuck clock.
3. **Buffer ownership and fence critical path.** Correlate each plane's actual
   framebuffer and readiness fence with the producer submission and atomic
   deadline. Current GPU IDs and sampled plane masks are insufficient. This
   separates late producer completion, avoidable driver serialization and
   compositor scheduling without changing the desktop's visual workload.
4. **Stability independently of FPS.** GPU runtime remains held on by the old
   diagnostic drop-in. Long PM/recovery validation remains incomplete. A short
   fault-free run does not establish a flawless graphics stack.

A new reusable `tools/summarize-presentation-critical.py` reproduces the current
interval correlation; three host tests cover missing/lost evidence and a known
pending-job timeline. Raw decoder counts remain emitted-command counts, not
executed pixels. The next corrective patch should be selected from a causal
control above, with pixel validation, paired timing and independent restoration.

## Additional pixel-path isolation

See [the new controlled report](GRAPHICS-PIXEL-ISOLATION-20261101.md).
Halving target bytes, disabling blending and reducing the constant fragment
shader from four MOVs to one leave the incremental cost near 2.30 ms per
fullscreen layer. This narrows the synthetic bottleneck, but does not identify
a specific faulty register or prove a physical OCMEM bandwidth limit. Requested
lower core frequencies did not take effect physically; the frequency sweep is
invalid as a causal frequency experiment.
