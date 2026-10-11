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

Sources checked 2026-10-12. Host build used ARM GCC 15.2.0 and binutils 2.46. Linux is GPL-2.0-only; retained upstream DTS code
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
  No microSD was detected in the initial collection. The subsequently inserted
  16 GB SD card has 30253056 sectors; its 48 MiB boot and remaining root
  partitions are reformatted only with owner authorization. eMMC is SDC1, 8-bit,
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
The backed-up Android BOOT has `ANDROID!` header, 2048-byte pages, separate QCDT at
byte 6072320, four embedded FDT magic occurrences. Live DT was exported from
`/proc/device-tree`; `/sys/firmware/fdt` was unavailable.

## Build

On Debian/Ubuntu install Git, Make, GCC, `gcc-arm-linux-gnueabihf`, binutils,
bison, flex, libssl-dev, libelf-dev, bc, Python 3, dtc, cpio, gzip, curl, e2fsprogs,
Debian debootstrap/keyring, `mkbootimg` and static QEMU ARM with binfmt. `qemu-arm` must
execute armhf binaries. `ripgrep` is used for collector checks.

```sh
make build
# Optional: JOBS=4 make build on a smaller host.
make rootfs
make bootstrap  # Compact first-stage kernel and internal BOOT payload.
```

`multi_v7_defconfig` plus `config/kernel.fragment` is the bring-up baseline.
It retains unrelated upstream defconfig drivers; it is not a final size-tuned
production config. Required fragment settings are checked after olddefconfig.
One source checkout and one out-of-tree build live under `.work/`, ignored by Git.
The build refuses a different base or conflicting source modifications. It
applies six format-patch changes: compatible binding, board DTS, inherited
framebuffer resources, diagnostic SD speed limit, SD regulator load voting and
card-detect pin configuration. No driver or lk2nd patches are used. The modem is disabled.

Build timestamps, host/user and initramfs ordering/ownership are fixed. BusyBox
and lk2nd downloads are checked against pinned SHA-256. Rootfs uses signed
Debian snapshot repositories and emits `debian-packages.tsv`; rootfs tar bytes
are not yet claimed reproducible because package maintainer scripts generate
state. Host compiler/package versions also matter for kernel reproducibility.

Current outputs are in `.work/artifacts/current/`: `zImage`,
`qcom-msm8226-samsung-matisse3g.dtb`, `initramfs.cpio.gz`, installed modules,
`kernel.config`, `SHA256SUMS`, lk2nd image and Debian tar/manifest.
The diagnostic initramfs provides a USB ACM root shell. Command exchange has
been tested on the tablet; USB Ethernet is currently disabled during bring-up.

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

For the identified card still inside the rooted Android tablet:

```sh
FORMAT_SD=yes make deploy-adb-sd
```

This erases only the verified `mmcblk1p1`/`mmcblk1p2` external SD partitions,
checks model, SD type and exact partition boundaries, releases vold mounts,
uses Android's existing mke2fs and streams Debian via raw ADB. It does not
write the eMMC partition table or any eMMC partition.

The ext2 root contains `zImage`, DTB, initramfs and `/extlinux/extlinux.conf`.
Diagnostic initramfs provides an ACM shell through `/dev/ttyACM0` on the host.
This shell is for bring-up and is not a Debian login service. It also attempts
to save boot evidence to `/var/log/t531-initramfs.log` on the card rootfs.

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

lk2nd 23.1 was installed successfully using the BOOT-only command above. The
restore command has not been executed. Download Mode and PIT were checked
on the tablet: BOOT identifier 14, start sector 209536, 20480 sectors; RECOVERY
identifier 15, start 230016, 20480 sectors; EFS identifier 11, start 168576,
28672 sectors (512-byte sectors). PIT SHA-256:
`3668fb5d80416a9c774666202cb027c7567d6d80b9566ff289374aa00d96e0e9`.
After `download-pit --no-reboot`, use `heimdall flash --resume --BOOT ...`
for the next action in the same Download Mode session; fresh sessions omit
`--resume`. Installation was authorized after verified backups and PIT checks.
The build also packs `diagnostic-boot.img` (legacy Android v0, single appended
DTB). After lk2nd starts, test it only with
`fastboot boot .work/artifacts/current/diagnostic-boot.img`. It exceeds the
10 MiB BOOT partition and must never be flashed. The kernel loads at 0x8000. Initrd and DT addresses are calculated using
lk2nd extlinux placement: initrd ends below 50 MiB on a 4 KiB boundary, with
2 MiB reserved immediately below it for DT. The previous RAM test placed the
initrd at 46 MiB; overlap during decompression is under investigation. Through
lk2nd, `fastboot flash boot` writes at 512 KiB offset. See the bootstrap gate below.

