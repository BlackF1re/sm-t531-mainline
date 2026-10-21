<p align="center">
  <img src="assets/tab4-mainline.svg" alt="Galaxy Tab 4 SM-T531 mainline Linux — hardware bring-up" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/device-SM--T531-2563eb?style=flat-square" alt="Device: SM-T531">
  <img src="https://img.shields.io/badge/Linux-v7.2.9-0f766e?style=flat-square" alt="Linux: v7.2.9">
  <img src="https://img.shields.io/badge/Debian-trixie%20armhf-7c3aed?style=flat-square" alt="Debian: trixie armhf">
  <img src="https://img.shields.io/badge/status-hardware%20bring--up-d97706?style=flat-square" alt="Status: hardware bring-up">
</p>

# Galaxy Tab 4 SM-T531 · Mainline Linux

**Native ARMv7 Linux** on the Samsung Galaxy Tab 4 10.1 **SM-T531** (`matisse3g`): Qualcomm **MSM8226**, four Cortex-A7 cores, and **Adreno 305B**. Debian armhf runs from **microSD**, independently of Android userspace.

> [!IMPORTANT]
> **Experimental port — not a daily-driver image.** Real hardware works, but graphics stability, power management, and long-duration reliability are not fully accepted. **Do not flash a different Galaxy Tab 4 variant.**

## At a glance

| | Verified on the actual SM-T531 | Still limited / pending |
|:--:|---|---|
| 🟢 **Boot & Debian** | Internal bootstrap → SD kexec → Debian; USB ACM and Wi-Fi SSH | Cold-boot / endurance tests |
| 🟢 **CPU** | Seven stock frequency steps; all four cores; CPU hotplug; WFI and standalone collapse | Sustained thermal tests, deeper cluster idle |
| 🟢 **Storage & input** | microSD ext4 readback; touchscreen | SD hotplug and extended stress |
| 🟡 **Display** | Native MDP5 / DSI / TC358764 output; earlier physical image/touch acceptance | Historical black/frozen GUI reports; repeat physical and endurance acceptance of the current build |
| 🟢 **Backlight** | Phosh absent-sensor bug fixed; actual GUI/register range reaches 255 instead of 37 | Optical brightness acceptance and full panel power sequencing |
| 🟡 **GPU & shell** | Freedreno / Adreno acceleration; Plasma Mobile and native Phosh | Composition performance, fault recovery |
| 🟡 **Suspend** | Earlier profiles passed s2idle / standby / standalone CPU-L2 collapse and physical wake/desktop checks | Repeat acceptance on the current native profile; whole-SoC savings, display power sequencing and power draw |
| 🟡 **Battery** | PM8226 BMS voltage/current/temperature/coulombs and modeled SOC | Capacity / aging / full-cycle accuracy |
| 🟡 **Wi-Fi** | Managed, WPA2 AP, raw standalone monitor + probe/data injection | [Tested scope](docs/WIFI.md); firmware restart, PMF and RF-control limitations |
| ⚪ **Bluetooth / audio** | Hardware identified, limited bring-up | Untested / deferred |
| ⚪ **Modem / cameras** | — | Not brought up / untested |

> [!NOTE]
> **Observed ≠ production-ready.** The status above summarizes on-device tests, not successful compilation alone. See [graphics stability](docs/GRAPHICS-STABILITY.md), [battery evidence](docs/BATTERY.md), and [patch review](docs/PATCH-REVIEW.md).

Evidence spans several kernel and display profiles. **Latest installed profile**, rechecked on **2026-10-22**: kernel `7.2.9-dirty #16`, native split GPU/KMS, Mesa **25.0.7**, Phoc **0.46.0**, Phosh **0.58.0-1~t5313**, Debian **13.7**. This check confirmed processes, DRM ownership, module hash and battery interfaces; it adds no new physical display, FPS or suspend acceptance. Firmware bridge power, `FD_MESA_DEBUG=inorder` and a device-local GPU runtime hold remain in use.

On **2026-10-22**, kernel #16 consolidates [WCN3660 support](docs/WIFI.md) into one kernel patch, selects software scanning without the known HAL208 timeout, clears stale scan state and excludes the unsupported channel 144 through standard OF limits. Managed, WPA2 AP, raw monitor, probe/data injection and hcxdumptool handshake capture passed short tests. Configuration/MSM module are unchanged; DTB adds only the frequency limit. Monitor is exclusive; firmware hot restart, PMF and advanced RF controls remain incomplete or unvalidated.

