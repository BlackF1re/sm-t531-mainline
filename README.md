# Samsung Galaxy Tab 4 SM-T531 mainline Linux

Native ARMv7 Linux for `matisse3g` (MSM8226, four Cortex-A7 cores, Adreno 305B).
Debian armhf runs from microSD. Android userspace is not a runtime dependency.
This is a hardware bring-up port, not a validated daily-use system. Modem and
cameras are outside the current scope; Bluetooth and audio follow stability.

## Fixed inputs and hardware evidence

| Input | Pinned revision |
|---|---|
| [Linux stable](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tag/?h=v7.2.9) | `v7.2.9`, `5fce161649b4d779d1b76d9fcd52dc77779774b8` |
| [lk2nd](https://github.com/msm8916-mainline/lk2nd/releases/tag/23.1) | `23.1`, `e9c8b21735c13dd7ace808b1e35451638f0a0c6d`, unmodified |
| [Samsung downstream](https://github.com/LineageOS/android_kernel_samsung_msm8226/tree/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256) | `3fa1853ed5d6c3a8ef5a2fda9822705243bbc256`, hardware research only |
| [matisse3g product configuration](https://github.com/matissewifi/android_device_samsung_matisse3g/tree/cf5a3b04f9598d6756113b79df64e91aa53868d9) | `cf5a3b04f9598d6756113b79df64e91aa53868d9` |
| [Debian snapshot](https://snapshot.debian.org/archive/debian/20261003T000000Z/) | Debian 13.7 trixie armhf, `20261003T000000Z` |
| Static BusyBox / kexec-tools | Debian `1:1.37.0-6+b9` armhf / upstream `2.0.29` |

Sources checked 2026-10-13. Host builds use ARM GCC 15.2.0 and binutils 2.46.
Linux is GPL-2.0-only; retained upstream DTS licensing and authorship are
preserved. The downstream kernel is not copied into this repository.
Related Matisse Wi-Fi/LTE and MSM8916 Matisse VE ports do not establish wiring.

The connected device reports SM-T531, MSM8226 SoC ID 158 revision 2.0,
`[MATISSE-3G-OPEN] Rev-02-MTP-v2`, and stock CPU frequencies
300/384/600/787.2/998.4/1094.4/1190.4 MHz. Its backed-up Android installation
is rooted Dirty Unicorns Android 6.0.1, not a proven factory image.
Confirmed wiring includes maXTouch 1188S on I2C5, GPIO17 IRQ, GPIO31/73 power
and PM8226 GPIO6 reset; TC358764 DSI/LVDS and LP8556 backlight; SM5502 MUIC;
SMB358 charger; SDC1 eMMC and SDC2 microSD with PM8226 L18/L21 and GPIO38
card detect. WCNSS firmware and factory calibration come from this device.
Raw DT, identifiers, credentials, firmware, unsanitized logs and all partition
backups remain outside Git under `/home/paul/t531/private/`.

## Build and deployment

Install Git, Make, GCC, `gcc-arm-linux-gnueabihf`, binutils, bison, flex,
libssl-dev, libelf-dev, bc, Python 3, dtc, cpio, gzip, curl, e2fsprogs,
`mkbootimg`, debootstrap, the Debian keyring and static QEMU ARM with binfmt.
`qemu-arm` must execute armhf binaries.

```sh
make build
ROOTFS_PROFILE=mobile make rootfs
# On a positively identified, mounted card:
make deploy-sd BOOT_MODE=internal BOOT_MOUNT=/mounted/card-boot
sudo tar --numeric-owner -xpf .work/artifacts/current/debian-armhf.tar.gz \
    -C /mounted/card-root
```

The build pins Linux, checks its source state, applies ordered format-patch
files, merges `config/kernel.fragment` into `multi_v7_defconfig`, and builds
out of tree. `.work/linux`, `.work/out` and `.work/artifacts/current` are the
single ignored source, build and current artifact directories. Patches reuse
upstream drivers; driver changes and board limitations are documented below.
Build timestamp, user/host and initramfs ordering are fixed. Downloads are
SHA-256 checked. Rootfs inputs use signed Debian snapshots; generated rootfs
state is not claimed byte-reproducible. Compiler versions matter too.

Outputs include genuine `zImage`, SM-T531 DTB, diagnostic initramfs, modules,
`kernel.config`, `sd-kernel.img`, checksums and Debian package manifest.
The installed bootstrap expects the Android-v0 `sd-kernel.img` container under
the card filename `zImage`; the host artifact `zImage` remains the real kernel.
The container carries an appended updated DT, verified RAM banks and initrd
placement at `0x04008000`. Its checksum manifest checks exactly the installed
kernel container and initramfs. Updating the SD kernel never requires updating
the internal bootstrap DT.

The identified 16 GB card has 30253056 sectors, a 48 MiB ext2 `T531_BOOT`
partition and an ext4 `T531_ROOT` partition. Keep SD `/extlinux/extlinux.conf`
absent when using the internal bootstrap: lk2nd otherwise prefers the card
entry. `BOOT_MODE=internal` refuses an active SD extlinux entry. Standalone SD
boot remains available with `BOOT_MODE=sd`. The initramfs waits for the root
label, mounts ext4 and switches to Debian, with USB ACM diagnostic fallback.

The mobile rootfs profile installs Plasma Mobile, SDDM, XWayland and Mesa.
`scripts/configure-plasma.sh` applies the same automatic `t531` login to an
existing system. SDDM stops the previous user graphical session before restart
so a stale KWin process does not leave only a text console. SSH host keys are
generated on-device. `scripts/configure-network.sh` accepts private Wi-Fi
configuration inputs; the owner's installed policy allows empty-password SSH
on Wi-Fi. Never commit those inputs or factory calibration/MAC data.

## Installed boot chain and recovery

Samsung bootloader → unchanged lk2nd 23.1 → internal UP bootstrap → automatic
kexec of SD SMP kernel → Debian systemd → SDDM → Plasma Mobile.

The internal BOOT partition is `mmcblk0p14`, 10485760 bytes, start sector
209536, size 20480 sectors. Its first 524288 bytes are protected lk2nd; the
remaining 9961472 bytes hold the ext2 bootstrap payload. RECOVERY is p15
(10485760 bytes); EFS is p11 (14680064 bytes). BOOT, RECOVERY, EFS and other
critical accessible data were checked against a second complete read and
SHA-256 before flashing. Download Mode and the actual Samsung PIT were checked.
BOOT has PIT identifier 14. PIT SHA-256:
`3668fb5d80416a9c774666202cb027c7567d6d80b9566ff289374aa00d96e0e9`.

Initial lk2nd installation used:

```sh
heimdall flash --BOOT .work/artifacts/current/lk2nd-msm8226.img
```

Release image SHA-256:
`3e94879473e6136bda826949474525b8d3b9d20365258ba3347878affe7f23bc`.
The validated bootstrap was installed using lk2nd's offset-aware
`fastboot flash boot .work/artifacts/current/bootstrap-boot.ext2`.
That command is specific to lk2nd and is not a future kernel-update procedure.
The original UP kernel and lk2nd remain frozen in internal storage. An
authorized recovery update replaced only initramfs, DTB and extlinux arguments;
the kernel file and complete lk2nd prefix stayed byte-identical. Full BOOT
readback and a private 10 MiB backup were checked. Ordinary automatic kexec to
Debian and Plasma was verified after the update. `make bootstrap` prepares a
new complete first stage only; it never flashes it and must not replace the
frozen kernel as part of an SD update.

Press/hold either volume button during the bootstrap's three-second window to
enter recovery. Press either button again, or run `boot-sd` in the USB shell,
to load the card kernel. A failed automatic SD load also enters recovery.
The button-triggered SD handoff was physically tested in the temporary
recovery image; permanent automatic handoff was separately tested.
`mount-sd` mounts both card partitions read-only (ext4 without journal replay);
`mount-sd rw` explicitly requests writes. `umount-sd` unmounts them.
`mount-internal-boot` checks the model and partition geometry and mounts only
the ext2 payload read-only. `save-logs` writes pstore and bootstrap evidence
to card rootfs `/var/log/t531-rescue`, synchronizes and unmounts it.

`make rescue-initramfs` rebuilds only the recovery initramfs from pinned inputs,
without compiling or replacing the kernel. It reproduced the installed image
SHA-256 `7b54015a8a758b95901579f216818e3206b7809c4f9ac1cf1aaf7a1910241cc8`.
Recovery uses USB ACM; USB Ethernet is not validated.

Before the recovery update, an authorized change edited only the internal
extlinux command line:
remove `console=ttyMSM0,115200`, add `sysctl.kernel.sysrq=0`. The reported
bootloop panic was explicitly `sysrq triggered crash` in the UP first stage,
not evidence of a fault in the new SMP frequency or idle implementation.
Upstream MSM UART handles BREAK followed by a SysRq character; the electrical
source of that input is unknown. Temporary loading with the corrected arguments
worked. BOOT was backed up before this edit; kernel/initramfs/DTB file hashes
and the complete protected lk2nd prefix remained identical afterwards.
The ordinary internal-to-SD boot then restored SSH. Future diagnostic and SD
images omit that UART console; main builds also disable serial SysRq handling.

From Samsung Download Mode, restore the saved Android installation with:

```sh
(cd /home/paul/t531/private/device && sha256sum -c SHA256SUMS)
heimdall flash --BOOT /home/paul/t531/private/device/BOOT.img
```

Restore the saved pre-bootstrap lk2nd state with `BOOT-lk2nd.img` instead.
Neither restoration command has been physically tested. After
`download-pit --no-reboot`, the next command in the same Download Mode session
needs `--resume`; a fresh session omits it. Never flash a raw zImage, RECOVERY,
PIT, bootloader, modem or calibration partitions. See
[lk2nd boot documentation](https://github.com/msm8916-mainline/lk2nd/blob/23.1/Documentation/boot.md).

## Current hardware results

Compilation and probe messages do not constitute hardware acceptance.

| Component | Observed on the tablet | Remaining limits |
|---|---|---|
| Boot / Debian / SSH | Automatic UP-to-SMP kexec; native Debian, USB ACM command exchange and Wi-Fi SSH | Cold-boot and long-duration reliability |
| CPU frequency / voltage | All seven stock frequencies under four-worker checksum load; SAW acknowledgments match 1.14/1.15/1.28 V targets; schedutil reaches 1190.4 MHz under load | Closed-loop CPR, fuse-based voltage reduction and sustained thermal stress |
| CPU idle | Existing upstream standalone power-collapse sequence; thousands of successful entries and residency on all four cores | L2 remains powered; full RPM/L2 suspend absent |
| CPU hotplug | CPU1, CPU2 and CPU3 each pass offline→online; verified collapse re-runs the existing ACC release path | Repeated long-duration stress pending |
| System suspend | CPU/USB/Wi-Fi return in tested s2idle cycles; longer system-managed sleep exposes failed physical display recovery | Disabled through standard systemd sleep policy; native display recovery, RPM/L2 sleep and power consumption unfinished |
| Storage | Two 32 MiB ext4 write/unmount/cache-drop/readback tests after regulator load-vote fix; rootfs boots | SD remains limited to 50 MHz/no 1.8 V; sustained stress and hotplug |
| Display / touch | Continuing 1280×800 output; desktop touch interaction observed | Inherited simpledrm framebuffer; native MDP5/DSI scanout unfinished |
| Backlight | LP8556 register control follows DRM blanking and sysfs power-off; actual_brightness reads the chip and reports zero while BL_CTL is off | Illumination control does not prove recovered panel/scanout after sleep |
| GPU / desktop | FD305 GLES 3.0; full historic glmark2 score 74; three post-sleep scenes complete (score 106); accelerated Plasma | Mesa ordering workaround; post-sleep GPU recovery resolved in tested cycles; desktop 60 FPS unverified |
| Wi-Fi / Bluetooth | Pronto/wcn36xx autoconnect and SSH traffic | Firmware scan-offload fails; software fallback; Bluetooth untested |
| Charging / battery | SMB358 charging and thermistor read; AICL selected 2 A input ceiling | Actual source current not measured; full-cycle termination/recharge and accurate battery percentage unverified |
| Sound | Tapan identified from stock sources | Deferred |

### CPU implementation and diagnostics

The existing SPM driver now supports the MSM8226 L2 SAW voltage controller
for the shared PM8226 S2 CPU rail. Voltage requests run on CPU0, preserve the
inherited PMIC range and check the hardware acknowledgment; failures propagate
to cpufreq. The board uses the actual stock speed0 frequency plan and conservative
slow-process ceilings from its captured DT. Those targets are not external
voltage measurements or implementation of CPR. PM8226 L3 is voted higher
before APC and lower afterwards, following the stock
corner-ceiling dependency. The existing Qualcomm cpufreq wrapper connects CPU
OPPs to RPM CX: SVS_SOC through 998.4 MHz and NORMAL above it, matching the
stock PLL requirements. The analog PLL rail L8 is already held at 1.8 V by the
inherited framebuffer; independent native-display power integration remains
future work. The shared policy uses schedutil;
CPU idle reuses the upstream MSM8226 sequence with stock 500 us wake latency and
conservative 2 ms minimum residency. The four checksum workers passed at every
frequency. Temporarily lowering only the passive TSENS threshold produced
cooling state 4 and clamped CPU maximum/current to 600 MHz; both stock 75 °C
thresholds were restored. This validates the temperature-to-cpufreq control
path without heating the tablet to its normal trip point. Sustained hot-device
stability and external power/voltage measurements remain unverified.

The first RTC-woken s2idle test exposed an active LIS2HH12 interrupt reading
physical QUP_STATE `0xf9924004` before the I2C controller's clocks resumed.
The QUP patch moves system transitions to the noirq phase with runtime-PM
force helpers and adapter suspension marking, as in upstream Qualcomm GENI.
Four repeated RTC cycles passed after the QUP fix and sensor input was read
again. The accelerometer now disables its active data-ready interrupt and
conversion during system suspend and restores them on resume.

Active Plasma then exposed an A3xx GPU hang after sleep. Backport upstream
commit [be0e82b8e0c96649b8bc77a99ab0d185243b7659](https://github.com/torvalds/linux/commit/be0e82b8e0c96649b8bc77a99ab0d185243b7659)
with original authorship to drain VBIF before power-off. A305B implements three
clients; its acknowledgment register reads `0x00070000` after request clearing.
The six-client mask failed safely with `-EBUSY`; the A305B-specific three-client
mask then passed RTC sleep with active Plasma and no new GPU recovery.
Thermistor and cable-policy work use the freezable queue, avoiding conversion
attempts while VADC completion IRQs are disabled. Wi-Fi remembers its failed
firmware scan capability across restart/resume and uses software scanning.
The Pronto MX vote also allows the stock shared-rail maximum of 1.3375 V;
its former 1.15 V ceiling conflicted with the CPU turbo voltage requirement.
Three final-image RTC cycles passed with the same Plasma process, all four
CPUs online, schedutil restored, immediate Wi-Fi reassociation and no new GPU,
VADC or accelerometer faults. The post-sleep three-scene glmark2 test reports
Freedreno FD305 and completes with exit status 0. Its score 106 is for this
short smoke workload, not directly comparable with the earlier complete suite.
A subsequent physical Power press woke the device after 13 seconds, before
the 60-second backup alarm; the PMIC key IRQ advanced and Plasma/SSH returned.
A controlled SysRq panic with a five-second restart then preserved the actual
panic record through Samsung/lk2nd, bootstrap and kexec, and automatic Plasma
startup recovered. The record was saved in both `/var/log/t531-pstore` and
`/var/lib/systemd/pstore`. This proves that tested reset path; it does not prove
retention after power removal or every possible hardware reset.
A successful suspend counter alone cannot validate recovered graphics, input,
networking, charging or actual deep-sleep power.

Later system-managed sleep returned a lit black panel even though KWin could
render a desktop screenshot and populate the physical RGB framebuffer. A
mobile lockscreen was also active: `Autolock=false` did not disable the default
`LockOnResume=true`. Administrative `loginctl unlock-session` restored desktop
capture, but the user still observed missing physical output. The earlier raw
sysfs/RTC tests did not cover this complete session and display recovery path.
System sleep is therefore disabled at the owner's request by
`/etc/systemd/sleep.conf.d/20-t531-bringup.conf` (`AllowSuspend`,
`AllowHibernation`, `AllowHybridSleep`, `AllowSuspendThenHibernate` all `no`).
`CanSuspend` returns `no`. PowerDevil's AC, Battery and LowBattery profiles
also disable idle dimming, idle display-off and automatic suspend through
normal `powerdevilrc` settings. Manual DRM blanking, CPU idle and frequency
scaling remain available. Remove the drop-in and restore profile settings only
for controlled sleep diagnostics; native display recovery remains incomplete.

For boot failures, use USB ACM, private card logs and lk2nd logs, not screen
appearance alone. `sudo picocom --baud 115200 --flow n /dev/ttyACM0` accesses
the root diagnostic shell; inspect all ACM ports after USB re-enumeration.
Only one host reader may open a terminal. USB/IP attachment delay is separate
from kernel progress. `fastboot oem log` / `fastboot get_staged` retrieve lk2nd
logs. The appended SD DT now explicitly reserves the 512 KiB ramoops region at
`0x2ff80000` with two 128 KiB dump records and a 256 KiB console. The previous
SD DT replaced lk2nd's DT and lost its runtime reservation; a live bootstrap
ramoops node did not prove second-stage reservation. Both stages now register
the backend. Console persistence across kexec, controlled-panic restart retention and
systemd archival to `/var/lib/systemd/pstore/` are verified. Power-loss
retention is not expected from RAM. Bootstrap copies available previous pstore records to
`/var/log/t531-pstore` before kexec. Do not pass `lk2nd.pass-ramoops`: lk2nd 23.1
would override the static layout with 8 KiB dump records. Its raw Fastboot
reader remains usable; its dump parser assumes that older layout.
Do not zap pstore before investigating a failure. Bootstrap/initramfs and
journald logs persist on SD; unsanitized output stays outside Git.

### Graphics, charging and time limits

MSM8226-specific clearing of SMMU SCTLR.AFE resolved hardware translation
faults while retaining AP permission checks. Mesa renders through the separate
Adreno node, using the KMSRO adapter based on the MIT-licensed
[AsteroidOS implementation](https://github.com/AsteroidOS/meta-asteroid/tree/c5b82318a9d065f37d7f4ec90e272721288797b5/recipes-graphics/mesa-dri-simpledrm).
`FD_MESA_DEBUG=inorder` prevents observed missing text/icons during scrolling.
It retains hardware rendering; no pixman, per-frame glFinish or diagnostic
preload is installed. The underlying Mesa ordering problem is unresolved.
Measured application swap rates were about 22 FPS in settings and 10–12 FPS
in the drawer before the CPU changes, not physical scanout or input latency.
Simpledrm copies/converts XRGB8888 to the inherited RGB888 framebuffer.

LP8556 now uses its existing I2C brightness path rather than a stopped CAMSS
PWM clock whose inactive output level is unspecified. The driver honours
`bl_power` through `backlight_get_brightness()` and clears LP8556 BL_CTL for
zero brightness in register-only mode. The optional framebuffer backlight
phandle connects DRM CRTC disable/enable to standard backlight helpers.
Physical observation confirmed that register brightness 0/control `0x84`
extinguishes illumination. Two DRM off/on cycles and sysfs power-off read back
that state; restoring the display reads brightness 63/control `0x85` without
losing the requested level. Two further RTC-woken sleeps lasted 20.94 and
20.72 seconds with successful I2C off/on transactions in the suspend trace,
the same KWin process, four CPUs online, schedutil and Wi-Fi SSH restored.
This fixes illumination; it does not claim native display-engine power-off
or RPM/L2 deep sleep. The internal BOOT readback remains unchanged.
The LP855x get_brightness callback now reads the register brightness and,
for LP8556 register-only mode, its BL_CTL bit. This avoids reporting requested
brightness 63 as actual illumination while the chip is off; I2C errors remain
visible. No polling or userspace backlight override is installed.
After rebuilding and booting, levels 32/96/63 read back correctly; two DRM
off/on cycles report actual brightness 0/63 with requested brightness intact.
The post-sleep three-scene Wayland glmark2 workload also completes on FD305:
35/33/46 FPS, short-workload score 37. It validates resumed hardware rendering,
not 60 FPS desktop performance or comparability with the direct-DRM suite.

With SDDM stopped, run `sudo glmark2-es2-drm --visual-config alpha=0
--winsys-options drm-device=/dev/dri/by-path/platform-3200000.framebuffer-card`.
Then start SDDM using the configured session cleanup. Preserve the established
GPU configuration when investigating CPU power management.

The installed charging policy increases the input ceiling through
500/700/1000/1200/1500/1800/2000 mA at one-second intervals while SMB358 AICL
handles source droop. A higher ceiling is not measured consumption. The PMIC
USBIN ADC is not a valid VBUS measurement on this port. Charge ceiling is
1.8 A, float voltage 4.34 V; hardware termination and recharge are enabled.
Invalid or unsafe battery-temperature readings inhibit charging. Weak-source,
full-cycle and suspend charging behaviour remain unverified. UPower detects
the external supply; PM8226 BMS support and valid SOC percentage are missing.

Timesyncd persists a last-known time and synchronizes NTP. PMIC RTC initially
reported 1971 and rejects time writes, so RTC_HCTOSYS is disabled. Correct time
restored authenticated HTTPS and successful apt update/package installation;
certificate verification stays enabled. Persistent bring-up services include
NetworkManager, the Wi-Fi SSH listener and the charging policy. Their idle
memory, wakeups and production suitability still require measurement.