## State and acceptance tests

| Component | Mainline implementation | Actual tablet acceptance |
|---|---|---|
| Kernel / DT / initramfs | Built and artifact hashes checked | Internal UP bootstrap automatically kexecs SD SMP kernel; ACM shell commands verified; Debian not booted |
| Four CPU cores | Upstream Qualcomm SMP, OPP and TSENS | Four CPUs online after boot; CPU3 could not return after a hotplug test; OPP/thermal/stability tests pending |
| eMMC / microSD | Common DTS SDHCI and regulators | eMMC enumerated; SD passed two 32 MiB ext4 write/unmount/readback tests after load-vote fix at 50 MHz; UHS and long stress unverified |
| USB / buttons / touch / backlight | Existing upstream drivers and board DT | USB ACM shell command exchange tested; Ethernet and input tests pending |
| Display | Boot framebuffer retains MDSS clocks/domain and DSI supplies | Owner observed continuing output past former failure; brief blue handover remains; native DRM and repeated boots untested |
| Adreno 305 | Upstream msm DRM/OCMEM; GPU DT remains disabled | No acceleration test |
| Wi-Fi / Bluetooth | WCNSS research; no enabled radio DT | Not implemented in this port |
| Battery / charging | Existing SMB358 support identified | Battery DT/policy not implemented |
| Audio | Tapan source identified | Deferred |
| Suspend / thermal / shutdown | Upstream baseline, incomplete board validation | Not tested |
| Debian | armhf rootfs built and deployed to microSD ext4 | Not booted |
| Plasma Mobile | Awaiting usable accelerated graphics | Not installed |

Validation order: lk2nd Fastboot → extlinux/card detection → correct model in
Linux → four CPUs/timers/interrupts → OPP/TSENS/cooling/stability → card ext4 →
Debian systemd → USB traffic/input/power → panel/backlight/touch → DRM connector
and hardware renderer → Plasma Mobile → repeated cold boots, thermal/charge,
shutdown/reboot and suspend/resume. Save sanitized results, not raw device logs.
For missing display, collect lk2nd logs with `fastboot oem log` then
`fastboot get_staged /home/paul/t531/private/lk2nd.log`, and test USB ACM; no UART wiring or ramoops
reservation is invented. The verified lk2nd region is 512 KiB at
`0x2ff80000`; console data starts at `0x2ffc0000`. Linux registration is
confirmed in the card log, but retention across restart remains unverified.

Boot-chain audit: Samsung BOOT contains lk2nd 23.1; the selected SD entry is
`diagnostic`, loading the project zImage, explicit SM-T531 DTB and initramfs.
USB ACM/ECM creation demonstrates that `/init` ran. Debian is not selected.
The owner observed console output followed by a blue flash and black display.
No panic log was obtained; ACM shell and USB Ethernet traffic did not respond.
The original USB diagnostic attempt left no rootfs log; a later USB-free log
collector successfully wrote boot evidence to the card boot partition. Display clock/power teardown
is a hypothesis: inherited simple-framebuffer has no clocks property, and
native panel support is absent. Framebuffer RAM is reserved by common DTSI.

A single-variable extlinux test added `clk_ignore_unused` with unchanged
kernel, DTB and initramfs hashes. The owner observed the same blue flash and
black display; ACM returned no data and USB Ethernet did not answer. This
test did not support unused-clock gating as the sole cause. DRM/MSM is a
module absent from this initramfs; an MDP5 driver underrun panic is therefore
not established.

