# A3xx private texture allocation optimization

Candidate 0005 changes the Freedreno A3xx layout allocator, not the desktop.
For a private single-level, single-layer, non-MSAA 2D color tiled image, retain
4-row alignment without rounding its height to a power of two. Arrays, cubes,
mipmapped images, depth/stencil and MSAA retain their previous layout rules.
Externally shared/scanout images retain the existing linear-layout safeguard.

The driver currently pads 1280×800 to 1280×1024. The candidate uses 800 rows.
No valid pixels, stores, clears, cache operations or synchronization are removed.
This targets allocation waste, not the intrinsic per-pixel GMEM processing cost.

## Build and device validation, 2026-11-01

Paired native cross-builds of Mesa 25.0.7 completed successfully. Control and
candidate both include the previously tested buffer-capability correction 0003;
0004 tile selection and previous diagnostic/FP16 changes are absent. Only the
height-layout change distinguishes these paired artifacts. A private library
path was used, without replacing distribution packages or kernel modules.

196 full-image pixel checks passed across control/candidate, RGBA/BGRA/A8/L8,
257×131, 1023×769 and 1280×800, queued updates, and shared KMS-source/linear-target
1023×769. See `graphics-compact-layout-results.json`. These are bounded checks,
not exhaustive GPU conformance.

The new `tools/fd-texture-memory.c` allocates and clears sixteen private RGBA
render targets and measures the DRM client's total allocation increase using
fdinfo. Duplicated DRM fds are not summed. GPU/command/cache overhead is included.

| Size, 16 targets | Control increase | Candidate increase | Reduction |
| --- | ---: | ---: | ---: |
| 1280×800 | 85568 KiB | 69184 KiB | 16384 KiB, 19.15% |
| 1023×769 | 69184 KiB | 60992 KiB | 8192 KiB, 11.84% |
| 1024×1024 | 69184 KiB | 69184 KiB | 0 |

The actual allocation change is affected by BO allocation/cache size buckets;
it must not be inferred solely from width×height arithmetic. Probe cross-build
passed `-Wall -Wextra`. Its reading is total allocated memory, not exclusively
resident memory or physical VRAM; this is shared system memory on this device.

## Performance and deployment decision

Fixed stock CPU/GPU maxima, offscreen four-layer 1280×800 private-tiled-target
ABBA means: 14.8823 / 14.9464 / 14.9106 / 14.9308 ms. No steady-state rendering
speedup is demonstrated. Those runs lack an independent foreign-GPU-submit
record, so do not interpret the small differences as a regression or gain.
The previous clock minima (GPU 19 MHz, CPU 300 MHz) were restored.

A bounded real-shell trial retained Qt, KWin, kernel, cache plugin and
`inorder,ttile`. It completed warm-up and ten measured drawer cycles with a
stable candidate PID: 50.867 presentations/s, p95 33.349 ms, p99 33.434 ms,
17.00% of intervals above 25 ms. No GPU/kernel fault or logged display underrun
was detected by the profiler. This does not establish a GUI FPS improvement
relative to the earlier approximately 50–51/s controls.

An independent 240-second return timer guarded the trial. Original Mesa was
restored and verified in running shell PID 2873; the trial drop-in was removed.
Native graphics and SDDM remain active. Candidate 0005 remains outside the
production series: it is a measured allocation improvement, not a demonstrated
fix for the remaining 60-FPS deficit. The next throughput work must still target
RB/MARB or unnecessary memory traffic rather than treating this allocation
reduction as proof of increased raster throughput.

The first test runner attempted strace, which is absent on the device, after
completing pixel/ABBA tests. Allocation measurement was then performed using
the dedicated fdinfo probe; no strace-derived result is claimed.

Host source/build/test artifacts: `.work/mesa-compact-build/`.
Device private libraries: `/var/lib/t531/mesa-compact-20261101/`.
Device results: `/var/tmp/t531-compact-20261101/` and
`/var/tmp/t531-compact-gui-20261101/`.

## Integration, 2026-11-03

The bounded image/memory fix is now recorded in the main Mesa series as
`0011-freedreno-a3xx-compact-private-color-images.patch`, alongside the
buffer render-target capability fix (0010) and query-buffer sizing fix (0012).
The combined source matches a fresh upstream archive plus only the main
patch series. A clean `scripts/build-mesa.sh` cross-build passes. Combined
device readback/query results are in `graphics-release-validation-20261103.json`;
this does not establish 60 FPS or final graphical-session acceptance.
