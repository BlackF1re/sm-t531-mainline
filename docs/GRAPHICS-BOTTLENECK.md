# SM-T531 graphics diagnosis, 2026-10-15

Current reliability work (2026-10-17) is recorded in
[GRAPHICS-STABILITY.md](GRAPHICS-STABILITY.md): an actual NULL-domain IOMMU
panic, premature ARM32 DMA attachment during firmware handoff, and the DSI
video-blanking IRQ storm have separate fixes and device evidence. Historical
performance results below do not establish long-term stability.

## Evidence and limits

VERIFIED_DEVICE: the active path is Phosh 0.58.0-1~t5312 → Phoc
0.46.0-1 / wlroots 0.18.2-3 → Mesa 25.0.7 Freedreno FD305 → imported
linear XR24 DMA-BUF → native MDP5 DMA0 → DSI/TC358764/LVDS.
The output is 1280×800 at 59.999Hz. Simpledrm is disabled.

The clean manual 15-second drawer sample gives 30.835FPS, median
33.336ms and p95 33.346ms. All 192 traced GPU submissions are from Phoc,
with median submit-to-retire latency 25.8505ms. Queueing and retirement
scheduling are included: this is not a pure GPU execution timestamp.
There is no evidence of an intentional 30Hz output mode.

A temporary virtual keyboard was visually verified to open the actual
Phosh panel with its configured Super+V shortcut. It avoids orientation
errors and accidental quick-setting clicks from fixed touch coordinates.
The keyboard must advertise ordinary letter keys for udev to classify it.
Four open/close cycles give reproducible warmed samples around 33FPS.

The compositor-side counter observes a median five texture surfaces per
pass, covering about three full screens in total. That is observed draw
coverage, not proof that each of the five surfaces fills the whole screen.
An offscreen FD305 test using glFinish, no window/swap/vblank, and RGBA
textures measures about 11.2ms / 16.0ms / 25.6ms for one/two/four full
texture layers plus a clear. It reproduces excessive frame cost without
KMS presentation waiting. Rendered blue-channel pixels are checked.

VERIFIED_DEVICE: under an active offscreen workload, read-only RBBM
always-on counters advance at a median 449.990 million cycles/second with
450MHz requested. Selector1 is 0 and RBBM control is 0x30000. Earlier idle
all-zero samples were INVALID; these active samples confirm the GPU core
clock, not DDR. An initial shell trap syntax error was followed by explicit
restoration of the 19MHz minimum / 450MHz maximum policy.

## Controlled experiments

| Experiment | Drawer active FPS | p95 interval | Logged underruns |
| --- | ---: | ---: | ---: |
| Fixed GPU450MHz, AXI266.67MHz | 32.956 | 50.003ms | 3 |
| Fixed GPU320MHz, AXI266.67MHz | 29.165 | 50.018ms | 0 |
| Stock two MDP global settings | 32.706 | 49.988ms | 1 |
| Factory two MDP global settings | 33.190 | 49.968ms | 1 |
| Stock VBIF policy | 32.705 | 50.003ms | 4 |
| Factory VBIF policy, 15seconds | 33.590 | 49.995ms | 0 |
| Factory VBIF policy, 60seconds | 33.878 | see JSON | 0 |
| Full-background glClear, matching Debian ABI | 34.344 | 33.391ms | 2 |
| Phoc-only removal of Mesa inorder | 30.412 | 50.019ms | 0 |

These are short sequential samples, not confidence intervals. Differences
near 1FPS do not establish a useful speedup. The clock comparison verifies
equal AXI and CPU rates; median submit-to-retire is 22.649ms at450MHz and
26.293ms at320MHz. Neither frequency achieves 60FPS. CPU use is around
9–10% across all four cores in the warmed controlled runs.

Forced sysmem in the offscreen test makes four blended layers about46ms
instead of25.6ms. It is rejected. The glClear optimization has no meaningful
drawer gain demonstrated and remains an experimental patch, not a deployed
library. The first custom library missed Debian's layer-shell patch; adding
an extra Phoc XWayland patch also changed the ABI and caused a Phoc crash.
The final library uses exactly Debian's two downstream patches and completes
the measurement; the packaged system library is restored afterwards.
No global loader override or experimental library remains selected.

Two recordings immediately after session restart (20.166 and24.750FPS)
are INVALID comparisons: Phosh was still consuming substantial startup CPU.
Full numeric records, guards, queue latency and health reports are in
`phosh-performance-results.json`; raw logs stay in `/var/lib/t531` on-device.

## Blue flashes: confirmed MDP underrun

VERIFIED_DEVICE: the owner's blue flashes coincide with MDP5
`errors: 04000000`, INTF1_UNDER_RUN. MDP5 explicitly programs the underrun
color to0xff (blue). These errors existed on the initial boot, before the
clear experiments. They are distinct from the continuing DSI FIFO error
storm. Profiler `display-health.json` now reports MDP underruns separately;
rate-limited logged counts are lower bounds and zero is not physical proof.

Samsung's exact MSM8226 BSP commit
[3fa1853ed5d6c3a8ef5a2fda9822705243bbc256](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/boot/dts/msm8226/msm8226-mdss.dtsi)
sets VBIF CLKON at+0x004 to1 and DDR_OUT_MAX_BURST at+0x0d8 to0x707.
Readback on-device instead finds0 and0x808. FIFO watermarks match the
three-block allocation (0xc0,0x180,0x240); the tested two global MDP
settings alone do not fix underruns and are restored.

Patch0104 maps the existing parent's `vbif_phys` resource only for the
MSM8x26 hardware configuration. It replays the two factory settings after
MDP clocks are enabled, at initial setup and runtime resume. Other hardware
configs are unchanged. Checkpatch passes without warnings; the full kernel,
DTB, module tree and boot-layout checks pass. The configuration is identical
to0103; the raw kernel/SD image hashes are bit-identical because the changed
DRM driver is modular. The new installed msm.ko SHA256 is
`ccc91626b4056397c21c404b4dedea97e5d244cc37be56652dfb0b5ebe472d42`;
previous is`40851b420360d64f5768361fc1e7911a415fadf2a291ed9c1b7aa21f1ef25950`.
Previous SD files are verified in`/var/lib/t531/native-before-0104` and the
previous full module tree in`/var/lib/t531/modules-before-install.17121`.
Internal BOOT/lk2nd is untouched.

After deployment/reboot the owner reports no blue flashes but continued low
FPS. Sustained stability is not established: a subsequent GPU hang occurs.

## GPU hang after reboot

VERIFIED_DEVICE: at10:22:44 UTC, kernel hangcheck identifies Phoc as the
submitter, completed fence1906 / submitted1907, then attempts recovery.
Recovery times out draining ring0 at rptr/wptr0/24. Phoc subsequently logs
GL_CONTEXT_LOST. SSH continues working; this is a GPU/graphics-session hang,
not evidence of a kernel panic. Pstore is empty. Full journal, kernel,
thread, DRM, interrupt and available devcoredump evidence is saved under
`/var/lib/t531/freeze-0104` before reboot. Earlier Phosh/Plasma GPU hangs
predate0104, so causality of the VBIF change is not established.

HYPOTHESIS under test: GPU runtime suspend/resume contributes to the hang.
A temporary service drop-in
`/etc/systemd/system/t531-native-graphics.service.d/40-gpu-runtime-diagnostic.conf`
sets GPU power/control=on after native driver activation. This holds the
GPU powered for diagnosis, changes no OPP/voltage, and is not a production
power-management fix. Remove that file and daemon-reload to undo it; restore
auto only after the planned comparison. Physical UI stability, post-boot
VBIF readback and repeated drawer tests remain required.

After the interrupted reboot/recovery attempt, a fresh host check finds
SSH unreachable and the enumerated SM-T531 diagnostic USB console returns
no command response. The original GPU-hang evidence above was collected
while SSH still worked; it does not establish the cause of this later loss
of both diagnostic channels. A physical Power restart has been requested.
No further kernel/module deployment or clock change was made during this
recovery check. Application of the temporary GPU power policy at the next
boot is still unverified.

The next drawer recording also includes existing `msm_gpu_suspend`,
`msm_gpu_resume` and `msm_gpu_freq_change` tracepoints, plus passive sysfs
runtime-PM samples. These additions are prepared and syntax checked on the
host; they have not yet been deployed/run after the loss of access. A
failure-free bounded test with power/control=on alone will not prove a
runtime-PM root cause or constitute a production power-management fix.

## Recovery and held-power test