The first appended-DTB RAM tests were accepted by lk2nd, but USB was not
observed within the initial observation window. A subsequent RAM test used a
legacy QCDT v2 container with the same mainline kernel and board DTB; the host
did enumerate the diagnostic USB gadget while the screen retained Fastboot.
This establishes initramfs execution for that test, not console usability.
ACM returned no data and USB Ethernet remained unreachable. A first ramoops
read after an earlier RAM test returned an all-zero region; it cannot prove
absence of panic because startup and RAM retention were not established.
The host uses USB/IP, so attachment delay and stale screen contents must be
distinguished from kernel progress.

USB control requests (device descriptor, configuration and status) repeatedly
completed after the display went black. This establishes active kernel USB
request handling, not a usable userspace console. ACM class requests succeeded,
but bulk IN/OUT timed out; the upstream serial gadget queues receive buffers
only while its terminal is open. A pre-open test did not restore a usable terminal.
A separate RAM boot with `fw_devlink=off` did not enumerate diagnostic USB
within 25 seconds; disabling dependency links is not an established fix.

Card logging test: adding `lk2nd.pass-ramoops` produced a reserved-memory node
at `0x2ff80000` and Linux registered ramoops/pstore console at boot. The
USB-free `t531.logonly` initramfs path mounted `LABEL=T531_BOOT` and saved
`t531-boot.log` and `t531-dmesg.log` on the external ext2 partition. Raw logs
remain outside Git. Saved evidence shows all four CPUs online, SD SDR104
enumeration and eMMC HS200 enumeration. This does not validate CPU OPP,
thermal behavior, storage stress, ext4 rootfs or USB data traffic.

For a log-only boot, append `lk2nd.pass-ramoops t531.logonly` to the diagnostic
entry. It skips gadget creation, attempts card logging and requests reboot
after 30 seconds. Hold Volume Down during the restart to enter lk2nd Fastboot;
automatic reboot and RAM retention are not yet validated. Read the fixed-size
region before issuing any new boot: `fastboot oem ramoops raw`, then
`fastboot get_staged /home/paul/t531/private/ramoops.raw`. Never use
`lk2nd.pass-ramoops=zap` when preserving a previous failure. A subsequent
maintenance Android boot can read the external ext2 logs without writing
internal partitions. USB-free logs passed the reported device-link errors
and reached `/init`, so those errors are not themselves proof of a panic.

An instrumented USB test also saved `t531-usb-dmesg.log` and a process/IRQ
snapshot to the external boot partition. UDC binding and `ttyGS0` opening
returned successfully. The later process snapshot contained the collector
but no interactive USB shell; timer interrupts were present on all four CPUs.
The cause of shell exit is not established. Waiting for USB `configured` and restarting an exited shell restored ACM
command exchange on the tablet. `echo READY` and `uname -a` returned results;
a runtime query reported CPUs `0-3` and available frequencies
300/384/600/787.2 MHz. Frequency transitions, thermal behavior and stability
remain untested. No full stacks were recorded in that snapshot; it contains wait-channel
names.
The requested automatic restart did not occur in the observed test; no
claim of preserved ramoops across a warm restart is made.

The `usb-log` entry selects the tested diagnostic path in `scripts/init-usblog`.
It waits for the card, saves USB boot/process/IRQ logs to `T531_BOOT`, waits
for USB configuration and restarts an exited interactive shell. It stays
online after collection. On the host, connect with
`sudo picocom --baud 115200 --flow n /dev/ttyACM0` (exit: Ctrl-A, Ctrl-X).
Only one host reader should use the terminal at a time. Use a terminal emulator
for BusyBox line editing; a raw reader must handle cursor-position requests.
This is a root initramfs diagnostic shell, not Debian or a graphics session.

Only demonstrated functions are validated: initramfs boot, ACM command
exchange and microSD ext2 log writes. Complete USB support, CPU power
management, Debian and graphics remain unvalidated.

Display resource test (2026-10-12): the original framebuffer lacked MDSS
clock, power-domain and supply references. Its blank flag was zero while
MDSS was off (`GDSCR=0x00282001`). `pd_ignore_unused` alone did not help.
A power-domain reference alone brought MDSS on but produced a blue screen.
With clock references and the vendor-confirmed L4/L5/L8 DSI supplies added,
the owner observed continuing display output beyond the former failure,
with a brief blue transition at startup. Runtime showed MDSS on
(`GDSCR=0xa0282000`) and framebuffer clock/supply consumers. USB shell
remained responsive after 170 seconds. These tests retained the existing
`clk_ignore_unused` parameter; operation without it is not verified.
Patch 0003 records this board-specific change using existing upstream
interfaces. This is inherited framebuffer bring-up, not native DRM/KMS.