## Boot flow

```mermaid
flowchart LR
    A["Samsung bootloader"] --> B["lk2nd 23.1"]
    B --> C["Internal bootstrap"]
    C -->|automatic kexec| D["Linux on microSD"]
    D --> E["Debian armhf"]
    E --> F["Plasma Mobile / Phosh"]
    C -. recovery shell .-> R["USB ACM"]
```

> [!WARNING]
> The **internal BOOT / lk2nd chain is deliberately frozen**. Ordinary kernel updates target the SD card, **not internal partitions**. Verify your device identity, card mount points and backups before deployment. Read [Recovery & safety](docs/RECOVERY.md).

## Build

```bash
make build
ROOTFS_PROFILE=mobile make rootfs
```

Detailed prerequisites, mount layout, deployment options and recovery-safe commands: **[Build & deploy →](docs/BUILD-DEPLOY.md)**

`ROOTFS_PROFILE=mobile` prepares **Plasma Mobile**. The installed **Phosh** profile requires its separate [build/install and session-selection steps](docs/PHOSH.md); these two commands alone do not reproduce the current tablet setup.

<details>
<summary><strong>📌 Pinned inputs and provenance</strong></summary>

| Input | Pinned version / role |
|---|---|
| [Linux stable](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tag/?h=v7.2.9) | `v7.2.9` · `5fce161649b4` |
| [lk2nd](https://github.com/msm8916-mainline/lk2nd/releases/tag/23.1) | `23.1`, **unmodified** |
| [Debian snapshot](https://snapshot.debian.org/archive/debian/20261003T000000Z/) | Debian **13.7 / trixie / armhf**, 2026-10-03 |
| [Samsung downstream kernel](https://github.com/LineageOS/android_kernel_samsung_msm8226/tree/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256) | Hardware research **only**; not imported wholesale |
| [matisse3g device config](https://github.com/matissewifi/android_device_samsung_matisse3g/tree/cf5a3b04f9598d6756113b79df64e91aa53868d9) | Hardware reference |

Linux patch files live in [`patches/linux/`](patches/linux); board and build configuration in [`config/`](config). The port currently applies **124 local kernel patches** to the pinned upstream base, including bring-up diagnostics and unmerged changes. Original licensing and authorship are retained. Original source pins were recorded on **2026-10-13**; later device results and upstream checks carry their own dates.

</details>

## Research map

| Area | Start here |
|---|---|
| 🖥️ **Native screen / DSI / LVDS** | [Native KMS](docs/NATIVE-KMS.md) · [Graphics stability](docs/GRAPHICS-STABILITY.md) |
| 🎮 **Rendering performance** | [Graphics](docs/GRAPHICS.md) · [Bottlenecks](docs/GRAPHICS-BOTTLENECK.md) · [Memory bus](docs/MEMORY-BUS.md) |
| 📱 **Mobile shell** | [Phosh](docs/PHOSH.md) · [Backlight](docs/BACKLIGHT.md) |
| 🔋 **Battery & charging** | [Battery measurements](docs/BATTERY.md) |
| 🧪 **Patch acceptance** | [Patch review](docs/PATCH-REVIEW.md) · [Measured JSON datasets](docs/) |
| 🛠️ **Operations** | [Build / deploy](docs/BUILD-DEPLOY.md) · [Recovery / safety](docs/RECOVERY.md) |

<details>
<summary><strong>Latest practical graphics constraints</strong></summary>

- Native scanout and GPU acceleration work, but the project explicitly records **missing / frozen GUI** reports.
- An ordinary Phosh drawer run was approximately **33 presentations/s**; a **59.993 presentations/s** fullscreen direct-scanout test does **not** mean the composited desktop runs at 60 FPS.
- Firmware-owned bridge power, GPU runtime workarounds, and resume/recovery paths remain bring-up topics.
- Some logs, calibration, firmware and device-identifying records are intentionally kept **outside Git**.

The evidence and caveats are in [Graphics stability](docs/GRAPHICS-STABILITY.md), [Patch review](docs/PATCH-REVIEW.md), and [Native KMS](docs/NATIVE-KMS.md).

</details>

> [!CAUTION]
> This repository contains **no universal flashable image**. Commands and partition assumptions are specific to the owner's verified SM-T531 setup. Never commit device credentials, factory calibration, raw partition backups, or unsanitized logs.
