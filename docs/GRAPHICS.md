# SM-T531 graphics investigation (2026-10-13–14)

> [!NOTE]
> Unified DRM migration and current validation limits: [Unified DRM](UNIFIED_DRM.md).
>
> These are **historical Plasma and framebuffer measurements**. The installed native Phosh profile and later IOMMU/DSI/MDP fixes are described in [Graphics stability](GRAPHICS-STABILITY.md). Its latest drawer regression is about 33 presentations/s; the older figures below are not a new benchmark of the installed build.

This investigation targets output latency and frame pacing with Debian 13,
KWin/Plasma Mobile 6.3.6, Mesa 25.0.7 and Linux v7.2.9 plus project patches.
Native MDP5/DSI/TC358764 scanout now works with accelerated KWin and separate
Adreno rendering. The owner physically accepts desktop, tray, touch, colours
and brightness. This remains PARTIAL bring-up, with DSI error interrupts and
unverified suspend/shutdown lifecycle; see [NATIVE-KMS.md](NATIVE-KMS.md).
A software frame-completion count is not an optical scanout measurement.

## Native Plasma measurements, 2026-10-14

The warmed complete desktop with the proper `msm-kms` Mesa entry gives
42.86 FPS (median 16.674 ms, p95 33.345 ms), aggregate four-core CPU 12.18%,
GPU busy 98.93%, normal devfreq/runtime PM, 450 MHz GPU and 266.67 MHz AXI.
Native card1 scans imported linear AB24 DMA-BUFs, pitch 5120, through MDP5
DMA0. The simpledrm RGB888 CPU conversion is absent from this path.

The owner's 15-second repeated notification-shade gestures give approximately
23.28 FPS in presentation bursts, median 49.998 ms and p95 50.015 ms,
GPU busy 97.50%. Pauses over 100 ms are excluded; without per-gesture markers
this can also exclude severe jank, so this is not a precise optical FPS or
input-latency measurement. A temporary background-contrast-effect comparison
gives 29.07 FPS, median 33.339 ms, p95 50.013 ms, GPU busy 98.91%, CPU 19.52%.
Contrast was restored automatically. Different manual gestures limit causal
comparison; no animation settings were changed.

`scripts/profile-drawer.sh` records simultaneous DRM presentations, GPU
submissions/utilization and CPU/frequency snapshots. It rejects compositor
restarts, new GPU/kernel faults and OOM. Both profilers inspect the compositor's
actual open DRM devices before and after recording with `graphics-path.py`;
the drawer test requires native MDP5 and an Adreno render descriptor. An intended
path supplied by an environment variable cannot override this check.
`tools/summarize-drawer.py` reports
the idle-gap threshold and its limitations explicitly. A temporary exact-build
upstream uinput module additionally permits repeated identical gestures without
physical assistance; no permanent input-injection service is installed.

The early 59.36 FPS native square run used a temporary global Mesa loader
override and an incomplete/crashing desktop. It is not the complete-interface
result. Replacing that override with the package built by
`scripts/build-mesa-msm-kms.sh` fixes driver selection for KWin's keyboard and
Qt Quick child contexts. It does not itself improve the warmed workload FPS.

The remainder of this document records the physically verified simpledrm
fallback and the preceding measurements; those results remain useful for
rollback and do not describe the current native output path.

## Evidence and actual frame path

`VERIFIED_DEVICE`: 1280×800, firmware RGB888 scanout at physical 0x03200000,
stride 3840; KWin XR24 linear buffers, pitch 5120; FD305 renderer; separate
MSM render and simpledrm KMS devices. The initial warmed animation workload
completed approximately 19.09 frames/s; median completion interval 55.82 ms.

`VERIFIED_UPSTREAM` / local pinned-source inspection: Mesa KMSRO's Freedreno
adapter allocates scanout buffers on the KMS device and imports their DMA-BUFs
into MSM. Therefore simpledrm `imported=no` does **not** prove an extra GPU
readback. KWin's `importWithCpu()` is a fallback, rather than an inevitable
step of every simpledrm presentation. EGL on this device advertises XR24 with
linear modifier 0 and `external_only=0`.

