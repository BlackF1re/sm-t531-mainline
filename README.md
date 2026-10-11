# Samsung Galaxy Tab 4 SM-T531 mainline Linux

Native Linux bring-up for `matisse3g` (MSM8226, ARMv7). Debian armhf lives on
microSD; Android userspace and its downstream kernel are not runtime dependencies.
This is a diagnostic port, not a validated daily-use system. Modem and cameras
are outside the current scope. Bluetooth and audio follow basic stability;
Plasma Mobile follows real DRM/KMS and Freedreno validation.

## Fixed inputs

| Input | Revision | Purpose |
|---|---|---|
| [Linux stable](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tag/?h=v7.2.9) | `v7.2.9`, `5fce161649b4d779d1b76d9fcd52dc77779774b8` | Kernel, MSM8226 and Matisse common DT |
| [lk2nd](https://github.com/msm8916-mainline/lk2nd/releases/tag/23.1) | `23.1`, `e9c8b21735c13dd7ace808b1e35451638f0a0c6d` | Unmodified release image |
| [Samsung downstream](https://github.com/LineageOS/android_kernel_samsung_msm8226/tree/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256) | `3fa1853ed5d6c3a8ef5a2fda9822705243bbc256` | SM-T531 revision 00/01/02 wiring and panel sequences; GPL-2.0 source research |
| [matisse3g device configuration](https://github.com/matissewifi/android_device_samsung_matisse3g/tree/cf5a3b04f9598d6756113b79df64e91aa53868d9) | `cf5a3b04f9598d6756113b79df64e91aa53868d9` | Android product identity research |
| [Debian snapshot](https://snapshot.debian.org/archive/debian/20261003T000000Z/) | `trixie`, `20261003T000000Z` | Rootfs package inputs |
| Debian static BusyBox | `1:1.37.0-6+b9`, armhf | Diagnostic initramfs; GPL-2.0, Debian source available |

Sources checked 2026-10-11. Linux is GPL-2.0-only; retained upstream DTS code
is BSD-3-Clause, with original authorship. The downstream tree is research only,
not copied into the project. [postmarketOS ports](https://gitlab.postmarketos.org/postmarketOS/pmaports)
are additional research references; related Matisse Wi-Fi/LTE and MSM8916
Matisse VE ports do not establish SM-T531 wiring.

lk2nd image SHA-256:
`3e94879473e6136bda826949474525b8d3b9d20365258ba3347878affe7f23bc`.
Static BusyBox Debian package SHA-256:
`8b35210e08d559ecc0ddb660dd96f6f9694f69eb27f1dc608f5eeda56d94509e`.

## Device evidence

`VERIFIED_DEVICE` means observed on the connected tablet under its current
Android system, not a mainline acceptance test:

- Model SM-T531, codename matisse3g, bootloader T531XXU1BPK2, Android 6.0.1
  Dirty Unicorns with root. Recovery and BOOT backups preserve this installation;
  they are not proven factory Samsung images.
- SoC ID 158, revision 2.0; four Cortex-A7 cores (`0x41/0xc07`), Android MemTotal 1406012 KiB. Device DT says
  `[MATISSE-3G-OPEN] Rev-02-MTP-v2`. `/proc/cpuinfo` reports revision `0003`,
  `ro.revision` reports `0`: those fields must not be conflated with DT board ID.
- Android CPU frequencies: 300/384/600/787.2/998.4/1094.4/1190.4 MHz.
  Mainline inherited CPU OPP stops at 787.2 MHz pending speedbin support;
  it has no per-OPP CPU voltage data. Full frequency/voltage support is unfinished.
- Live DT: maXTouch 1188S, I2C5 `0x4a`, IRQ GPIO17, power GPIO31/73,
  reset PM8226 GPIO6. Vendor SM-T531 DTS agrees. No SM-T535 GPIO32 inference.
- Panel 1280×800, TC358764 DSI-to-LVDS, LP8556 at `0x2c` on GPIO20/21 I2C,
  PWM GPIO33. Vendor panel sequence uses four DSI lanes, reset GPIO51,
  enable GPIO25, backlight enable GPIO74 and PMIC GPIO2.
- microSD wiring: SDC2, PM8226 L18/L21, active-low detect GPIO38.
  No microSD was detected in the initial collection. eMMC is SDC1, 8-bit,
  L17/L6; its Android device name is `016GE2`.
- SM5502 MUIC `0x25`, I2C GPIO14/15, IRQ GPIO67. SMB358 charger `0x6a`
  on GPIO10/11 I2C. Android reports Li-ion battery and valid temperature/voltage.
- WCNSS firmware names `wcnss.mdt`, `wcnss.b*`; Adreno firmware
  `a300_pfp.fw`, `a300_pm4.fw`. Exact Wi-Fi/BT firmware/calibration handling
  remains to be implemented. Android audio card is msm8226-tapan-snd-card.

Raw properties, logs, DT, serials, firmware inventories and all partition images
are only in `/home/paul/t531/private/device`, outside this Git repository.

| Partition | Device | Bytes |
|---|---|---:|
| BOOT | `/dev/block/mmcblk0p14` | 10485760 |
| RECOVERY | `/dev/block/mmcblk0p15` | 10485760 |
| EFS | `/dev/block/mmcblk0p11` | 14680064 |

All three backups and MODEMST1/2, FSG, FSC, PERSIST, PERSDATA and PARAM were
verified against a second complete device read and local SHA-256.
The current BOOT has `ANDROID!` header, 2048-byte pages, separate QCDT at
byte 6072320, four embedded FDT magic occurrences. Live DT was exported from
`/proc/device-tree`; `/sys/firmware/fdt` was unavailable.

## Build

On Debian/Ubuntu install Git, Make, GCC, `gcc-arm-linux-gnueabihf`, binutils,
bison, flex, libssl-dev, libelf-dev, bc, Python 3, dtc, cpio, gzip, curl,
Debian debootstrap/keyring, `mkbootimg` and static QEMU ARM with binfmt. `qemu-arm` must
execute armhf binaries. `ripgrep` is used for collector checks.

```sh
make build
# Optional: JOBS=4 make build on a smaller host.
make rootfs
```

`multi_v7_defconfig` plus `config/kernel.fragment` is the bring-up baseline.
It retains unrelated upstream defconfig drivers; it is not a final size-tuned
production config. Required fragment settings are checked after olddefconfig.
One source checkout and one out-of-tree build live under `.work/`, ignored by Git.
The build refuses a different base or conflicting source modifications. It
applies two format-patch changes: the board compatible binding and SM-T531 DTS
with its Makefile entry. No driver or lk2nd patches are used. The modem is disabled.

Build timestamps, host/user and initramfs ordering/ownership are fixed. BusyBox
and lk2nd downloads are checked against pinned SHA-256. Rootfs uses signed
Debian snapshot repositories and emits `debian-packages.tsv`; rootfs tar bytes
are not yet claimed reproducible because package maintainer scripts generate
state. Host compiler/package versions also matter for kernel reproducibility.

Current outputs are in `.work/artifacts/current/`: `zImage`,
`qcom-msm8226-samsung-matisse3g.dtb`, `initramfs.cpio.gz`, installed modules,
`kernel.config`, `SHA256SUMS`, lk2nd image and Debian tar/manifest.
The initramfs boots to a shell and attempts USB ACM plus ECM diagnostics.
These gadget paths still require enumeration and traffic tests on the tablet.

Rootfs contains systemd, udev, SSH, networkd, basic storage/network diagnostics
and packaged Qualcomm firmware. No desktop is installed. SSH permits keys only;
use `SSH_AUTHORIZED_KEY=/path/to/public-key make rootfs` to install your key.
SSH host keys are generated on first boot; no shared host identity is distributed.
Networkd configures device USB Ethernet as `192.168.77.2/24`; configure the host
as `192.168.77.1/24`. Persistent service memory/wakeups remain unmeasured.

## microSD layout and startup

Use a card with an ext2 boot partition **larger than 16 MiB** (256 MiB suggested)
and an ext4 root partition labelled `T531_ROOT`. This repository does not format
or repartition devices. Identify the exact card and preserve its data first.

```sh
make deploy-sd BOOT_MOUNT=/mounted/card-boot
sudo tar --numeric-owner -xpf .work/artifacts/current/debian-armhf.tar.gz \
    -C /mounted/card-root
```

The ext2 root contains `zImage`, DTB, initramfs and `/extlinux/extlinux.conf`.
The explicit `fdt` path avoids lk2nd's existing SM-T531 Wi-Fi DT filename alias;
no lk2nd modification is needed. The default entry is diagnostic. Change
`default diagnostic` to `default debian` only after storage and basic boot tests.
The initramfs waits for `LABEL=T531_ROOT`, mounts ext4 and uses `switch_root`.
It falls back to its shell if no suitable rootfs can be mounted.

## Recovery and flashing gate

Read [lk2nd boot documentation](https://github.com/msm8916-mainline/lk2nd/blob/23.1/Documentation/boot.md)
and [Samsung installation instructions](https://github.com/msm8916-mainline/lk2nd/blob/23.1/README.md).
Installing lk2nd in BOOT replaces the current Android boot path. Recovery and
all other internal partitions must remain untouched. A zImage is not a Samsung
BOOT image. Never flash it with Heimdall.

Before flashing, confirm Download Mode, retrieve PIT, match its BOOT mapping
and size to the backup, verify image checksum, and obtain owner approval:

```sh
heimdall detect
heimdall download-pit --output /home/paul/t531/private/device/device.pit --no-reboot
heimdall print-pit --file /home/paul/t531/private/device/device.pit
(cd .work/artifacts/current && sha256sum -c SHA256SUMS)
# Only after all checks and explicit approval:
heimdall flash --BOOT .work/artifacts/current/lk2nd-msm8226.img
```

Restore the saved current Android BOOT from Download Mode:

```sh
(cd /home/paul/t531/private/device && sha256sum -c SHA256SUMS)
heimdall flash --BOOT /home/paul/t531/private/device/BOOT.img
```

Neither flash command has been executed. Download Mode and PIT were checked
on the tablet: BOOT identifier 14, start sector 209536, 20480 sectors; RECOVERY
identifier 15, start 230016, 20480 sectors; EFS identifier 11, start 168576,
28672 sectors (512-byte sectors). PIT SHA-256:
`3668fb5d80416a9c774666202cb027c7567d6d80b9566ff289374aa00d96e0e9`.
After `download-pit --no-reboot`, use `heimdall flash --resume --BOOT ...`
for the next action in the same Download Mode session; fresh sessions omit
`--resume`. Owner approval is still required for the BOOT replacement.
The build also packs `diagnostic-boot.img` (legacy Android v0, single appended
DTB). After lk2nd starts, test it only with
`fastboot boot .work/artifacts/current/diagnostic-boot.img`. It exceeds the
10 MiB BOOT partition and must never be flashed. Kernel, initrd and DT load
addresses are 0x8000, 0x02e00000 and 0x03000000; the uncompressed kernel plus
relocated compressed payload fit below the initrd. Through
lk2nd, `fastboot flash boot` writes at 512 KiB offset; it is not used here.

## State and acceptance tests

| Component | Mainline implementation | Actual tablet acceptance |
|---|---|---|
| Kernel / DT / initramfs | Built and artifact hashes checked | Not booted |
| Four CPU cores | Upstream Qualcomm SMP, OPP and TSENS | Not tested in mainline; full clocks/voltage incomplete |
| eMMC / microSD | Common DTS SDHCI and regulators | Not tested in mainline |
| USB / buttons / touch / backlight | Existing upstream drivers and board DT | Not tested in mainline |
| Display | Inherited boot framebuffer | Native DSI/LVDS DRM chain not implemented |
| Adreno 305 | Upstream msm DRM/OCMEM; GPU DT remains disabled | No acceleration test |
| Wi-Fi / Bluetooth | WCNSS research; no enabled radio DT | Not implemented in this port |
| Battery / charging | Existing SMB358 support identified | Battery DT/policy not implemented |
| Audio | Tapan source identified | Deferred |
| Suspend / thermal / shutdown | Upstream baseline, incomplete board validation | Not tested |
| Debian | armhf rootfs built with package manifest | Not booted |
| Plasma Mobile | Awaiting usable accelerated graphics | Not installed |

Validation order: lk2nd Fastboot → extlinux/card detection → correct model in
Linux → four CPUs/timers/interrupts → OPP/TSENS/cooling/stability → card ext4 →
Debian systemd → USB traffic/input/power → panel/backlight/touch → DRM connector
and hardware renderer → Plasma Mobile → repeated cold boots, thermal/charge,
shutdown/reboot and suspend/resume. Save sanitized results, not raw device logs.
For missing display, collect lk2nd logs with `fastboot oem log` then
`fastboot get_staged /home/paul/t531/private/lk2nd.log`, and test USB ACM; no UART wiring or ramoops
reservation is invented. Compiled pstore support alone provides no persistent
RAM log until a safe reserved region is established.

No component is `WORKING` or `VERIFIED` in mainline without a physical functional
test. Current device observations establish wiring, not Linux readiness.