VERIFIED_DEVICE: after the owner forces a restart, USB and Wi-Fi/SSH return.
The installed module hash matches0104. Readback confirms VBIF CLKON=1 and
DDR_OUT_MAX_BURST=0x707. Phoc's live environment selects native MDP5 and
Adreno, FD_MESA_DEBUG=inorder, with no experimental LD override or
`.phoshdebug`. Pstore is empty. The saved freeze evidence, including the
205KiB devcoredump, has also been copied to the private host work directory.

The expanded profiler is now deployed and completes a60-second test with
40 virtual-keyboard panel transitions, no other compositor or GUI test,
and unchanged unlocked Phoc PID497/native DRM descriptors. It measures
34.229FPS across813 active presentation intervals: p50=33.332ms,
p95=33.391ms, p99=50.014ms. All957 traced GPU jobs come from Phoc;
submit-to-retire p50=21.342ms, p95=29.110ms, with none left outstanding.
No GPU fault or logged MDP underrun occurs during this test. All60 passive
power samples show on/active, with no suspend/resume trace events.
Whole-record CPU9.149% and GPU22.710% include the pauses between transitions;
these are not utilization figures restricted to animation frames. Owner
confirmation of visible movement/touch after this recovery is pending.

One MDP underrun is still logged during startup, before this measurement.
Therefore0104 does not establish an entirely underrun-free boot handoff.
There is no new GPU hang through at least eight minutes of this boot,
including the bounded rendering tests, but long-term stability and a
controlled auto/on runtime-PM comparison remain unverified. The temporary
held-power drop-in remains installed and can increase idle power use.

A further offscreen comparison holds the supported GPU450MHz/AXI266.67MHz,
uses the same FBO/geometry/blending and checks rendered blue pixels.
With a clear and four blended layers, median frame costs are24.771ms with
bilinear texture sampling,14.206ms with constant fragment color, and17.650ms
with nearest texture sampling. One-layer costs are10.860/7.247/9.830ms.
This separates a substantial texture-sampling/read contribution from pure
color drawing; it does not by itself separate texture units, cache layout,
DDR, shader instructions or all driver overhead. The output currently has
scale1 and Phoc's default auto-filter selects nearest at integer output
scales, so the offscreen nearest result is not a demonstrated new UI
optimization. No filter change is deployed. GPU limits are explicitly
restored to19MHz minimum/450MHz maximum after the test.

The private devcoredump records RBBM_STATUS=0x80004001 (GPU_BUSY,
CP_NRT_BUSY and HI_BUSY), rptr=wptr36, fence1906/1907. The first36 ring
words contain ME_INIT followed by the two indirect buffers and the fence1907
submission tail. This is consistent with a failure near a newly initialized
command ring; it does not establish runtime PM as the cause. Separately,
source inspection finds that a3xx_recover resets hardware pointers before
adreno_recover invokes the A3xx suspend callback, whose idle check compares
against the old software write pointer. The observed post-reset0/0x24 drain
timeout matches that conflict. Patch0105 synchronizes ring cur/next with
start after the hardware reset, before the suspend/idle call. It preserves
fences and the pending submission list for recover_worker's replay. The
primary hang and recovery failure must not be conflated.

The0105 in-tree module build and checkpatch pass with no warnings; its
configuration is byte-identical to0104. A checksummed complete module tree
is installed, retaining the preceding0104 tree in
`/var/lib/t531/modules-before-install.3189`; the kernel/DT/boot image are
unchanged. Installed candidate msm.ko SHA256 is
`970f92fa0b0a66bb306403483c88d0be2476366a7e25968f3759b0a3b803b8c3`.
BOOTS: the device reboots normally with a new boot ID, the expected module
hash and Phoc/Phosh running on native MDP5. The15-second post-boot drawer
test measures34.519FPS over168 intervals, p50=33.332ms, p95=33.448ms and
p99=50.014ms, with zero logged underruns/GPU faults. A separate screenshot
confirms that Super+V opens the actual notification/quick-settings drawer;
The owner subsequently confirms normal image, touch and panel interaction,
without blue flashes or a new freeze after restoration of packaged Phoc.
Recovery after an actual GPU fault remains unverified.

A bounded test temporarily selects power/control=auto and runs six small
32×32 offscreen workloads separated by idle. Every pre-render sample reads
runtime_status=suspended; suspended time rises from1022ms to7621ms. The
trace records exactly six suspend and six resume events. Every workload
completes its12 rendering cases with pixel checks, and no new GPU hang,
ring-drain timeout or warning is logged. This disproves an unconditional
failure on every runtime resume in this configuration; it does not exclude
an intermittent PM/clock/context-state bug. A timed independent restoration
and an EXIT trap return power/control=on. No intentional GPU fault was
injected. The temporary held-power policy is still selected pending longer
stability work. This is not a completed power-management fix.

## Opaque layer experiment on0105

A read-only Phoc/wlroots interposer now records destination geometry,
surface opacity, layer alpha and filtering. A representative pass draws
five textures, including two overlapping opaque1280×800 roots, and median
clipped coverage is about three screens. Filter mode is already nearest.
The source also shows Phoc rendering background/bottom/top/overlay groups
without excluding lower groups behind a fully covering opaque layer root.