The actual kernel output step is
`drm_sysfb_plane_helper_atomic_update()` →
`drm_fb_xrgb8888_to_rgb888()` → per-line conversion and `memcpy_toio()` to
firmware scanout. The kernel supports FB_DAMAGE_CLIPS; installed KWin 6.3.6
has no corresponding plane-damage submission in `drm_pipeline.cpp`, so full
updates remain a potential cost even for small visible changes. Measure
conversion, synchronization and presentation before assigning the bottleneck.

## Confirmed bottlenecks and implemented changes

`VERIFIED_DEVICE`: MMSS AXI stayed at 100 MHz even when the GPU core ran at
450 MHz. CCF-only experiments at the supported 200 and 266.67 MHz rates
improved FPS. This is the graphics memory **interface** clock, not a direct
DDR clock setting or a RAM overclock. MSM8226 has no complete upstream
interconnect/bandwidth provider in this tree. Its downstream GPU requests
1.6/3.2/4.256 GB/s toward EBI and separate OCMEM bandwidth levels.

Patch 0042 couples AXI to the existing GPU OPP transitions: core ≤200 MHz →
AXI 100 MHz; 320 MHz → 200 MHz; 450 MHz → 266.67 MHz. It raises bandwidth
before core, lowers bandwidth after core, and returns AXI to 100 MHz on GPU
runtime suspend. A single-clock OPP callback preserves the existing devfreq
and cooling APIs. CCF parent-rate propagation changes only MSM8226 MMCC.
This is explicitly a **temporary clock-based substitute** for interconnect
votes. It does not implement DDR/RPM bandwidth/QoS votes and must be revisited
before native MDSS and other multimedia masters share managed bandwidth.

`VERIFIED_DEVICE`: Unknown-1 was considered external. PowerDevil's internal
LP8556 brightness device consequently did not match KWin's output. The slider
changed software brightness while hardware brightness remained 63/255, adding
an expensive full-screen color/brightness pass. Patches 0043–0045 describe the
verified internal LVDS transport with a documented local simple-framebuffer
binding extension. No panel model is invented, no bridge is probed, and MDSS
remains disabled. After reboot the output is LVDS-1 / Panel and KWin adopts
hardware brightness. Slider values 1500 and 2441/10000 changed PWM to 39 and
63/255 respectively. Brightness remains functional without software dimming.

Patch 0046 packs RGB888 rows with ARM NEON, using eight-pixel deinterleave /
interleave operations in the existing cached scratch buffer. Existing source
fetch, MMIO copy, clip handling and scalar tail remain. CPUs without NEON and
contexts where SIMD is unavailable use the scalar path. NEON context ownership
is restricted to one row at a time. The same assembly passed 10,248 on-device
width/alignment/color/overwrite checks. Full-frame blit median decreased from
about 7.7 to 6.9 ms; remaining source fetch and MMIO copy still cost time.

Patch 0041 fixes the A3xx devfreq busy-counter source: RBBM counter 1 selects
ALWAYSON in initialization, whereas Samsung uses fixed power counter 1 for GPU
busy cycles. This corrects measurement semantics; it alone did not improve FPS.
Patch 0040 exposes existing devfreq samples through a disabled tracepoint.
Busy percentage includes memory stalls and is not shader occupancy.

`VERIFIED_DEVICE` (owner observation): display, colors, touch and brightness
remain functional, FPS visibly increased, but the moving rectangle has a split
edge. This is consistent with tearing: CPU updates firmware scanout memory
while the display reads it. simpledrm has no physical panel vblank interrupt;
its completion is generated after the CPU copy. Raising FPS does not make this
path tear-free. A synthetic 60 Hz timer would not establish physical sync.