The same boot reported repeated SD command timeouts and `mmcblk1: recovery
failed`, followed by writeback failures on the ext2 boot filesystem. These
are observed I/O failures, not evidence of a kernel panic. The boot filesystem
was repaired once from a local image using e2fsck and its writeback hash was
verified, but card I/O errors recurred. Logs remain local; SD reliability
must be fixed before Debian boot or further sustained writes. Inter-test
reboots were explicitly requested through the runtime shell; an independent
spontaneous reboot has not been established by a saved panic/reset log.

Further runtime checks (2026-10-12): the ACM shell remained responsive for
more than ten minutes. An observed battery-icon fragment disappeared after
clearing and redrawing tty1; the owner confirmed normal text afterwards. Both
initramfs entry points now clear tty1. The origin of the fragment is unknown;
this does not validate native DRM, cold boots or the rebuilt initramfs.

Patch 0004 limits external SD to 50 MHz without a 1.8 V transition for diagnosis.
Short 8 MiB write/readback checks passed, but subsequent log writes still caused
card removal and corrupted the on-card initramfs. The boot partition was
restored through temporary Android and its complete image hash verified.
MMC tracing then showed CMD25 completing successfully, followed immediately
by CMD13 timeouts and card re-enumeration. Runtime tests with vendor-confirmed
GPIO38 input/no-pull, controller reprobe and 25 MHz did not resolve the failure.
Patch 0006 subsequently records the vendor GPIO38 input/no-pull pin configuration; hotplug and long-term IRQ behavior remain unverified. Further boot-file updates require persistent
readback verification; Debian has not booted. Raw logs and partition images
remain outside Git.


## SD write fix and bootstrap kernel

The same card passed a 32 MiB write/unmount/cache-drop/readback under the
Android driver. With mainline it completed CMD25 data transfers but timed out
on the following CMD13 and re-enumerated. The board omitted
`regulator-allow-set-load` on PM8226 L18/L21; the upstream regulator core silently
ignored SDHCI load requests without that permission. Patch 0005 enables those
existing upstream requests, without changing supply voltages. Vendor SM-T531
revision-02 DTS documents active loads of 800000 and 22000 microamps.
A physical voltage drop was not measured; a defective card is not established.

With only the load-vote DT change, two separate 32 MiB ext4 write tests passed
sync, unmount, cache drop and remounted SHA-256 verification. MMC error counters
remained zero in those tests. Updated boot files also passed persistent readback.
The diagnostic 50 MHz/no-1.8-V limit remains; SDR104 and sustained storage
reliability still require testing. GPIO38 also generated an interrupt storm in
an earlier boot. Patch 0006 models the vendor GPIO/no-pull/2 mA configuration;
this is separate from the demonstrated supply-load fix.

`make bootstrap` reuses the one kernel build directory with `qcom_defconfig`,
`kernel.fragment` and `bootstrap.fragment`. It emits `bootstrap-zImage`,
`bootstrap-initramfs.cpio.gz`, `bootstrap-kernel.config` and
`bootstrap-boot.ext2`, a 9961472-byte ext2 payload fitting the logical BOOT
space after lk2nd's protected 512 KiB. Run `make build` for ordinary SMP
artifacts; the two profiles keep their current artifacts under distinct names.
The first stage is deliberately UP: upstream Qualcomm Cortex-A7 SMP lacks
`cpu_kill`, so ARM's kexec safety check rejects a load from an SMP kernel.
The ordinary second-stage kernel remains SMP-enabled; no safety check is bypassed.