Experimental `patches/phoc/0001-render-cull-fully-covered-layer-surfaces.patch`
only accepts mapped roots at output scale1 with a texture, actual geometry
covering the output, effective layer/alpha-modifier alpha1, and
PIXMAN_REGION_IN for the entire visible rectangle. It skips covered lower
groups/earlier surfaces and the otherwise redundant black rectangle. Higher
layers, drag icons and software cursors retain their order. Fractional
scales use the prior behavior. It is based on the official Phoc0.46.0
source [archive](https://sources.phosh.mobi/releases/phoc/phoc-0.46.0.tar.xz),
re-fetched and hash checked on2026-10-15, SHA256
`6a7337028a7b53872859895dc29f073b16cc610d969ccc002cf79eb09d09b814`.

The candidate builds against the same Debian wlroots0.18.2-3 ABI in the
isolated ARM build root. Xvfb/Pixman tests layer-shell, layer-shell-effects
and xdg-shell pass all12 cases, including a new full-pixel check of opaque
coverage, half-transparent buffer coverage, layer alpha0.5, shifted roots
and removal exposing the background. The first test run fails before
rendering because the isolated root lacks mutter-common schemas; installing
that build/test dependency fixes the environment. No test dependency is
installed on the tablet. These software tests are not physical acceptance.

On-device, the temporary candidate reduces typical pass texture counts
from5 to4 and median clipped coverage from3.00125 to2.500625 screens.
With the diagnostic interposer, stock/candidate give34.679/34.876FPS.
A separate comparison without the interposer fixes both GPU limits at the
supported450MHz (CPU1.1904GHz, AXI266.67MHz): stock/candidate give
34.344/34.492FPS, p95 intervals33.394/33.405ms. Median GPU submit-to-retire
is22.1435/20.002ms, p95=29.256/28.046ms; both tests have zero logged
underruns/GPU faults. Differences in CPU/startup activity and the short
sequential recordings limit causal comparisons. This is a demonstrated
reduction in composition work, without a meaningful UI FPS gain.

The candidate and probe were selected only via temporary `.phoshdebug`
wrappers with independent restoration timers. Both are now deselected,
ordinary packaged Phoc is restored, and its dpkg file verification passes.
GPU min/max are restored to19/450MHz. The experiment remains undeployed.
Raw data stays under `/var/lib/t531/phosh058-0105-*`; numeric results are
included in `phosh-performance-results.json`.

`tools/summarize-panel-actions.py` can additionally compare the toggle
windows without discarding long frame gaps. Its open/close labels assume
the panel was initially closed; individual toggle direction is not proven
from timestamps alone. First-presentation latency is an input scheduling
proxy, not photon latency. Do not use the labels as independent physical
confirmation of animation state.

At the end of this diagnostic session the0105 boot has run for at least
27minutes, including the tests above, without a new logged GPU hang. A
screenshot shows the restored Phosh app grid, the owner confirms physical
image/touch/drawer operation, packaged Phoc verifies cleanly, and no perf,
panel-load or offscreen benchmark process remains. This verifies recovery
of the usable UI, not a proven cure for the intermittent original hang.
The held-power drop-in remains temporary; automatic PM, sustained60FPS,
DDR attribution and actual GPU-fault recovery acceptance remain outstanding.

Stable60FPS is still unmet. Measured GPU composition cost is above the
16.67ms deadline, while display underrun and GPU recovery are separate
correctness blockers. Exact shader/memory/driver attribution remains PARTIAL.

## Texture-layout correctness isolation on0105

New `tools/fd-texture-check.c` uses a deterministic RGB pattern and compares
all output pixels, including unmodified pixels after five unaligned,
overlapping/edge-touching subimage uploads and a final whole-image update.
It tests RGBA and the supported BGRA8888 upload format, both257×131 and
1280×800, on the real FD305 with the installed Mesa25.0.7. The default
surfaceless renderer is checked. Optional independently selected linear
source/target buffers are real ABGR8888 GBM DMA-BUFs imported through EGL;
GBM must report explicit DRM_FORMAT_MOD_LINEAR. It does not use KMS master,
change the shell environment or modify system libraries.

VERIFIED_DEVICE: ordinary FD_MESA_DEBUG=inorder passes all28 image checks.
With inorder,ttile the first image fails before any partial upload:
257×131 first differs at(72,0), and1280×800 at(320,0). The latter returns
RGBA=(28,68,20,255) instead of(64,192,192,255), matching source(0,4).
Separate linear-target/tiled-source and linear-source/tiled-target cases
both reproduce these failures. Under the same ttile setting, explicitly
linear source AND target pass all14 checks at each size. No new GPU fault
or logged MDP underrun is observed. This is a repeatable texture-layout
correctness defect, separate from the shader/DDR performance attribution.
It also reproduces a reason to reject the earlier global ttile experiment;
no shell receives ttile in these tests.

The first bad x equals one quarter of the aligned pixel pitch (288/4 and
1280/4). A tiled row-pitch interpretation problem is therefore HYPOTHESIS,
not an established fix. Exact upstream Mesa25.0.7 source is retrieved from
[the release archive](https://archive.mesa3d.org/mesa-25.0.7.tar.xz), SHA256
`592272df3cf01e85e7db300c449df5061092574d099da275d19e97ef0510f8a6`.
A private cross-build is prepared for an isolated driver comparison; the
packaged Mesa and ordinary Phoc remain selected. Raw checks are retained
at `/var/lib/t531/0105-texture-layout` and in the private host archive.


The isolated Mesa experiment corrects two repeatable defects in the opted-in
4x4 layout: hardware row pitch (four pixel rows per tile strip) and BGRA
GMEM target channel order. Both patches are retained under `patches/mesa/`.
After removing the diagnostic allocation-size guard, complete RGBA/BGRA/A8/L8
pixel tests pass56 images with tiled source/target,56 with tiled source and
explicit linear target, and56 with default linear resources. Explicit linear
ABGR8888 sources pass28 RGBA/BGRA images for each target layout; A8/L8
uploads into that fixed ABGR8888 storage are explicitly skipped as an ES2
format mismatch, not classified as driver failures. The isolated EGL, GBM
and GBM DRI backend must match the driver build. An initial benchmark with
the packaged GBM backend fails versioned-symbol loading before rendering;
it is invalid, and the repeated benchmark uses matching components.

At fixed450MHz, nearest-sampled four blended layers into an explicit linear
GBM target give median18.0588ms (stock),15.4327ms (candidate with ttile),
and18.1378ms (repeat stock). With a background quad instead of a clear,
the same costs are20.8562/18.1301/20.8337ms. These are static offscreen
workloads, not measured drawer FPS. The benchmark logs zero MDP underruns;
CPU/GPU/AXI sample frequencies are1.1904GHz/450MHz/266.67MHz.

REGRESSION: a subsequent bounded compositor-only trial starts ordinary Phoc
with the private corrected Mesa and inorder,ttile. The Phosh desktop starts,
the native DRM guard passes and snapshot files are created. After reset
those recent snapshot/perf/metrics files are zero length, so they do not
provide surviving image/library-map/FPS evidence. Persistent Phoc startup
logs do confirm FD305 and the private Mesa25.0.7 version. At the start of the drawer profile the device stops answering
SSH and USB console; the owner confirms a frozen image. No completed FPS
recording is available at this point. Passing texture tests does not validate
all composer rendering/import/damage paths. The candidate is REJECTED for
ordinary use pending fault evidence and further diagnosis. An independent
180-second root timer and EXIT trap were installed to restore the packaged
session; they cannot recover a kernel that stops executing. Hardware reset
and post-reset evidence collection may therefore be necessary. The trial
changes no boot image, kernel module or system Mesa package. Its temporary
`.phoshdebug` selector must be removed after a forced reboot, since `/run`
candidate files do not survive reboot. SSH recovery remains configured.


## Recovered console: shared interrupt failure, not a proven GPU hang

The owner resets the tablet after the restoration deadline. The host
recovery watcher saves logs, removes the persistent `.phoshdebug` selector
and starts the ordinary packaged session. New boot ID is
`06c917bf-b89f-4bbe-85f9-d40ca00fe3db`. The owner confirms image, drawer
and touch work again. Live process maps contain only packaged EGL/GBM/
Gallium, GPU limits are19/450MHz, and the temporary runtime hold remains on.
No experimental session or workload remains selected.

The initial sysfs-pstore directory is empty. This does NOT mean no record
survived: systemd archives records in `/var/lib/systemd/pstore`, and the
existing bootstrap `scripts/kexec-sd.sh` saves the preceding SD kernel's
records in `/var/log/t531-pstore` before kexec. The latter console record
contains the failed boot up to3857.740seconds. Both archives are now copied
into `/var/lib/t531/mesa0105-freeze-recovered`, also saved privately on-host.
Old dmesg-ramoops records show a historical early-IOMMU panic at17seconds;
they are stale and must not be attributed to the new live-session freeze.

VERIFIED_DEVICE: the new failed console has no GPU hangcheck or panic.
DSI error-work messages end at3644.142seconds, RPM errors at3645.793.
At3672.812 SD times out waiting for an interrupt even though IntStat=0x3
(command and transfer completion). WCN36xx SMD requests time out next,
then PMIC VADC conversion and thermal reads fail. Kernel timeout messages
continue for several minutes, including an unrelated userspace watchdog.
Thus the entire kernel does not simply stop executing. Live IRQ accounting
after reboot routes SD, USB, WCNSS, GPU, display and PMIC interrupt activity
to CPU0; CPU0 standalone power collapse is enabled and used frequently.

HYPOTHESIS: CPU0/interrupt delivery (or a handler stuck with local IRQs
masked) is a common cause of the lost graphics, storage, network and USB
response. CPU0 power collapse and the DSI interrupt storm are candidates,
not measured root causes. There is no recorded faulting instruction or
CPU0 stack. The Mesa trial is not accepted for ordinary use, but temporal
coincidence does not establish that its texture fixes caused the shared
interrupt failure. GPU-only runtime-PM holding did not prevent this event.
No CPU-idle or IRQ-affinity policy has been changed yet.

An independent vendor-source safety issue is recorded in draft kernel
patch0106: omit exactly the57 registers in the nine HLSQ ranges that the
Samsung BSP excludes from fault-tolerance dumps because reads can hang the
device. Current upstream a3xx at
[be0e82b8e0c96649b8bc77a99ab0d185243b7659](https://github.com/torvalds/linux/blob/be0e82b8e0c96649b8bc77a99ab0d185243b7659/drivers/gpu/drm/msm/adreno/a3xx_gpu.c)
still contains them (upstream file history checked2026-10-15). The exact
[vendor warning and excluded ranges](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/drivers/gpu/msm/adreno_a3xx.c#L68)
are the evidence. All other snapshot registers remain. The in-tree module
build succeeds without warnings; checkpatch style checks pass with
`--no-signoff` because this is an unsigned draft. It is NOT deployed and
does not explain the new freeze without evidence that crash capture ran.
No further driver-switching or fault-inducing tests are run after recovery.

The wlroots0.18 source also bounds the proposed extra-copy hypothesis:
`drm_connector_set_pending_fb()` calls `drm_surface_blit()` only for a
secondary DRM backend with `drm->parent`; otherwise it imports the source
buffer directly. This session selects only the native KMS card, and saved
pass-probe recordings contain normal composition passes rather than one
extra single-texture pass per frame. No evidence of that particular
multi-GPU copy has been found. Texture upload/render costs and the separate
shared-IRQ stability issue remain the actionable investigations.

`scripts/collect-graphics-failure.sh` now captures all four known pstore
locations (sysfs, systemd, bootstrap, rescue), both journal boots, boot ID,
IRQ counters/affinities, CPU-idle counters and whitelisted graphics library
maps/environment. It never unloads a driver or changes session/PM policy.
The new collector is installed under `/opt/t531-graphics-test/scripts`, run
on the recovered tablet, and its SHA256SUMS verifies. Output is private at
`/var/lib/t531/0105-final-evidence`. Installed msm.ko still verifies as0105
(`970f92fa0b0a66bb306403483c88d0be2476366a7e25968f3759b0a3b803b8c3`);
0106 exists only as source patch and a host-built draft artifact. At least
14minutes after the recovery boot, ordinary Phoc/Phosh and native KMS are
running, with owner acceptance and no leftover automatic graphics workload.

The next controlled stability comparison should separate CPU0 idle/IRQ
routing from the Mesa experiment and preserve live evidence outside the SD
write cache. Do not attribute another all-device communication loss to a GPU
hang without its actual console/IRQ evidence. Do not repeat the rejected
compositor trial before addressing recovery observability. Neither these
texture fixes nor kernel0106 establish stable60FPS.

## Physical bus verification and DSI diagnostics (later2026-10-15)

See [MEMORY-BUS.md](MEMORY-BUS.md) for primary BSP sources, measurement
method, actual DDR533.33MHz / GPU AXI266.67MHz / GPU450MHz under load,
NoC/BIMC register readbacks and the negative QoS Bypass comparison. New
patch0107 corrects invalid RPM bandwidth nodes; native GUI boots and RPM
ENXIO errors stop. Four-cycle drawer samples remain33–34FPS. A frequency
request alone is no longer used as proof of actual bus operating rate.

Module0108 includes the0106 safe-snapshot omission plus IRQ-time DSI status
capture. Actual timeout0x1 and HS FIFO underflow bits are now distinguished
from live empty flags. No fault recovery test is claimed. The separate0109
summary-ack ordering candidate boots and gives33.81FPS versus33.89 for0108;
DSI IRQs persist. It does not establish either an IRQ or performance fix.

A15-second trace of all IRQ entries/exits lost32.5% of its events. It is
INVALID for quantitative frame/CPU baseline comparison. Do not silently
interpret its incomplete total IRQ time as full CPU overhead. A second
recording without high-volume IRQ events captures559 samples losslessly.
Read-only RBBM sampling at1ms is correlated with193 matched GPU jobs. For
107 jobs with submit-to-retire latency at least15ms and below100ms, median
latency is24.866ms and median GPU busy time is20.361ms; median per-job busy
fraction82.1%. Busy-cycle conversion uses the independently verified load
rate450MHz. Sampling/interpolation uncertainty is about1ms; this is not a
hardware timestamp attached to each command. Presentation remains34.25FPS.

This supports a GPU-side render/texture/memory cost above the16.67ms budget,
not merely delayed CPU fence retirement. It does not yet distinguish shader
work from memory stalls. The next bounded experiment enables only the two
VBIF diagnostic counters used by the Samsung GPU bus governor: AXI total
beats (countable85) and power counter0 (waiting for RAM). A30-second kernel
restore timer and module removal return the counter configuration to its
previous state; no operating clock, IRQ, QoS, voltage or display timing
changes are involved. Data remains private under`/var/lib/t531/0109-*`.


## GPU texture bottleneck isolated (2026-10-16)

VERIFIED_DEVICE: bounded VBIF/SP/TP counter tests, with restored selectors
and no operating-rate changes, distinguish texture work from a broad RAM
wait. During the drawer, RAM-wait counter/busy-cycle ratio is0.0070,
SP-stall-TP/busy-cycle ratio0.5493, SP-stall-UCHE and SP-stall-RB0.
TP L1 misses/requests is0.2504. These events overlap: ratios are NOT an
exclusive partition of execution time, and low RAM-wait count does not
prove the absence of all memory-system latency. TP latency transaction
count remains0 and UCHE latency samples appear clock-like on this chip;
those unvalidated counters must not be converted into average latency.

An independent AB-A comparison uses the same private Mesa25.0.7 build,
stock versus patches0001/0002 with opt-in ttile, fixed450MHz GPU, bilinear
sampling and a linear1280x800 GBM DMA-BUF render target. Packaged Phoc and
all GUI libraries remain unchanged. Each case uses40 measured frames,
glFinish, and read-back pixel validation. For blended layers with glClear:

| Full-screen texture layers | Stock1 ms | Fixed tiled ms | Stock2 ms |
| --- | ---: | ---: | ---: |
| 1 | 11.0975 | 8.6809 | 10.9854 |
| 2 | 15.8964 | 11.1120 | 15.7860 |
| 4 | 25.5527 | 15.9118 | 25.4134 |

The four-layer case reduces frame time37.7% and exceeds60FPS offscreen.
SP-stall-TP/busy ratio changes0.8971 →0.2389 →0.9017; RAM-wait ratio stays
below0.002. Pixel checks pass, with no logged GPU hang or MDP underrun.
This is a driver texture-layout improvement, not a Phosh animation tweak.
It is NOT yet proof of60FPS in either compositor, and the prior live Mesa
trial's shared-IRQ freeze remains an unresolved acceptance blocker.

Raw private evidence: `/var/lib/t531/0109-gpu-bus-profile2`,
`0109-gpu-shader-profile`, `0109-independent-texture-counters`, copied to
`.work/phosh/0109-irq-evidence/`. `tools/native-gpu-counters/README.md`
documents the bounded diagnostic. No counter module remains loaded.


## Live-compositor texture comparison (2026-10-16)

A new short trial uses the ephemeral session configuration through a
symlink into /run; after reboot its missing target automatically restores
packaged libraries. CPU0 cpu-spc is temporarily disabled equally for stock
and candidate, with an independent restore timer. GPU450MHz, native DRM,
one unlocked compositor, matching library mappings,15s/four panel cycles:

| Configuration | Presentation FPS | Submit-retire p50 / p95, ms |
| --- | ---: | ---: |
| Packaged Mesa, temporary CPU0 SPC off | 34.074 | 22.121 /30.205 |
| Fixed private Mesa, ttile, same PM | 33.760 | 18.145 /29.674 |
| Fixed Mesa plus full-background clear | 33.467 | 16.548 /27.021 |

VERIFIED_DEVICE: all valid recordings complete without GPU hang or logged
MDP underrun. These GPU queue changes do not yield a useful presentation
FPS increase. The previous shared-IRQ freeze is NOT explained or fixed by
a short successful trial. CPU0 idle state and normal GPU limits are restored
after each experiment; ordinary sessions still use packaged Mesa.

An earlier setup attempt loaded stock libraries because a root-only /run
directory hid the wrapper. It was stopped and rejected as a comparison.
The new guard requires the candidate's actual library mappings. A second
occlusion setup is rejected before recording because its executable name
was not `phoc`; the corrected trial preserves that basename. Neither setup
failure is counted as a performance result.


The corrected occlusion+fixed-tile+clear combined trial completes:
40.682FPS,198 active intervals, p50 interval16.673ms, p95 49.999ms.
GPU submit-retire p50 is12.717ms, p95 23.421ms; whole-recording CPU9.50%
(all cores), GPU17.55% including pauses. Typical pass4 textures/3.0025
screen-equivalents. This is a short combined comparison, not attribution to
one patch or a stable60FPS result. Zero logged MDP underruns and no GPU
hang; ordinary Phoc/Mesa and CPU0 SPC are restored afterwards. Further
live image acceptance and longer stability testing remain required.


## Fence/atomic path and IRQ controls (2026-10-16)

VERIFIED_DEVICE: optional `T531_PROFILE_ATOMIC=1` adds MSM atomic tail and
DMA-fence events to the bounded profiler. Event loss is now explicitly
rejected. On stock Mesa,162 complete atomic tails have median preparation
(start → flush)0.094ms, p95 0.165ms. The initial modeset is much slower
and is included in maximum78.476ms.161 uniquely matched single-CRTC
flushes → presentation events have p50 7.112ms, p95 15.878ms, max16.570ms.
There is no observed additional full refresh of post-ready scanout delay.
The260 completed scheduler-fence waits have median22.606ms and p95 29.106ms.
Wait time includes GPU and scheduling; it is not CPU execution time.

A separate kernel/user frame-pointer callchain recording does not unwind
beyond the first kernel frame and partial userspace frames, so it cannot
prove the full caller chain. Exact Debian Mesa debug symbols, matching
Build-ID fd7dcad10de8c89211ebe69ae8c8dda302f047d0, resolve the repeated
userspace return PC to `fd_bo_cpu_prep()` at freedreno_bo.c:730, waiting
in `fd_fence_wait()`. The subsequent bounded GL interposer identifies texture uploads, as
recorded below; no ARM Thumb uprobes are used.

The independent benchmark now also reproduces wlroots' conditional-highp
fragment shader and uniform alpha. With nearest filtering, four blended
layers/glClear measure17.67ms stock and15.76ms fixed-tiled, versus17.89ms
and15.70ms for the original mediump/constant-alpha shader. Shader precision
alone does not explain the UI cost. Pixel checks pass in all four cases.

A separate anomaly is GPIO38 card-detect IRQ noise (hundreds per second).
`tools/native-irq-diag` masks only that GPIO IRQ for at most30seconds, never
SD data/power IRQs. A normal/masked/restored comparison gives33.38/33.56/
33.35FPS. The counter is unchanged during masking and resumes afterwards.
This is a negative performance result. One MDP underrun occurs in the
normal control, none in the masked/restored cases; no causal claim follows
from three short runs. The no-pull DT state matches Samsung's board table,
so no speculative pin bias change is made. IRQ noise and occasional
underruns remain unresolved; do not describe the video path as perfect.

The first userspace-wait logger could not start a graphical session because
its constructor required libdrm even in the intermediate `env` process.
The trial is rejected before recording. Recovery exposed a separate script
bug: reloading a vanished user manager prevented SDDM restart. Session
selection changes only system display-manager files, so the unnecessary
user daemon-reload is removed. Ordinary SDDM/Phoc/Phosh are restored; the
corrected logger leaves non-DRM child processes alone.


## Inorder texture-upload CPU stall isolated (2026-10-16)

VERIFIED_DEVICE: the corrected bounded userspace GL/drmCommandWrite logger
records all first8 blocking waits inside glTexSubImage2D (19.599,23.634,
23.803,23.767,9.430,23.486,23.783,23.796ms). Exact Debian debug symbols
also resolve the partial perf return PC to fd_bo_cpu_prep:730, which waits
for outstanding fd_fence objects. Full userspace unwinding still stops at
the interposer, so the GL operation label is used rather than inventing a
complete backtrace. The operation wrapper preserves arguments and return
values, and is only temporarily preloaded into the compositor.

Mesa25.0.7 permits busy linear texture staging only when batch reordering
is enabled. This project uses inorder to avoid the separately observed
reordering faults. Draft patch0003 admits the existing staging GPU-copy
path for private single-sample a3xx 2D texture uploads in inorder mode;
resource shadowing stays disabled. Shared textures, persistent/direct
maps, CPU reads, other targets/generations and synchronization semantics
retain their prior path. This does not skip a fence or write an in-use
texture from the CPU.

`FD_TEXTURE_INFLIGHT=1` extends the upload validation: seven distinct render
targets save the before/after states of overlapping updates to one source;
four draws per snapshot are flushed without intermediate readback. All
seven images are checked only after queueing the whole sequence. This
catches accidental modification of textures still used by earlier GPU
work. RGBA/BGRA/A8/L8 at257x131 and1280x800 pass56 full-image checks per
run, both ordinary and in-flight, on both stock and candidate (224 total).
All tests use inorder, without ttile, and actual private library loading
is verified by the loader log.

For twenty large partial uploads (updates1–5 across the four formats),
median CPU call time falls26.850ms →0.199ms, maximum48.495ms →0.467ms.
Candidate Gallium SHA256 is
d12853af793aa9383e1b90ce700008c71b8fd3b790ac290a896f93597ee0c72f.
The source builds without warnings. Real compositor frame timing and
sustained stability are still required before accepting it for ordinary
use. Private evidence: `/var/lib/t531/0110-inflight-staging-check`, mirrored
on the host. No system Mesa package has been replaced.


A later resume exposed an error-filtering bug: /proc/uptime includes
suspended time, whereas the saved printk/perf timestamps do not. On this
boot they differ by about10704seconds. The profiler now writes a unique
/dev/kmsg start marker and takes its kernel-generated timestamp instead.
Measurements collected after resume with the old filter require health
reanalysis using the corresponding perf timestamp; their original zero
error count must not be accepted. Presentation/FPS and pixel comparisons
are unaffected by that filtering bug. Old pre-suspend recordings have
no such measured offset.


## Inorder staging: CPU improvement does not improve presentation

VERIFIED_DEVICE: the repeat `0110-mesa-inorder-staging-live2/async` uses
private candidate libraries verified in process maps, ordinary Phoc,
FD_MESA_DEBUG=inorder without ttile, GPU450MHz and CPU0 SPC enabled.
All first-long-wait records disappear, confirming the upload CPU stall
is removed. Presentation is nevertheless only30.610FPS (p50 interval
33.334ms, p95 50.011ms), compared with32.593FPS in the earlier stock run.
The samples are sequential, not a randomized statistical comparison;
they establish no FPS improvement. GPU scheduler-fence waits remain
p50 23.493ms/p95 36.401ms. Ordered staging copies add GPU work.
The draft patch0003 is therefore **not accepted for ordinary deployment**.
System Mesa and the ordinary compositor are restored after the trial.

The first candidate recording was invalidated by updating an executing
Bash profiler in place. Its complete perf stream can be inspected, but
it lacks the normal after-guards and is not accepted as a valid comparison.
Subsequent script deployment uses a temporary sibling and atomic rename.
The valid repeat records158 uniquely matched native commits, preparation
p50 0.084ms/p95 0.192ms, ready-flush to presentation p50 8.904ms,
p95 15.039ms/max16.593ms; no extra full-refresh delay is demonstrated.
Its corrected printk timestamp filter finds zero logged MDP underruns;
this remains a lower bound, not physical display acceptance.

After about10704seconds of suspended time on the same boot, the hardware
clock counter is measured again during real drawer animation:
DDR533.337MHz, GPU AXI266.666MHz and GPU450.003MHz. Debug registers are
restored and checked. Ordinary presentation is32.273FPS. This excludes
an observed post-resume clock collapse for these three clocks during this
test; OCMEM physical frequency is still not directly measured. Evidence:
`0110-after-resume-hardware-clocks`. No clock over its vendor rate is used.


## Texture damage and complete-level storage replacement

The upload-box probe is bounded to512 records and makes no GL queries or
state changes. It logs dimensions, current tracked texture name and CPU
call time. Texture names assume a single context/unit; the diagnostic is
loaded only into Phoc. A first trial had an unreadable preload (root640)
and therefore no upload records; it is rejected for upload attribution.
The corrected trial checks both library maps and probe maps before capture.

VERIFIED_DEVICE: `0110-texture-upload-boxes-valid/stock` records152 uploads,
all on tracked texture6:64 complete1280x800 uploads,48 updates39x252,
38 updates32x16 and two other small rectangles. Median call times are
3.993ms,3.399ms and22.943ms respectively; maxima31.924/26.565/26.456ms.
Even tiny partial updates wait for GPU readers; upload byte count alone
is not the stall. The GUI remains33.565FPS with this diagnostic.

Draft0004 is an alternative to0003. For complete uploads only, it allows
the existing resource-shadow/tracking-swap helper in inorder on private,
linear, single-level, single-sample a3xx2D color textures. There are no
other levels to preserve, so this requires no preservation GPU blit.
Partial uploads/shared resources/direct/persistent maps stay unchanged.
The candidate SHA256 is
913f0cb866cfd4fd95d2dace0786d18d6cc69b3d1770edcd02c4b6ceb75dee19.

`FD_TEXTURE_FULL_UPDATES=1` adds consecutive complete replacements to the
in-flight pixel test. Stock and0004 each pass56 ordinary,56 mixed-update
in-flight and56 full-update in-flight images (336 comparisons total).
For1280x800 full-update BGRA the upload CPU median falls23.030→5.508ms;
RGBA28.976→15.903ms, A8 16.603→4.237ms, L8 16.770→1.238ms. Conversion/copy
cost remains; this is not zero-cost upload or a proven GUI FPS result.
Evidence: `0110-inflight-rename-check`. System Mesa remains unchanged.


Draft0005 (on0004, excluding0003) restricts ordered staging to partial
rectangles no larger than1/16 of base-level area. The candidate SHA256 is
4ad26334ec13e162a3fb9a7ee764191c66c3f182b433e0ecbcef549a84c77588.
It passes168 ordinary/mixed-in-flight/full-in-flight pixel comparisons.
Private real-UI trial gives33.812FPS:39x252 upload CPU p50 0.446ms and
32x16 p50 0.231ms; full uploads p50 3.941ms. GPU submit-to-retire remains
p50 21.782ms/p95 30.520ms. With the earlier Phoc occlusion/clear experiment
it gives34.074FPS; median pass5 textures/4 screen-equivalents on this
particular session. Neither trial demonstrates a useful FPS improvement.
This distinguishes CPU upload waiting from the underlying GPU completion
cost; removing the former is insufficient. Drafts0004/0005 are not promoted
to packaged Mesa. All transient loader/session overrides are restored.
Evidence: `0110-inflight-small-check`, `0110-mesa-inorder-small-live`,
`0110-mesa-small-occlusion-live`.


## GMEM selection and direct CPU packing experiment

VERIFIED_DEVICE: a bounded private CPU-only batch logger (no GPU timestamp
commands; a3xx has no record_timestamp callback) records278 batches.
All171 draw batches with4–6 draws and1280x800 target use GMEM,5x7 bins;
restore/resolve mask4.86 small one-draw staging batches use sysmem and
21 empty batches also use sysmem. No incorrect full-scene bypass selection
is demonstrated. Profiling changes no GPU commands or operating clocks.
Evidence: `0110-gmem-batch-profile`,34.313FPS. The logging-only Mesa build
is isolated; system libraries are unchanged.

A separate private GL texture is uploaded through the GPU, finished,
exported and mapped read-only with DMA_BUF_IOCTL_SYNC. All1024 pixels at
32x32 and2961 pixels at63x47 have the observed a3xx4x4 byte offset:
`(y/4)*pitch*4 + (x/4)*64 + (y%4)*16 + (x%4)*4`.
Pitch is128 and256bytes respectively. The EGL export reports an INVALID
modifier; it is not used for external scanout/import. This is a private
layout experiment, not proof of a usable shared DRM modifier.

Draft0006 uses that layout only for complete private sole-level a3xx
32-bit UNORM color uploads. Eligible tiled BOs become CPU-mappable; the
existing shadow/tracking helper replaces busy backing before any write.
CPU staging is cached malloc memory and unmap packs four-pixel rows into
the fresh/idle tiled BO. Partial updates, other formats, sharing,
direct/persistent maps, mipmaps and other generations retain prior paths.
It requires0001/0002/0004/0005, excludes0003, and keeps ttile opt-in.
Candidate SHA256:
3d74ed899c4e252a34ef4082da26bd0ae214b4bc6c2d56829dc29c787377bc3f.

Control and candidate each pass168 ordinary/mixed-in-flight/full-in-flight
image checks (336 total), RGBA/BGRA/A8/L8,257x131 and1280x800, with
inorder,ttile. BGRA complete-update CPU call median is4.131ms control,
4.390ms candidate; this experiment targets extra GPU copies, not a claimed
CPU-time gain. Live compositor timing is pending. Evidence:
`0110-inflight-cputile-check`. No persistent graphics change is deployed.


The first tiled control/candidate session comparison is confounded:
control39.028FPS uses median4 textures/3.0031 screen-equivalents; candidate
33.443FPS uses median5 textures/4 screens. Both run the same occlusion
binary, but the scenes after separate shell restarts differ. These values
are retained as observations, **not a causal CPU-tile regression or gain**.
A private-only marker-controlled build now compares GPU-copy/CPU-pack/
GPU-copy in the same compositor process. It also records bounded CPU-path
hits to verify selection rather than infer execution from pixel success.
This marker instrumentation is not part of draft0006 or a system package.


**Correction:** the first0006 implementation compared tile mode with2,
but the authoritative a3xx.xml enum is TILE_4X4=1 (2 is TILE_32X32).
The bounded execution-hit counter stayed empty in the same-process trial,
which rejected it before a third recording. Thus the original168 pixel
checks on SHA3d74ed... exercised fallback, not CPU packing; they do NOT
validate the new path. The old39/33FPS comparison is not evidence for
that path either. Ordinary Phoc/Mesa were automatically restored.
The corrected implementation uses TILE_4X4 in a3xx-specific helpers, with
an explicit perf-message execution check in each new pixel run. No
production global tiling change is made on the strength of fallback tests.


## Corrected CPU packing: measured negative result

VERIFIED_DEVICE: corrected0006 (TILE_4X4 enum1), NEON0007 and cached-scratch
0008 each pass168 image checks, including mixed and complete updates while
earlier GPU images remain in flight. Bounded path-hit messages confirm
execution of the new path. Full BGRA upload CPU medians are27.765,37.332
and37.362ms respectively; RGBA35.848,43.115 and43.921ms. These are
experiments, not production optimizations. Minimal patches1/2/6/7/8 apply
without4/5 and with zero fuzz to the official Mesa25.0.7 archive.

The controlled same-process GPU-copy / scalar-CPU-pack / GPU-copy comparison
gives39.1548 /36.0372 /38.9663FPS. Each scene has median4 textures and
3.003 screen-equivalents; GPU fence medians14.388 /14.350 /14.338ms.
CPU-path hit counts are0 /16 /16 cumulative (disabled in the third run).
There are zero logged MDP underruns in these recordings. This demonstrates
a regression for CPU packing, unlike the earlier confounded session test.

A separate28-image phase probe measures cached packing including zeroing
at16.5–16.9ms; BO upload initially14–16ms and later3.4–3.8ms. A warmed
CPU1 cached-memory microbenchmark measures approximately1.5ms memset,
9.4ms NEON packing and4.6ms memcpy for4.096MB. CPU PMU cycle/time
measurement independently gives1.190GHz. Other PMU cache events returned
zero and are not valid evidence of cache behavior. Reusing cached scratch
may avoid first-touch overhead, but packing still consumes a substantial
refresh budget. Ordinary Phoc and system Mesa are restored. Evidence:
`0110-inflight-cputile2-check`, `0110-cputile2-same-process`,
`0110-inflight-cputile3-check`, `0110-inflight-cputile4-check`,
`0110-cputile-phase-check`, and private CPU microbenchmark logs.

## Hardware composition and mixer-stage boundary

VERIFIED_DEVICE: enabling wlroots0.18's existing libliftoff backend with
ordinary system Phoc/Mesa yields33.748FPS, frame p5033.333ms/p9549.964ms,
zero logged MDP underruns during the bounded recording. This alone does
not offload Phoc surfaces: Phoc0.46 does not submit output layers. Startup
includes EBUSY commits and a kernel rejection of a two-plane configuration.
The temporary session override was removed automatically. Evidence:
`0110-liftoff-backend`.

The MDP5 stage enum is one-based: BASE=1, STAGE0=2, up to STAGE6=8.
The current check rejects `cnt + start - 1 >= nb_stages`, although its
cursor path already assigns `nb_stages` itself as a valid stage. MSM8226
has nb_stages=2. Diagnostic patch0110 changes only this boundary to `>`;
it does not increase the hardware stage count.

VERIFIED_DEVICE before patch0110: `tools/mdp5-plane-check.c` issues only
atomic TEST_ONLY requests on the exact SM-T531 native msm-kms device.
One fullscreen plane is accepted; fullscreen base plus a second layer is
rejected with EINVAL; one half-width plane requiring border color is also
rejected with EINVAL. Three full-width planes fail ENOMEM (SMP allocation).
DRM state before/after is byte-identical. The GUI is stopped briefly with
an independent restart timer and restored successfully. Evidence:
`0110-plane-test-before`. After patch0110, both the two-plane and half-width single-plane requests
pass TEST_ONLY. Three full-width planes still fail ENOMEM. State remains
byte-identical; ordinary Phosh returns. Evidence: `0110-plane-test-after-valid`.
Module SHA25661f38733fb738c1d625ebe852a837beb240775b4d71636e7613b05692ed4cfca.
This proves atomic validation, not physical blending or an FPS improvement.

wlroots0.18 output layers support DMA-BUF buffers; Phosh's SHM surfaces
cannot simply be imported for scanout. Any SHM conversion must observe
wl_buffer release/lifetime, damage, scanout-in-use storage and fallback.
Reading a released SHM source later during rendering is unsafe. No such
unsafe copy or unverified plane offload is deployed.


## Output-layer experiments and additional blockers

An opt-in Phoc prototype captures eligible top/overlay SHM buffers at
`wl_surface.client_commit`, before upload/release, into a three-buffer
linear KMS pool. It matches the applied surface sequence and never writes
scanout-locked storage. It rejects subtrees, non-unit global alpha,
transforms/viewports, capture locks, visible software cursors, drag icons,
visible shields and cutouts. Normal GLES composition is retained in probe
mode. This is experimental, with whole-output damage and full SHM copies;
it is not installed as the ordinary compositor.

Host screenshot regression suites layer-shell, layer-shell-effects and
xdg-shell pass under Xvfb/Pixman (12 cases); the initial invocation without
an X server failed before creating a backend and is not a rendering result.
The opt-in feature also falls back on non-DRM outputs in host tests.

The first probe gives27.905FPS and no accepted output layers; a debug
repeat28.797FPS. These include extra CPU copies and conservative damage,
so they demonstrate no gain. Their bounded600-entry logs were exhausted
during startup, before the measured drawer animation; those logs alone
cannot classify every measured frame. Ordinary Phoc/Mesa were restored.
Evidence: `0110-output-layers-probe`, `0110-output-layers-debug-probe`.

VERIFIED_UPSTREAM/source: wlroots0.18.2 `output_basic_test` resets accepted
to false, but libliftoff updates it only after a real commit. This violates
the output-layer API's test_state contract. The same control flow exists
in the locally inspected0.20.2 release. Experimental wlroots patch0002
updates acceptance after a successful TEST_ONLY allocation, while keeping
feedback signals on actual commits. No global toolkit setting is changed.
A private release build with this fix, plus the earlier full-clear patch,
is isolated via the compositor's library path. First probe28.255FPS still
reports allocation failures; this fix alone has not enabled offload.

VERIFIED_UPSTREAM/source: MDP5 `mdp5_pipe_assign` returns ENOMEM when no
compatible hardware pipe is available and translates SMP ENOSPC to ENOMEM.
libliftoff0.5 `output_choose_layers` backtracks for EINVAL/ERANGE/ENOSPC,
but aborts for ENOMEM. Thus an over-capacity trial can abort the allocation
search before finding a valid smaller configuration. Patch0111 returns
ENOSPC for exhausted hardware pipes and preserves the SMP error; actual
allocation errors from global-state duplication remain unchanged. Hardware
limits and register programming do not change. VERIFIED_DEVICE after a normal reboot: the same
TEST_ONLY cases give accepted/accepted/ENOSPC/accepted, with identical DRM
state before/after and the ordinary GUI restored. Evidence: `0111-plane-test`.
Module SHA256542e4cc34c32f29507f1b4f4d749503cda68c7bc4b7b64d14db3b3a1dd5220fb.


## Native output-layer validation and remaining full-screen work

VERIFIED_DEVICE after0110/0111 and the private wlroots acceptance fix:
all153 recorded candidate frames in `0111-output-layers-probe` report
valid=1/accepted=1. Actual offload in `0111-output-layers-valid-offload`
uses DMA0+RGB0, plane_mask5 in45/45 state samples, six of seven SMP blocks.
Both requests and real commits succeed. Presentation remains29.107FPS
with zero logged MDP underruns: the initial prototype still adds a copy.
The first offload attempt aborted because an inhibitor unit name collided;
it has no accepted FPS measurement and ordinary Phoc was restored.

A second prototype replaces the owned pending SHM source with its completed
DMA-BUF snapshot, so EGL and KMS share that single copy. Buffer consumer
locks protect scanout; POLLOUT/reservation-fence readiness and paired
DMA_BUF_IOCTL_SYNC protect GPU readers surviving GL texture deletion.
Unknown formats or busy storage retain the normal source. Native KMS BO
import is checked independently by112 rendered-image checks across
RGBA/BGRA,257x131/1280x800, mixed/complete updates, prior GPU images in
flight, and28 varying-alpha checks. Tolerance is one channel level.
No framebuffer mode or system library is changed by those checks.
Evidence: `0111-kms-source-check`, `0111-kms-source-alpha-check`.

Primary reuse stores an exact conservative description of the lower scene
and a locked complete primary BO. It includes root lifetime, visual
generation, geometry, alpha, order and output geometry/filter. Captures,
visible cursors, views, subtrees, shields and cutouts retain ordinary
composition. Excluded hardware layers cannot cull pixels from this cached
underlay. A successful reused commit consumes damage; a future composition
repaints fully. Backend rejection disables offload and schedules fallback.

VERIFIED_DEVICE: initial primary reuse38.160FPS, opening about46 and
closing about31, zero logged underruns. Controlled same-process no-reuse /
reuse / no-reuse gives29.503 /41.582 /29.314FPS. The remaining cache misses
show unchanged visual content sequence but changing global alpha on the
full-screen `phosh top-panel background` surface. That change must be
rendered; ignoring it would alter the image.

Grouping every top/overlay root into a separate premultiplied ARGB GPU
buffer includes too many static roots and regresses to28.727FPS. A bounded
stack suffix of the two upper mapped roots, with a shared boundary in both
render passes and scene descriptors, gives42.768FPS (p5016.670ms,
p9533.416ms), zero logged underruns. Grouping does not inspect shell names
or change animations. A separate wlroots full replacement-clear extension
also handles transparent unblended full rectangles; components stay in
the normalized range. These remain isolated experiments, not production.

A bounded DSI0 MISR reader is implemented from the exact Samsung BSP
`mdss_debug.c`/`mdss_mdp_hwio.h`. It holds MDP runtime power, checks revision
1.1 and an unused counter, measures one frame, clears/restores the counter
and restores the prior power policy. VERIFIED_DEVICE: signature ready on
hardware revision0x10010001. It changes no timing, plane or operating clock.
Three hardware signatures per path are stable. For ordinary GLES texture /
verified solid-color GLES / direct MDP overlay / grouped GPU+MDP, respectively:

| Static case | Texture | Solid | Direct | Group |
| --- | ---: | ---: | ---: | ---: |
| Gradient and binary-alpha cutouts |1131474029|1131474029|1131474029|1131474029|
| Same, offset +23,+23 |1645420898|1645420898|1645420898|1645420898|
| Same, offset -37,-37 |1080015941|1080015941|1080015941|1080015941|
| Uniform opaque colors |3267749277|3267749277|3267749277|3267749277|
| Uniform fractional alpha |3183063101|3183063101|3064673459|3183063101|

Thus the tested grouped path matches the actual DSI pixel stream exactly,
including clipping in both directions and fractional alpha. The direct
fractional-alpha plane differs; rounding is a hypothesis, not a measured
explanation. This is not an optical panel/touch acceptance test. Evidence:
`0111-solid-shm-offload/crc`, native-plane-pattern/read-mdp5-misr tools.

The full-screen black background is an actual uniform client SHM surface.
Opt-in patch0008 recognizes uniform ARGB/XRGB pixels while the SHM source
is still owned, tracks the commit sequence, and renders the same clipped,
premultiplied solid color instead of sampling a full-screen texture. It
keeps the texture path for nonuniform or unknown buffers. Together with
the bounded group, presentation reaches50.065FPS (p5016.669ms,
p9533.350ms, p9950.011ms), opening56.6–58.3 and closing42.6–43.8FPS.
All250 GPU jobs retire, latency p5011.612/p9513.698ms; zero logged MDP
underruns. Twelve host screenshot regression cases pass with all opt-in
features enabled. Ordinary Phoc/Mesa are restored after the trial.

Stable60FPS remains unachieved. CPU preparation, repeated KMS validation,
client commits and frame scheduling still require timing measurements;
a GPU latency below16.7ms alone does not prove on-time presentation.


## CPU preparation and per-snapshot damage

VERIFIED_DEVICE: CPU-only phase logging in `0111-cpu-phases-offload`
reproduces50.413FPS. All250 drawn frames reuse the unchanged primary.
There are195 full4,096,000-byte copies of the changing top-panel SHM
surface:798.72MB in the recording. Snapshot preparation p504.624ms,
p955.601ms; post-copy surface application p500.152ms. Output preparation
p502.827/p953.631ms, including group submission p500.977ms and two KMS
tests p500.624ms. GPU submit-to-retire p5011.562/p9513.605ms. Zero logged
MDP underruns. These are measured phases, not additive independent costs.
Do not align the original perf default clock directly to GLib monotonic
timestamps; future traces explicitly use `--clockid mono`.

Opt-in patch0009 retains accumulated damage independently on each of the
three native snapshots until both consumer locks and reservation fences
permit rewriting. New storage is fully dirty; unknown/cached state history,
geometry/format changes, transforms and viewports retain full copies.
The source is read only before client release. Damage is valid relative to
the previous surface contents, not relative to a pool-buffer index.

A bounded client performs24 persistent partial updates, alternating surface
and buffer damage, including transparent pixels and an unchanged reattach.
It writes SHM only after wl_buffer.release. The final DSI signature is
726685171 in all three samples for each of full-copy GLES, partial-copy
GLES, partial-copy direct MDP, partial-copy grouped output and full-copy
grouped output. Logs confirm partial copies39,312/78,624/117,936 bytes,
so the optimization really executes. Twelve host screenshot cases pass.

The owner reported a broken image during the diagnostic-pattern period.
The test pattern itself was visible by design; physical corruption versus
the pattern remains unresolved. Ordinary Phoc was restored, then a normal
15-second drawer test gave33.215FPS, p9550.001ms.
No GPU lockup or logged MDP underrun occurred in that ordinary test.
The validation helper exited before its FPS phase, so there is no speed
result for patch0009 from that run. A second speed attempt also stopped
before recording because a pre-test screenshot used a root-owned directory;
its ordinary-session restore completed. Neither is an accepted FPS result.


The corrected speed trial `0111-snapshot-damage-speed2-offload` completes
50.667FPS, p5016.670/p9533.355ms, zero logged underruns. Full copies79,
p504.440/p955.005ms; partial copies112, p500.301/p950.364ms. Thus partial
copying executes and saves CPU time, but aggregate presentation does not
materially improve over50.413FPS. Separate sessions are not a controlled
ABA test. Closing remains43.8–45FPS. CLOCK_MONOTONIC is now explicit for
both phase logs and perf; GPU latency is lower during closing than opening,
so a fixed30Hz limit or uniformly slow GPU does not explain every gap.
The ordinary session is restored and unlocked after the trial.


## Distinguish GUI production from DRM presentations

VERIFIED_DEVICE `0111-gtk-frame-offload`: a CPU-only preload attaches GDK
before-paint/after-paint observers to the shell's frame clock. It changes
no drawing, animation or clock settings and uses no uprobes/GPU timestamps.
191 GTK frames are observed;50 exceed16.7ms of CPU time. Opening CPU
p9532.483ms; closing p9532.326ms. CPU sums
0.891s opening/0.964s closing; short frames below1ms alternate with expensive
ones. DRM still presents50.962FPS, so this is not a claim of51 distinct,
fully updated GUI frames per second. Slow client frames already miss the
budget before GPU composition. The observer and runtime service override
are removed; ordinary Phoc/Phosh return.

`0111-gui-cpu-offload` records583 cpu-clock:u samples at199Hz, zero lost.
Build-ID-matched Debian debug files identify the largest individual leaf
as Pixman combine_in_reverse_u (8.92% of both processes' sampled CPU time),
then NEON source fill7.38%, NEON over6.17%, NEON masked over4.12%, Cairo
scan conversion2.74% and spline decomposition2.57%. ARM call chains do not
reliably unwind beyond leaves here; no caller chain is inferred.

Pixman0.44.0 official archive SHA256
89a4c1e1e45e0b23dffe708202cb2eaffde0fe3727d7692b2e1739fec78a7dac
also matches its official SHA512. Inspection of the official0.46.4 release
finds no ARM NEON unified IN_REVERSE combiner either. A minimal candidate
adds that operation to the existing runtime NEON implementation. It keeps
masked-alpha rounding separate from destination multiplication. The
21,551,248-pixel dedicated test passes under ARM emulation with zero channel
tolerance, all byte/alpha/coverage values, tails, exact aliases and protected
pages. Actual device correctness and GUI performance are separate checks.
Sources: https://cairographics.org/releases/pixman-0.44.0.tar.gz and
https://cairographics.org/releases/pixman-0.46.4.tar.gz (retrieved2026-10-16).


The initial native combiner test also passes21,551,248 pixels exactly. A
CPU-only alternating scalar/NEON microbenchmark gives about55.6/32.6ms for
a1280x800 masked row. This does not describe GUI frame rate. PMU cycles per
task-clock independently give1.190GHz on CPU3 and1.186GHz on CPU1, so a
low actual core clock is not observed in these tests.

A controlled private DSO includes a startup selector absent from the public
patch. `0111-pixman-scalar-offload` versus `0111-pixman-neon-offload` uses
that same binary/compiler, switching only the IN_REVERSE combiner, in
separate sessions:48.721 versus50.285 DRM FPS, GTK CPU p9530.657 versus
28.662ms; median slow GTK frame29.252 versus27.937ms. This is a small gain,
not stable60FPS. Both return to ordinary Phoc/system Pixman. Upstream
combiner-test and pixel-test also pass on the private ARM build under QEMU.
A further uniform-alpha shortcut is an isolated, pixel-checked experiment;
its speed and broader GUI acceptance remain pending.


Bounded public Pixman API timing identifies the precise expensive call:
solid-source, unmasked IN_REVERSE of1280x252 ARGB, Cairo fill_boxes
(cairo-image-compositor.c:365).38 captured calls have CPU p508.611ms,
p959.400ms. The same-size OVER calls have p503.902/p954.523ms and ADD
p502.604/p953.227ms. The160-call cap excludes cheap calls; this is not a
full operation distribution. The exact Debian Cairo1.18.4 source confirms
fill_boxes creates a solid color image. Source retrieved2026-10-16:
https://sources.debian.org/data/main/c/cairo/1.18.4-1/src/cairo-image-compositor.c.

Patch Pixman0002 adds direct solid-opacity paths for the two32-bit alpha
formats, preserving clipping, stride and scalar rounding. Its public-API
test passes16,697,344 pixels exactly under QEMU and on the tablet, including
all65,536 source-alpha values, negative stride, clipping and guard pages.
Upstream combiner-test, pixel-test and alphamap pass under QEMU.

Identical private DSO, only the solid-path selector changes: fast49.634FPS
versus control49.667FPS, GTK CPU p9527.951 versus28.624ms, median slow frame
26.936 versus27.936ms. Native API microbenchmark2.35–2.36 versus2.84–2.87ms
per1280x252 operation. Thus there is a small CPU saving but no aggregate
FPS gain. The uniform-alpha shortcut experiment also gives no material gain
(50.499FPS, GTK p9528.993ms) and is excluded from the public series.

The grouped fractional-alpha CRC case composes over an opaque lower root
inside the foreground group. It proves that case's final DSI pixels, not
arbitrary hardware blending of a translucent foreground over the primary.
The direct fractional-alpha signature is decoded below; it remains a
specific-case result, not a complete hardware blending validation.

`0111-mdp-alpha-reference-offload` compares hardware DSI MISR signatures
with eight neighboring opaque RGB references, three identical readings
per case. The fractional case resolves to GPU RGB80/48/72 versus native
MDP RGB79/47/71, one level per channel. Black alpha128 over white gives
RGB127/127/127 on both paths; alpha64 gives191/191/191 on both. These
results identify the observed color discrepancy, but do not prove the
general hardware equation or optical panel correctness. They do not
explain the FPS plateau or previous blue flashes.

`0111-fold-clear-logged-aba-offload` explicitly enables verbose logging:
40 fold executions are confirmed, same compositor PID throughout.
Disabled/enabled/disabled presentation FPS50.877/50.619/50.554 and
submit-to-retire p5011.548/11.568/11.605ms show no material gain.
Keep the experimental wlroots0004 path disabled. Its separate exact
pixel checker passes5,120 cases/31,457,280 pixels, including40 logged
activations; correctness does not establish a performance benefit.

The clean Pixman public-series build uses O2 and generic ARMhf
VFPv3-D16; only its runtime-dispatched NEON object gets `-mfpu=neon`.
Meson probes C intrinsics and leaves existing assembly available if the
compiler cannot build them. Both dedicated checks pass under Cortex-A7
emulation and natively:21,551,248 and16,697,344 pixels, zero tolerance.
Upstream combiner-test, pixel-test and alphamap pass on this clean build
under emulation. SHA256:
1c5428eaa60a415b0cf55dba77aaa22cc887214961c1b2aed443df0cf6a404b2.
No system Pixman package is replaced. Earlier GUI control measurements
used a separate DSO with private startup selectors; they are not new GUI
measurements of this clean build.

Read-only cache-register observations and a dependent-load test on CPU1
andCPU3 now support functioning L1/L2 caches with normal active CPU rates;
see [MEMORY-BUS.md](MEMORY-BUS.md). This narrows the clock/cache hypothesis
for the tested states; it does not validate all power transitions.

## Repeat Plasma on the current native stack

VERIFIED_DEVICE `0111-plasma-current-kms2`: current0111 MSM, system Mesa,
KWin6.3.6/Qt6.8.2, no Phoc/Phosh process, no private Pixman/wlroots/Mesa.
The mobile shell is ready before sampling; a separate uinput swipe gives
`isActionDrawerOpen=true` then `false`. Four touch open/close cycles yield
27.202 DRM FPS, interval p5033.341/p9566.670ms, zero logged MDP underruns.
The15-second atomic trace is lossless: prepare-to-flush p500.107/p950.155ms,
flush-to-presentation p502.691/p9515.223ms;40 DRM-scheduler fence waits
have p5018.573/p9538.451ms. These waits include queueing/scheduling.

The simple fullscreen Qt square on the same KWin gives46.288FPS over the
central19-second window, interval p5016.671/p9533.341ms. GPU devfreq busy
fraction is99.959% during that window, at450MHz. This is below the earlier
accepted near60FPS native/direct-output test and must not be conflated with
it. KWin's baseline frame-path observer shows no CPU import swapchain,
shadow buffer or EGL import swapchain. The renderer is accelerated FD305,
desktop OpenGL3.1; Qt also selects desktop OpenGL3.1. Direct-scanout behavior
during the square still needs a live observation. Ordinary Phosh is restored
and unlocked afterwards, without a kernel change.

The first attempt `0111-plasma-current-kms` exits before profiling because
the mobile DBus object is not ready40seconds after session selection.
It is not an FPS measurement or proof that a desktop shell was selected.
The successful repeat waits for the actual mobile object. Initial startup
is excluded from accepted measurements.