| Controlled/warmed QML workload | FPS | Median interval | p95 interval | CPU, four cores | GPU busy |
|---|---:|---:|---:|---:|---:|
| Original path, AXI 100 MHz, software brightness 61.58% | 18.70 | 55.63 ms | 56.15 ms | 8.33% | ~100% |
| Reversible AXI 266.67 MHz + software brightness 100% | 43.53 | 22.92 ms | 23.51 ms | 19.04% | 92.79% |
| Implemented AXI OPPs + matched hardware brightness | 41.36 | 23.08 ms | 24.13 ms | 19.34% | 81.81% |
| Above + NEON, default atomic KWin | 42.23 | 22.20 ms | 38.90 ms | 17.40% | ~100% |
| NEON + KWin safety margin 4000 µs | 41.87 | 19.62 ms | 36.45 ms | 17.54% | 98.67% |
| NEON + legacy KMS | 35.77 | 28.54 ms | 30.46 ms | 13.95% | 83.32% |
| Ordinary kernel, final installed configuration | 41.65 | 22.18 ms | 38.86 ms | 18.01% | 99.38% |

These are 19-second steady windows of DRM completion events, with CPU/GPU clock
medians 1190.4/450 MHz. The reversible 43.53 FPS experiment held CPU performance;
implemented rows use schedutil and normal GPU devfreq. It is not a claim of
43.53 stable physical frames/s in every Plasma application. Startup runs and
failed recordings are retained separately. A run overlapping compositor restart
and an OOM-killed Plasma run are invalid, not performance results.

GLES did not improve FPS. The sysmem rendering experiment hung the GPU and was
rejected; logs/coredump were saved privately and normal rendering restored.
Large 9000 µs safety margin and legacy mode were slower; none is installed as a
production override. Freedreno `inorder` remains because its removal previously
lost glyphs/icons. Plasma animations have not been disabled.

Additional UI automation is not accepted as a hardware pass: the D-Bus
`openActionDrawer` call returned with the drawer still closed. The compositor
and Plasma stayed running and the screen was not locked. This probe needs a
working control route before drawer frame timing can be compared; owner
physical feedback is retained separately.

Detailed sanitized measurements: [graphics-results.json](graphics-results.json).
Stable physical 60 FPS has **not** been achieved. The installed fallback is
`PARTIAL`: approximately 2.2× more completed frames, with remaining pacing
outliers and observed tearing. Native KMS remains `BLOCKED`, not `VERIFIED`.

## Reproducible measurements

Build the optional measurement configuration with:

```sh
GRAPHICS_TRACE=1 make build
```

Only a checked SD kernel is deployed. The immutable internal bootstrap,
lk2nd, recovery, modem and eMMC partition layout are not updated.
Tracers remain off by default. The common board configuration removes display
blocks and architecture built-ins for other SoCs to keep decompressor placement
safe; MSM8226, MDP5, DSI and Adreno support remain enabled. The optional fragment
adds instrumentation only.

On-device, copy `scripts/profile-graphics.sh`, `scripts/graphics-probes.sh`
and `tools/{frame-load.qml,sample-graphics.py,summarize-graphics.py,graphics-path.py}` in the
same relative layout to a readable temporary directory. Then run:

```sh
sudo scripts/graphics-probes.sh
sudo scripts/profile-graphics.sh /run/t531-fps-run-1
```

Each output directory must be new. The 25-second workload animates a rectangle
without removing Plasma effects. Record DRM completion events, paired converter,
plane-update and fence-wait probes, CPU ticks and clock frequencies. The MSM
tracepoint records the existing devfreq hardware busy/total measurements (µs),
without additional hardware reads. Optional `GRAPHICS_GPU_SUBMITS=1` records
submission/retirement latency, including software queueing and stalls. A3xx
retirement events have zero hardware start/end timestamps; these are not GPU
execution-time measurements. In the additional traced run, median submit-to-
retire latency was 20.94 ms (p95 30.58 ms). A3xx per-context fdinfo counters returning
zero are not treated as evidence of an idle GPU.

