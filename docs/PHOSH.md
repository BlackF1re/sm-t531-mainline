# Native Phosh on SM-T531

> [!NOTE]
> **Installed package:** Phosh `0.58.0-1~t5313`, Phoc `0.46.0-1`, Mesa `25.0.7-2+deb13u1`, rechecked read-only on 2026-10-19. The t5313 package fixes the absent-light-sensor brightness regression; see [Backlight](BACKLIGHT.md). The t5311/t5312 discussion below is historical. Kernel/device acceptance is tracked in [Graphics stability](GRAPHICS-STABILITY.md).

## Sources and packaging (2026-10-15)

VERIFIED_UPSTREAM, as checked 2026-10-15: Phosh 0.58.0 was the latest stable release in the
[official release directory](https://sources.phosh.mobi/releases/phosh/),
published 2026-10-04. Debian 13's pinned repository provides 0.46.0.
`scripts/build-phosh.sh` rebuilds the upstream tarball with Debian's
0.58.0-1 packaging against an isolated copy of the ARM Debian 13 rootfs.
Both archives have pinned SHA256 checksums. Debian's patches, licensing
and authorship are preserved; the build package manifest is retained.
The deployed runtime uses an explicit, checksum-locked set of 19 Debian
snapshot packages in `config/phosh-runtime.lock.json`: GNOME settings daemon
49.1, GNOME session 49.2, shell schemas 49.5, desktop schemas 49.1,
GTK 4.20.3, GLib 2.86.3, Wayland 1.24, matching PyGObject/GIR, and the
Phosh portal 0.58 dependencies. This is a targeted runtime update; the
kernel, Mesa, libc and Plasma packages are retained. The first installation
removed incompatible old GNOME components; these were restored/upgraded
as a coherent set. Subsequent installations use `apt-get --no-remove`.
`dpkg --audit` and `apt-get check` pass after deployment and after reboot.
`tools/fetch-phosh-runtime.py` verifies package metadata and SHA256;
`scripts/install-phosh.sh` automates the no-removal deployment. The script
passes syntax checks; the equivalent individual deployment steps, rather
than the complete installer invocation, were exercised on this device.

The initial 0.58.0-1~t5311 packages compile and install, but are REGRESSION:
startup SIGTRAP is caused by an unconditional read of the GNOME 49
`org.gnome.shell.keybindings::screen-brightness-up` key on GNOME 48.
The failure is recorded by journal/coredump, not attributed to the GPU.
The t5312 backport checks for the four new shortcut keys before taking
over shortcut registration. With the old schema, the existing GNOME
settings daemon retains that role. Backlight/slider/D-Bus initialization
is independent and remains enabled. The actual deployed runtime now uses
GNOME 49 schemas/settings daemon, respecting upstream package conflicts.
Phosh 0.58.0-1~t5312 starts after a clean reboot; the owner reports a working
interface and a perceived improvement in smoothness. This does not establish
complete acceptance of every settings/portal function.

Phoc remains Debian 13's 0.46.0-1 for this shell comparison. Phosh's Debian
runtime dependency is Phoc >=0.45.0. This is **not** a claim that the
compositor has been upgraded to Phoc 0.58: that newer release needs newer
wlroots and libdrm, which have not been installed. Wayland was upgraded for
the GTK runtime dependency, independently of the compositor version.

## Session selection and recovery

`scripts/select-mobile-shell.sh phosh` selects the native Phosh session;
`scripts/select-mobile-shell.sh plasma` selects the retained Plasma session.
Copy `scripts/`, `config/` and the installed diagnostics into their usual
`/opt/t531-graphics-test` tree before running on-device. The switch only
terminates t531's local seat0 session and waits for its compositor to exit.
SSH and USB recovery are preserved. SDDM/native activation remains the
boot path; the kernel, internal BOOT/lk2nd and SD boot image are unchanged
by the shell switch. Session configuration/package manifests are backed up
in `/var/lib/t531/mobile-shell-backup` (earlier manual switch backup is in
`/var/lib/t531/phosh-switch-backup`). No automatic graphics fallback is added.

VERIFIED_DEVICE: SDDM filters the display manager's service environment.
Putting WLR variables only in an SDDM service drop-in did **not** pass them
to Phoc, although GNOME's user-service Phosh inherited the global Mesa
workaround. `scripts/phosh-session.sh` exports the device/renderer settings
inside the session, before starting Phoc; its live environment is verified:

```
WLR_DRM_DEVICES=/dev/dri/by-path/platform-fd900100.display-controller-card
WLR_RENDER_DRM_DEVICE=/dev/dri/by-path/platform-fdb00000.gpu-render
WLR_RENDERER=gles2
FD_MESA_DEBUG=inorder
```

Phoc reports Freedreno FD305/OpenGL ES 3.0, opens native card1 plus
renderD128, and scans an imported linear XR24 DMA-BUF at pitch5120 through
MDP5 DMA0. CONFIG_DRM_SIMPLEDRM remains disabled. The legacy simplefb console
is only used before native takeover, as documented in NATIVE-KMS.md.
Phosh 0.46 was physically observed, with touch/desktop working but laggy;
one earlier physical freeze required recovery and has no matching new
panic record. Do not call the whole stack stable based on a session launch.

## Profiling corrections

The profilers now detect the active KWin **or** Phoc descriptors, reject
concurrent recordings using a shared flock, and require an unlocked local
Wayland session before/after recording. CPU snapshots include Phoc/Phosh.
The overlap-rejection test passes without creating a recording directory.

Initial Phosh automatic swipes are **INVALID as notification-drawer FPS**.
Screen captures show a PIN lock screen; later unlock also rotates the output
from landscape to portrait. A virtual touch device using fixed landscape
coordinates therefore cannot establish which panel was animated. The
27.31,13.37,29.41FPS runs and the 320/450MHz comparison (24.55/29.52FPS)
must not be used as a desktop-drawer or cross-shell speedup claim. The latter
does verify the requested 320MHz core/266.67MHz AXI during its recording,
but the animated surface is not established. Original min/max GPU policy
19000000/450000000 is restored; no overclock or memory-voltage change occurs.

Two early square recordings have insufficient visible presentations and
are INVALID. Neither their event gaps nor background-client rendering are
interface FPS. Future gesture comparisons require an unlocked screen,
known/held orientation, confirmed visible drawer movement and the actual
native path guard. A3xx all-zero raw counter prototypes also remain INVALID;
they are not shader/memory evidence and are not installed as services.

The accepted native Plasma drawer baseline remains about26.9FPS with
p95 around50ms. Stable60FPS for the full interface remains unmet.

## Unlocked manual drawer recording, 2026-10-15

VERIFIED_DEVICE: a new 15-second recording on Phosh 0.58.0-1~t5312 / Phoc
0.46 uses the same native MDP5 path, session c2 unlocked before/after, and
unchanged compositor PID494. Before recording, process inspection found no
KWin, Plasma, QML benchmark or glmark client. Residual KDE autostarts
`kclockd`, `kdeconnectd`, `calindac`, `xwaylandvideobridge` and the unused
XWayland server were terminated; the post-recording process list confirms
their absence. Normal GNOME services and portals remain. No screenshot,
synthetic input or second graphics benchmark runs during the measurement.
The user was instructed to repeatedly open/close the drawer during recording.

Native DRM presentation bursts contain 184 intervals: **30.835 FPS**, median
33.336ms, p95 33.346ms, p99 33.363ms; 94.02% of intervals exceed 25ms.
Two bursts last 4.967s and 1.000s. The 100ms idle-gap rule excludes pauses
and can also exclude severe jank; these are presentation timings, not optical
FPS or a directly comparable controlled Plasma workload. CPU is 9.43% of
all cores and GPU busy 74.75% over the whole recording, including pauses.
Median GPU/CPU/AXI rates are 450MHz / 1.1904GHz / 266.67MHz.

All 192 traced GPU submissions come from Phoc TID494; no other submitter is
observed. Submit-to-retire latency has median 25.8505ms and p95 28.298ms,
with no unretired job at recording end. Up to two traced jobs overlap.
172 of 185 consecutive presentation sequence differences are two vblanks
(11 are one; one is three; one idle gap is 42). This supports missed
16.67ms presentation deadlines in the compositor/GPU path. Submit-to-retire
includes queueing and retirement scheduling, so it does not isolate shader
execution, memory bandwidth, fences or the responsible Mesa operation.
No GPU/kernel fault or OOM was detected during recording. Stable 60FPS and
the exact underlying graphics bottleneck remain unresolved.

Raw device evidence: `/var/lib/t531/phosh058-clean-manual15/`; durable
numeric evidence: `docs/phosh-drawer-results.json`. Temporary idle/suspend
inhibition was stopped after recording. No clock policy was changed.

Further GPU/core-clock, composition, VBIF underrun and freeze evidence is in
[GRAPHICS-BOTTLENECK.md](GRAPHICS-BOTTLENECK.md).