The bootstrap uses static ARM kexec-tools 2.0.29 from
[the kernel.org release directory](https://www.kernel.org/pub/linux/utils/kernel/kexec/),
archive SHA-256 `67b1ac503aade45a54db0bc79228a8830a35d5d4f83cee932cff3e7a81a4a9ec`.
It mounts `LABEL=T531_BOOT` read-only, verifies `kernel.sha256` for `zImage`
and `initramfs.cpio.gz`, reads `kexec.cmdline`, loads and unmounts before kexec.
It uses a tested 64 MiB image allowance to place initramfs/DT above the normal
kernel decompression area, and saves addresses plus first-stage dmesg to
`/var/log/t531-bootstrap.log` on the external rootfs before handoff.
It reuses `/sys/firmware/fdt` with lk2nd's actual RAM/framebuffer settings;
DT changes therefore require updating the bootstrap DTB too. A failed load
returns to the diagnostic shell. Missing-card recovery is not yet physically tested.

Test the bootstrap on SD using `boot/bootstrap-extlinux.conf.in`, replacing
`t531.bootstrap=internal` with `t531.bootstrap=sd-test`, with the bootstrap
files alongside the ordinary files and checksum manifest. The saved first-stage
command line distinguishes the selected loader in subsequent internal tests. Internal
installation is gated on a successful real UP-to-SMP kexec test. The revised
loader passed automatic SD-to-SMP loading and was installed with:

```sh
# Only after real kexec validation and confirmation of the 10 MiB BOOT layout:
fastboot flash boot .work/artifacts/current/bootstrap-boot.ext2
```

This command is for lk2nd Fastboot, never stock Fastboot or Heimdall. It must
preserve the first 512 KiB. The complete current lk2nd BOOT was read and its
SHA-256 verified before preparing this scheme; its initial release-image bytes
also match the pinned lk2nd download. Fastboot reported logical BOOT
`0x980000` and protected lk2nd `0x80000`. After flashing, the complete BOOT,
protected 512 KiB prefix and payload hashes matched the expected bytes.
The card's test `/extlinux/extlinux.conf` had priority and was renamed to
`extlinux.sd-test.conf`. The next boot's saved first-stage log identified
`t531.bootstrap=internal`; the answering SMP shell identified `t531.stage=second`
and CPUs `0-3`. The other internal partitions were not written.

Keep `/extlinux/extlinux.conf` absent from the SD boot filesystem when using
this internal loader, or lk2nd may select the card entry first. Update ordinary
kernel files from a mounted card with:

```sh
make build
make deploy-sd BOOT_MODE=internal BOOT_MOUNT=/mounted/card-boot
```

This copies the kernel, initramfs, DTB and checksums without creating an SD
extlinux entry. It refuses an existing active extlinux configuration. The
loader currently reuses its live DT, so a DT change needs a rebuilt/retested
internal bootstrap too. Kernel/initramfs-only updates stay on SD.

Recovery of the exact saved pre-bootstrap lk2nd state from
Samsung Download Mode is:

```sh
heimdall flash --BOOT /home/paul/t531/private/device/BOOT-lk2nd.img
```

Bootstrap loading from SD and UP-to-UP kexec were observed on-device; the
second UP kernel returned an ACM shell with `t531.stage=up-self`. Re-enumeration
changed the host port to `/dev/ttyACM1`; inspect all ACM ports. Automatic UP-to-SMP kexec
reached the first kernel's `Bye!` handoff, but no second-stage console or usable
USB appeared; the owner reported a USB descriptor error. That first execution
was unverified. Repeating with only `maxcpus=1` added to the ordinary
second-stage command line also stopped at `Bye!`, without an answering ACM
shell. This does not support secondary-CPU startup as the sole cause. A compact
SMP kernel derived from the successful UP configuration then booted through
kexec with four CPUs and passed an 8 MiB ext4 write/unmount/readback test.
The ordinary multi_v7 kernel booted unchanged when kexec used
`--image-size=0x04000000`: initrd at `0x04008000`, DT at `0x040e5000`, instead
of `0x02ba5000`/`0x02c82000`. Its ACM shell reported `t531.stage=second`, CPUs
`0-3`, and passed a 32 MiB ext4 write/unmount/cache-drop/readback test.
This establishes a placement-dependent failure; the exact overwritten region
has not been measured. The final loader subsequently passed automatic SD-to-SMP kexec; the saved
first-stage command line identifies `t531.bootstrap=sd-test`, and the second
ACM shell reports `t531.stage=second` and CPUs `0-3`. The installed internal
loader then passed the same chain after the higher-priority SD test entry was
removed from lookup; its saved first-stage marker is `t531.bootstrap=internal`.
Debian systemd has not booted. Raw results and both BOOT backups remain outside Git.