`summary.json` excludes the first five seconds and the final second. FPS is
computed from completed-frame intervals. CPU utilization is normalized across
all four cores; a single saturated core can appear as only 25% total CPU.
Simpledrm completion timestamps are synthetic and do not guarantee tear-free
physical vblank or 60 visible distinct frames per second. Failed workloads,
missing Wayland sockets, compositor restarts and OOM during recording are rejected.
The perf ring is limited to 64 pages per CPU to avoid measurement-induced memory
pressure. Samples include available RAM and AXI clock as well as CPU/GPU clocks.

## Boot-layout constraint and recovery

`VERIFIED_DEVICE`: the first large tracing build relocated the appended DTB
into framebuffer memory at 0x0327ff60..0x03289196. The old/new DTBs were
byte-identical; the larger compressed/decompressed kernel changed relocation.
`early_init_dt_reserve_memory()` refused the overlapping no-map reservation,
and ARM rejected the subsequent WC mapping. SSH and USB recovery stayed
available, but simpledrm did not register. This is a boot-image layout failure,
not evidence that native MDP5 or DSI failed.

The original SD files and modules were restored with matching checksums;
subsequent boot restored both DRM cards and the FD305 Plasma renderer.
`tools/check-boot-layout.py` now conservatively checks decompressed kernel,
BSS, compressed image, appended DTB and 256 KiB workspace against the firmware
framebuffer boundary before creating deployable artifacts. It rejects the
failing tracing image. It also rejected the large untraced multi-platform
configuration (bound 0x0329e931). The trimmed ordinary build has bound
0x02fe63b1, below 0x03200000. Do not weaken this check or move only the DTS framebuffer
address: the firmware display engine is already scanning that physical address.

The pre-investigation files are private on-device under
`/var/lib/t531/graphics-rollback/`; `boot-files.sha256` and `modules.sha256`
verify them. `sudo scripts/restore-graphics-kernel.sh` checks model and the
48 MiB `T531_BOOT` partition, verifies backups, stages and verifies SD files,
and restores modules. The same helper is installed on the tablet as
`sudo /usr/local/sbin/t531-graphics-rollback`. Run `sudo systemctl reboot` afterwards. It never opens
an internal eMMC partition. Bootstrap recovery remains available using Volume
buttons and USB ACM as documented in the project README.

## Native MDP5 / DSI / LVDS readiness

`VERIFIED_UPSTREAM`: MSM8226 MDP5, DSI host/28nm PHY and TC358764 drivers exist.
The SoC DTS already describes MDP5→DSI0; its MDSS node is disabled. This is not
a missing Adreno driver. `msm.separate_gpu_kms=1` separates GPU/KMS ownership;
it does not itself enable a display controller.

`VERIFIED_VENDOR_SOURCE`: the SM-T531 revision-02 board includes
`dsi_panel_tc358764_wxga_video-r01.dtsi`. It describes TC358764/65, four DSI
lanes, 24-bit video, virtual channel 0, nominal 60 Hz, 1280×800, porches
48/48/2 horizontal and 32/64/2 vertical, and a 458 MHz DSI bit clock. GPIO51
resets the bridge; GPIO25 is display-enable; PM8226 GPIO2 enables the LCD;
LP8556 backlight control uses GPIO20/21. These facts do not identify every
bridge supply or the exact LCD module.

The upstream bridge defaults differ from the Samsung sequence:

| Setting | Upstream TC358764 | SM-T531 vendor sequence |
|---|---:|---:|
| PPI LPX count | 2 | 4 |
| PPI clear SIPO | 5 | 4 |
| PPI turnaround | 0x00020003 | 0x00050006 (DSI commands) |
| VP_CTRL VS delay | 15 | 63 |
| VP_CTRL H/V polarity bits | set | clear |
| LV_CFG | clock polarity bits + enable | 0x1 |
| Host video flags | burst | downstream traffic mode 1 |

