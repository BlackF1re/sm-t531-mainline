# Unified Adreno / MDP5 graphics

The main build supports one production architecture: Adreno 305 and MDP5 in
one MSM DRM device (`separate_gpu_kms=0`). The simple framebuffer is retained
only for the bootstrap/early boot console. SSH starts before graphics.

## Implementation and evidence

Linux v7.2.9 is pinned to `5fce161649b4d779d1b76d9fcd52dc77779774b8`.
Patches 0126–0129 fix component teardown ownership, register MSM's existing
self-import callback consistently, and backport the shared GPU VM lifetime
fixes. GPU platform drvdata is Adreno SMMU state, not DRM private data.
A305 uses a global GPU VM: closing an imported handle previously invalidated
another client's live mapping. The two-client reproducer demonstrated an IOVA
changing from `0x1009000` to `0x100a000`; after the fix it remains `0x1009000`.
The filler object instead receives `0x100a000`. No zeroing, cache maintenance,
fences or validation have been disabled.

The shared VM backports preserve upstream authorship and Message-IDs:

- https://lore.kernel.org/r/20260822-msm-fix-export-v1-1-917b3cbedd43@oss.qualcomm.com
- https://lore.kernel.org/r/20260822-msm-fix-export-v1-2-917b3cbedd43@oss.qualcomm.com

Split registration originally permitted standalone GPU bring-up with firmware
framebuffer scanout. Native display later retained that choice unnecessarily.
One DRM device still uses separate GPU/display IOMMU address spaces. Existing
board power, SMMU, TrustZone, PHY and TC358764 fixes remain necessary.

**VERIFIED_DEVICE, 2026-10-29:** `7.2.9-t531-unified2-dirty` exposes a single
MSM card and matching render node, hardware Freedreno FD305 OpenGL ES, atomic
1280×800 at 59.999 Hz, and active primary/overlay MDP planes. The owner confirmed
working image, text and touch. This is functional validation, not a claim of
flawless long-term operation or completed cold-boot acceptance.

| Measurement | Previous split evidence | Unified device measurement |
|---|---:|---:|
| Expensive PRIME class median | 6.2 ms | card 0.017 ms; render 0.014 ms |
| PRIME maximum in 22 s | — | 0.081 ms |
| KWin main-thread page allocations | 615,243 / 20 s | 275 / 22 s |

The unified trace contains 2,113 successful PRIME ioctls; these are inexpensive
shared-object lookups, not eliminated API calls. The old allocation-to-import
association was a hypothesis; the measured allocation collapse is established.

The historical packaged-plugin measurement was 35.52 FPS (p95 33.412 ms).
The cache was subsequently restored and promoted into the main source series:
controlled original / cache / original measurements were 35.026 / 51.432 /
34.735 presentations/s. The canonical stack measured 51.251/s after boot and
50.732/s after s2idle/RPM sleep. See [the current stack](GRAPHICS-STACK.md).
These DRM event rates do not establish optical FPS or stable 60 FPS.

One subsequent `ksplashqml` GPU hang recovered; its cause remains UNKNOWN.
Two session restarts with runtime power on and two with runtime autosuspend
passed afterward. These short checks do not establish long-term stability.
MDP5's seven 4-KiB SMP blocks cannot accommodate three fullscreen RGBA planes
requiring nine blocks; rejected overlay candidates must still be composited.
Resource checks and their diagnostics remain enabled.

## Supported configuration and removed debt

`config/msm.conf` is the sole module topology/PHY setting. Activation discovers
one device by capabilities and stable sysfs identity, not card numbers.
Mesa/GBM use normal device discovery. The split-only Mesa loader shim and
simpledrm desktop helper are removed. Old in-place trial/restore writers are
replaced by the verified slot controller. Canonical graphics environment and
KWin drop-in replace duplicated diagnostic overrides; permanent forced GPU
runtime power is unnecessary. Existing generic Qt depth/stencil and Mesa buffer
layout fixes remain independent requirements, not shell animation tweaks.

An on-demand udev/systemd GPU coredump collector preserves up to three private
32-MiB dumps. It has no polling daemon. Recovery and the early framebuffer
console are retained deliberately.

## Build, deploy and recovery

Build with `make build` (optionally `SD_ONLY=1`); `NATIVE_KMS=0` is rejected for
the main profile. Bootstrap is a separate immutable profile. To compile the
query/reproducer tools use `scripts/graphics/build-probe.sh` with `DRM_SYSROOT`.
Run `python3 -m unittest discover -s tests -p 'test_graphics_slots.py'` for host
slot tests. Device probes and `tools/auto-drawer.py` provide repeatable checks.

Before deployment, run `scripts/graphics/snapshot.sh` on the tablet. Preserve
its checksum-verified SD files, complete modules, configuration and absence
manifest. `scripts/graphics/ab.sh prepare` stages a uniquely named kernel release
and immutable trial slot. Consult the script's usage for arguments. The early
guard selects the golden next boot before graphics and arms a fifteen-minute
rollback. `confirm-session` stops the timer but does not promote; `promote`
stages the production slot. `confirm-boot` accepts an actual production boot.
`confirm-primary` can select the verified running candidate without falsely
claiming cold-boot acceptance. `recover` restores the verified baseline;
`restore-native-from-bootstrap.sh` selects golden from the rescue shell.

Only `/dev/mmcblk1p1` with the verified label and size is writable by this
controller. Internal eMMC is never a target. Slot selection is atomic and host
tests cover interruption, corruption and retirement with verified backups.
Responsive-device rollback was tested; a hard kernel hang can still require
physical recovery. Never delete golden or the baseline while acceptance is
pending.

The earlier publication ended before unified2 promotion; that observation is
historical. The current `7.2.9-t531-mainline-dirty` image
`d476c3fb1032590d31285e49c468301f1ff8619abf75af1dc9af47e65d6cfe85`
booted from microSD, passed the recorded short checks and was persistently
selected as `mainline-d476c3fb1032`. Its pending marker was removed. Legacy
one-off trial boot guards were retired; the generic verified SD recovery
mechanism and golden slot remain. See [OCMEM qualification](OCMEM-RESUME-20261103.md)
and [the consolidation audit](graphics-stack-audit-20261103.json). This is
bounded functional acceptance, not long-term reliability or whole-SoC sleep
acceptance.
