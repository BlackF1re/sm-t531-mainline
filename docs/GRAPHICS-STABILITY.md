# SM-T531 graphics stability investigation, 2026-10-17

## Acceptance status

**Latest installed snapshot:** kernel `#8` through patches 0118–0121,
with the unchanged 0116 MSM module. Image SHA256 is
`9d76269c14fb76cc9e171044532c417df3d78f43301a3fc57c1aba3ea00e7d92`.
Read-only checks on 2026-10-19 confirmed this kernel version, native Phoc
DRM ownership, the MSM module hash, Phosh 0.58.0-1~t5313 and battery export.
They are not new physical display, FPS or suspend tests. The latest retained
rollback pair is the pre-battery 0114 kernel with MSM 0116; the automatic
trial service is disabled. See [current recovery guidance](RECOVERY.md#graphics-fallback).

PARTIAL: native MDP5/DSI scanout and accelerated Adreno rendering work, but
the graphics stack is not yet reliable. Owner reports of frozen or missing
GUI are failures regardless of successful benchmarks. Performance experiments
are paused while boot handoff and failure recovery are investigated.

| Patch | Change |
| --- | --- |
| [0112](../patches/linux/0112-iommu-qcom-handle-unattached-context-faults.patch) | Handle an actual NULL-domain context fault without panicking |
| [0113](../patches/linux/0113-of-honor-managed-platform-dma-before-arm32-setup.patch) | Defer premature ARM32 platform DMA setup |
| [0114](../patches/linux/0114-drm-msm-mdp5-manage-display-dma-domain.patch) | Let MDP5 own attachment of its display domain |
| [0115](../patches/linux/0115-drm-msm-dsi-mask-MSM8226-video-blanking-FIFO-irqs.patch) | Mask measured blanking-only HS FIFO IRQ sources in MSM8226 video mode |
| [0116](../patches/linux/0116-drm-msm-mdp5-flush-interface-before-timing-engine.patch) | Upstream v4: flush the interface before starting its timing engine |

The ordinary Phoc fullscreen-square test reached 59.993 DRM presentations/s
over its central 19 seconds. Only the Qt client submitted GPU jobs in that
window, consistent with direct scanout. This does not establish 60 FPS for
composited interfaces or long-term stability. Typical ordinary Phosh panel
measurements remain about 33 FPS. See GRAPHICS-BOTTLENECK.md for the separate
CPU painting and GPU composition evidence.

## Preserved failure evidence

VERIFIED_DEVICE: before changes, bootstrap pstore and current/previous
journals were archived under `.work/phosh/recovery-20261017/`, with the
device originals copied to `/var/lib/t531/recovery-20261017-preserved`.
Pstore records a NULL dereference in `report_iommu_fault+0xc`, called by
`qcom_iommu_fault`, with r0=0 and fault address 0x03234a00. That address is
inside the firmware framebuffer reservation, 0x03200000–0x039fffff.

The saved panic's kernel build matches the installed pre-fix kernel, but
its association with the owner's most recent freeze is UNKNOWN. The last
long-running journal ends with an orderly shutdown. Do not equate this
specific boot panic with every observed GUI freeze.

## NULL-domain fault handling

Patch0112 reads `ctx->domain` once and only calls `report_iommu_fault` when
it is non-NULL. Fault logging, FSR acknowledgement and transaction termination
remain enabled. This fixes the observed NULL dereference; it does not prove
all domain-lifetime races are fixed.

VERIFIED_DEVICE: kernel build `#3 SMP Sat Oct 17 00:46:49 +07 2026` boots and
logs actual **Unattached context fault** messages during graphics activation.
These traverse the newly protected NULL-domain branch without a panic.
Phoc and Phosh start, SSH and USB console respond. The prior SD image is
restored by the trial service before graphics activation, with hash checks.
This is a meaningful on-device test of the guard, not just a clean build.

## Premature ARM32 DMA-domain attachment

VERIFIED_UPSTREAM (source inspection of the pinned kernel):
`of_dma_configure_id()` calls `arch_setup_dma_ops()`. With
CONFIG_ARM_DMA_USE_IOMMU, that creates and attaches an empty legacy
UNMANAGED domain before the MDP5 probe can stop firmware scanout.
IOMMU discovery can call platform DMA configuration even with no driver
bound. The later `driver_managed_dma` check in platform code cannot undo
those early hardware transactions. ARM32's core default domain is already
identity; setting global passthrough or adding another default-domain
identity preference does not solve the legacy attachment.

Patches0113/0114 preserve OF ranges, masks, coherency and IOMMU discovery,
but defer ARM32 DMA-ops installation until an ordinary DMA-API driver is
bound. MDP5 declares that it owns its DMA address space and attaches its
private translated domain after stopping firmware timing engines. Other
architectures and existing OF helper callers retain their previous path.
No permanent framebuffer identity mapping is added to the DRM address space.
These are project patches requiring upstream review; device acceptance is
recorded below from the actual trials.

VERIFIED_DEVICE: two successive candidate boots of kernel `#5 SMP Sat Oct
17 01:02:17 +07 2026`, with the candidate MSM module, start ordinary system
Phoc/Phosh on native card1 and renderD128. Both saved kernel journals contain
**zero context faults**, compared with ten rate-limited NULL-domain messages
in the preceding guard-only boot. Imported XR24/5120-byte-pitch DMA-BUF
scanout through DMA0 remains active. Eight injected open/close cycles complete
without a logged GPU hang, IOMMU fault, panic or vblank timeout. A subsequent
held-open/held-closed pair of software screenshots confirms actual panel and
desktop state changes. Earlier short screenshots happened between transitions;
the first two injection attempts failed because uinput was absent and are
not accepted tests. None of these screenshots establishes physical LCD or
touch acceptance.

The fix is now installed on SD and in the persistent MSM module. Container
SHA256: `c0c83d66678d784a358d90ad30e36163d0b4aa6f4c1d84c49ae9b32e494a4390`;
MSM SHA256: `c3ff1917d724ef997443310f68dc628307d9b28a88e1df3815b020c9c5443e32`.
DTB, initramfs and command line are unchanged. The retained rollback pair is
the guard-only kernel0112 and MSM0111, not the earlier panic-prone kernel.
That describes the0114 promotion; the later0115 rollback snapshot is listed
below.

## DSI error investigation, still open

VERIFIED_DEVICE: `tools/read-dsi-controller.c` reads only a fixed controller
register list with the DSI runtime active. It excludes PHY/PLL and protected
global registers. In the second candidate boot its live snapshot finds FIFO
0x00001000, while IRQ-time diagnostic snapshots repeatedly find0x99991000
(HS FIFO underflow flags). Thus the flags are not permanently set at every
instant. Do not infer from a later clean read that the IRQ records are false.

The earlier working bootloader-owned/simplefb baseline has identical CTRL,
video configuration, active timing and lane-control values for the sampled
registers. Its error mask is0x7fff3bff versus native0x13ff3be0. The native
mask leaves HS FIFO-underflow sources unmasked; the baseline masks them.
The baseline is a captured working firmware-owned display, not a captured
Android SurfaceFlinger session. Later Qualcomm source documents HS FIFO
underflow mask bits26,27,29,30; see the authoritative
[Qualcomm DSI controller implementation](https://android.googlesource.com/kernel/msm/+/1e5081e1b29bfbd508533677454a3c2f7cc63702%5E2..1e5081e1b29bfbd508533677454a3c2f7cc63702/).
Whether these events occur solely in blanking or affect payload delivery is
tested next against the actual MDP5 line counter.

VERIFIED_DEVICE: a five-second,20,000-sample read-only observation of FIFO
flags and INTF1 LINE_COUNT finds 17,816 active-line samples with zero HS
FIFO-underflow flags. All300 observed0→1 transitions occur in vertical
blanking, at approximately one event per60Hz frame. A second observation
with the panel held open finds17,824 active samples with zero such flags
and299 new transitions in blanking. The second observation also records
the actual timing registers: HTOTAL1378, VSYNC_PERIOD1237444,
DISPLAY_VSTART90948 and DISPLAY_VEND1193347. The raw one-based active-line
range is67–866; the total is898lines. The histogram is sampled, not an
exhaustive IRQ-time trace or proof about every future transfer.

Patch0115 adds a video-mode error-mask field to the DSI SoC configuration.
Only MSM8226 masks the four HS-lane underflow IRQ sources in video mode;
other controllers and command mode retain their existing mask. This matches
the working firmware-owned display for these bits. Other ACK, PHY, PLL,
timeout, command/MDP and video/MDP error-mask bits are unchanged. FIFO status,
video timing and actual data transfer are unchanged. The fault flags can
remain latched after this change; a raw later FIFO read is not a count of
new faults unless the flags have been acknowledged. This distinction is
essential when interpreting the sampling tool after IRQ masking.

The baseline before this patch measures1219.289 DSI IRQ/s over19.976s,
with four normal panel cycles and ordinary system Phoc/Phosh. Aggregate CPU
busy fraction is4.106% across all cores, excluding idle and iowait.
VERIFIED_DEVICE: the candidate with the same four-cycle workload records
**zero DSI IRQs over20.116seconds**, compared with24,357 over19.976seconds
before. Aggregate CPU busy fraction is2.852% afterwards. CPU governors are
unchanged, with observed CPU rates998.4/1094.4/1190.4MHz in both samples;
GPU frequency varies within its normal range. These short samples support
elimination of the interrupt storm; they do not isolate every CPU-cost
difference or establish a new GUI FPS result. Native MDP presentations and
open/closed software screenshots continue working; the candidate journal
contains no IOMMU fault, DSI error-worker message, GPU hang/recovery or panic.
The live mask reads0x7fff3be0 as expected. Other controller/timing values
remain unchanged in the sampled register set.

Important condition found in the subsequent audit: both IRQ/CPU comparison
samples had the pre-existing GNOME `enable-animations=false` setting. It is
restored to **true**, in accordance with the owner's requirement to retain
animations. Eight further panel open/close cycles with animations enabled
complete without a logged IOMMU/DSI error, MDP underrun, GPU hang/recovery,
panic or vblank timeout. A preceding32-cycle persistent-module test is also
clean, but was before this setting was restored. No new FPS comparison is
claimed from either test. The final session uses normal system Phoc/Mesa
with the existing `FD_MESA_DEBUG=inorder` correctness workaround, without a
private Mesa/wlroots/Pixman preload. Inorder and the diagnostic GPU runtime
power hold remain release limitations, not solved mechanisms.

MSM0115 SHA256:
`ba2eb19923cf5210ed67b2d7e9090667c7c641a2e6a9232fa51190562c92dd2d`.
It is installed persistently after its one-boot trial; the SD kernel remains
the same0114 image. The current `kernel-trial-backup` contains that kernel
and MSM0114 for rollback. The earlier guard-only rollback is retained in
`/var/lib/t531/kernel-trial-0114-backup`.
The subsequent boot with the persistent module also starts Phoc/Phosh on
native KMS successfully; the repeat and animation-enabled tests above are
from that boot. Source matches the full recorded patch series through0115.
Kernel/module builds pass; patches0112–0115 pass checkpatch without errors
or warnings. The initial single-module modpost attempt lacked dependency
symbols and is rejected; the complete incremental modules build passes.

## Recovery and remaining limits

### Additional white-window failure

VERIFIED_DEVICE: the final software screenshot after the initial acceptance
loop unexpectedly shows a white full-output content area with a functioning
top bar. X11 inspection identifies a1280x753+0+32 `Wayland to X Recording
bridge` window owned by xwaylandvideobridge. Terminating that exact helper
returns the app grid and changes OverviewActive from false to true without
resetting Phoc, the GPU or the kernel. This episode is separate from kernel
hangs and not evidence that the IOMMU/IRQ fixes failed.

The helper's [v0.4.0 source](https://raw.githubusercontent.com/KDE/xwaylandvideobridge/v0.4.0/src/contentswindow.cpp)
sets its window opacity to zero and relies on window-manager handling of
that property. Researched Phoc0.46 source returns opacity1 when the optional
wlroots XWayland-opacity extension is absent. Its autostart entry was active
in the Phosh session. A per-user desktop-entry override now excludes
**only Phosh** with NotShowIn=Phosh; package files and XWayland support are
retained. The override is installed by select-mobile-shell.sh for repeatable
session selection. After a fresh session start the helper is absent and a
normal app grid is captured, with animations still enabled. This is a
session-integration workaround for the current compositor combination,
not an implementation of that optional opacity extension.

### MDP restart underrun: still present in0115

Correction to the initial broad health assessment: the full0115 journal
contains native MDP errors04000000 outside the bounded panel-test windows.
They decode as INTF1 underruns. Recorded times33.836347,622.062891 and
1252.108438 coincide with mode activation; a controlled Phosh PowerSaveMode
off/on cycle reproduces another at1379.654400. A lossless perf recording
includes atomic-tail, flush and printk events for that cycle. The panel
cycles having no new logged underrun does **not** mean the whole boot is
underrun-free.

Samsung's pinned BSP specifies seven4096-byte SMP blocks, matching our
MSM8226 hardware configuration; its FIFO watermark calculation also matches
the quarter/half/three-quarter policy. No speculative SMP-size change is
made. The vendor display-commit path writes CTL_FLUSH before the interface
starts its timing engine.

Patch0116 is the standalone upstream v4 04/10 by Dmitry Baryshkov:
[original message](https://lists.openwall.net/linux-kernel/2026/10/03/60),
Message-ID `20261003-fd-kms-fix-smmu-v4-4-2a44d4d8ac77@oss.qualcomm.com`.
It moves the INTF flush ahead of TIMING_ENGINE_EN to avoid a first-frame
fetch through stale pipe settings. Author, date, Fixes, Assisted-by and
Signed-off-by metadata are preserved. As checked2026-10-17, current mainline
and linux-next still have the previous order; searches found no newer
revision. This remains a **temporary unmerged upstream patch**, requiring
merge/revision recheck. Its code is applied unchanged; three checkpatch
warnings concern the original log-line length, the original Assisted-by
format and the unavailable historical Fixes commit in the shallow tree.
There are no checkpatch errors. A device trial with a next-boot module
fallback follows the same power-cycle reproducer.

VERIFIED_DEVICE: the0116 candidate module boots without the initial INTF1
underrun. The original single power-off/on test and four additional cycles
then complete with **zero logged MDP underruns**, zero IOMMU context faults,
zero DSI error-worker messages and no GPU hang/recovery/panic. The second
recording explicitly rejects lost trace events and uses a kernel marker for
the error window. This is a before/after improvement for the tested mode
enable sequence; it is not an optical panel acceptance or long-term GPU test.

| Test |0115 |0116 |
| --- | --- | --- |
| Initial native mode activation | INTF1 underrun | No logged underrun |
| One Phosh PowerSaveMode3→0 cycle | INTF1 underrun | No logged underrun |
| Four additional power cycles | Not sampled as a group | No logged underrun |

`scripts/check-display-power-cycle.sh NEW_DIRECTORY [1..4]` reproduces the
normal Phosh display-power route with a bounded recording and an independent
power-on restoration timer. It does not suspend Linux or unload MSM.
The timer cannot recover a wedged kernel or a vanished session bus.

0116 MSM SHA256:
`8f6a70bd3350add8a427263706952dc0fb04820e5f88fe5a54ec596c6351fa6f`.
After the trial it is installed persistently, with the unchanged0114 SD
kernel. At that 0116 promotion, kernel-trial-backup retained MSM0115 and that same kernel
for rollback; older snapshots remain in kernel-trial-0115-backup and
kernel-trial-0114-backup.

VERIFIED_DEVICE after persistent promotion: ordinary boot again starts
Phoc/Phosh on native MDP5, with the expected module hash, animations enabled
and the incompatible XWayland helper absent. Four further normal display
power cycles record zero MDP underruns; the full saved kernel log has no
IOMMU context fault, DSI error worker or GPU hang. A screenshot shows a
rendered Phosh lock screen, not physical LCD acceptance. The boot also
contains one naturally occurring s2idle interval. At observation, BOOTTIME
was45601.67s but MONOTONIC only1672.37s: this is **not** a twelve-hour active
load/stability run. That one resume does not validate repeated suspend or
complete display power management. Lossless power-cycle traces are archived
privately in `.work/phosh/recovery-20261017-0116-stability.tar.gz`.

`scripts/trial-graphics-kernel.sh` only writes the verified 48 MiB SD boot
partition /dev/mmcblk1p1 (T531_BOOT), preserving its previous boot files and
checksums. The next candidate boot restores the previous kernel on disk
before starting graphics. An optional MSM candidate is bind-mounted over
the original module for that boot; the persistent original remains intact
and the mount disappears on reset. No live MSM unload is used.

This protects the next boot after rootfs reaches the restoration service;
it is not a watchdog and does not recover an early boot failure automatically.
Internal boot, lk2nd and bootstrap recovery remain unchanged.

After promotion, the installed helper supports an explicit rollback without
unloading the running driver:

```sh
sudo /usr/local/libexec/t531-kernel-trial-restore --rollback
sudo systemctl reboot
```

This restores the verified saved image and MSM module for the next boot.
Keep `/var/lib/t531/kernel-trial-backup` intact. The trial service is disabled
after promotion.

Still unresolved: historical GPU/IRQ hangs, complete display power/suspend
integration, and repeated physical boot/display acceptance. Eliminating
blanking-triggered IRQs does not by itself validate link signal integrity
under all operating conditions. Read-only CPU/cache, DDR and bus clock
measurements are in MEMORY-BUS.md; they are not proof that every power state
is correct. No overclock is applied.


### Bounded GPU runtime resume check on0116

VERIFIED_DEVICE: a temporary `power/control=auto` check runs twelve separate
32x32 FD305 rendering processes, each checking twelve rendered pixel cases.
Eleven pre-render samples find the GPU suspended and one finds it active;
the lossless trace contains sixteen suspend/resume pairs, including normal
compositor activity. All144 cases complete with no logged graphics fault.
An independent timer and EXIT cleanup restore the previous diagnostic
`on` policy. The tiny-workload throughput is not a UI FPS measurement.
This confirms actual runtime transitions in this bounded test, without
intentional GPU faults; it does not prove intermittent hang recovery or
justify declaring long-term power management complete.

`profile-graphics.sh` now also derives its kernel error boundary from a
unique printk marker after resume and rejects lost perf events. The drawer
and display-power profilers already use those safeguards. `/proc/uptime`
would otherwise skip real errors after a long suspend because it includes
sleep time while printk timestamps do not.