The alternative I2C initialization in Samsung's driver uses a different
turnaround value again. Do not silently choose one without confirming the
active stock build and the bridge/panel behavior. Some explicit TC timing
registers also describe 800/1280 active dimensions despite the declared
1280/800 DSI mode; event-mode timing behavior must be reconciled.

`UNKNOWN`: exact LCD identity, TC bridge core/I/O/LVDS supply topology and the
safe Linux power-off/on sequence. The upstream binding requires `vddc`
(1.2 V), `vddio` (1.8 or 3.3 V), and `vddlvds` (3.3 V); the board sources do not
establish which Linux regulators power them. The LCD module name alone would
not solve this. DSI PHY supplies L4/L5/L8 are not proof of
bridge supply wiring. `BLOCKED`: native takeover needs an appropriate panel
mode, modeled supplies/reset/enable sequencing, bridge configuration support,
and physical acceptance including suspend/resume. Blindly enabling MDSS would
remove the working firmware driver without establishing a working replacement.

## Sources

Retrieved/checked 2026-10-13–14. Preserve upstream authorship and licensing.

* Linux v7.2.9, commit `5fce161649b4d779d1b76d9fcd52dc77779774b8`:
  [sysfb modesetting](https://github.com/torvalds/linux/blob/v7.2/drivers/gpu/drm/sysfb/drm_sysfb_modeset.c),
  [ARM decompressor](https://github.com/torvalds/linux/blob/v7.2/arch/arm/boot/compressed/head.S),
  [TC358764](https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/bridge/tc358764.c).
  GPL-2.0 family; driver/framework and relocation evidence.
* [KWin v6.3.6 DRM EGL surface](https://github.com/KDE/kwin/blob/v6.3.6/src/backends/drm/drm_egl_layer_surface.cpp)
  and `src/core/renderloop.cpp`, GPL-2.0-or-later: buffer allocation, fallback
  readback, timing and scheduling. Current upstream was also checked.
* [Samsung downstream](https://github.com/LineageOS/android_kernel_samsung_msm8226/tree/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256),
  `arch/arm/boot/dts/msm8226/msm8226-sec-matisse3g-r02.dtsi`,
  `dsi_panel_tc358764_wxga_video-r01.dtsi`, `msm8226-gpu.dtsi`,
  and `mdss_tc358764_dsi2lvds.c`, GPL-2.0:
  exact-board wiring, bridge commands, GPU bandwidth votes and timings; research only.
* [Mesa KMSRO](https://gitlab.freedesktop.org/mesa/mesa/-/blob/mesa-25.0.7/src/gallium/winsys/kmsro/drm/kmsro_drm_winsys.c)
  and Freedreno resource allocation, MIT: KMS-side allocation and GPU import.
* [KDE PowerDevil v6.3.6 brightness controller](https://github.com/KDE/powerdevil/blob/v6.3.6/daemon/controllers/screenbrightnesscontroller.cpp)
  (LGPL-2.0-only) and KWin `drm_output.cpp` (GPL-2.0-or-later): internal backlight matching and
  hardware-versus-software brightness handling.
* [Qualcomm interconnect drivers](https://github.com/torvalds/linux/blob/master/drivers/interconnect/qcom/Makefile),
  checked 2026-10-14: MSM8974 is supported, MSM8226 provider is absent.
* [TC358764 binding](https://github.com/torvalds/linux/blob/v7.2/Documentation/devicetree/bindings/display/bridge/toshiba,tc358764.yaml),
  dual GPL-2.0-only/BSD-2-Clause: required bridge supplies and graph.
* [Kernel kprobe tracing documentation](https://docs.kernel.org/trace/kprobetrace.html):
  paired timing probes. This ARM32 kernel rejects return-probe `$arg2`
  capture; the measured GPU devfreq tracepoint avoids that limitation.
