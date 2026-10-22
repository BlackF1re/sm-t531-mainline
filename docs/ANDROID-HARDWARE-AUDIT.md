# Android hardware cross-check on SM-T531

Checked **2026-10-22**. Evidence: **VERIFIED_DEVICE** for the explicitly stated
Android identification/probe results. This is a hardware inventory audit, not
native Linux feature acceptance. The [full matrix](HARDWARE.md) and
[machine-readable tasks](../status/hardware.yaml) retain separate implementation
states. [Sanitized measurements](android-hardware-observation-20261022.json)
contain fixed hardware names, selected configuration and compatible/status nodes.

## Boot provenance and DT selection

The owner authorized a temporary Android BOOT test followed by restoration.
The tablet was already in **lk2nd 23.1 fastboot**. Its device detection identified
SM-T531; a fresh read of both virtual BOOT pieces reproduced the previously saved
10 MiB internal BOOT exactly. Before writing, the rollback image, target sizes,
protected prefix and candidate were checked.

The candidate is the owner's preserved **Dirty Unicorns Android 6.0.1 userdebug**
boot image, not a pristine Samsung factory release. The running kernel reports:

```
3.4.0-cyanogenmod-g6be37d8-00011-gcee6fdf-dirty
#1 SMP PREEMPT Sun Apr 10 13:17:48 CDT 2016
```

Its compressed kernel and ramdisk are byte-identical to the original pre-Linux
Android BOOT backup. The existing maintenance container adapts only the QCDT
selection table for lk2nd: one entry for platform `0x9e`, variant `0x8`, revision
`0x20000`. The selected **r02 FDT bytes are unchanged** from the original Android
image. Their SHA256 is
`834eb73ec12f46211acd6e2f301f51c75dad429b5bd5cca0ab9114bcb6a62bc9`.
The exact source tree of that Android binary has not been reconstructed; the
separately pinned Samsung/Lineage research mirror is not claimed to be identical.

Therefore this test does **not** independently exercise Samsung's original
bootloader/QCDT selection algorithm. It does boot the original Android kernel
with its preserved board FDT and obtains real bus/probe evidence. Android
completed boot (`sys.boot_completed=1`), identified `SM-T531 / matisse3g`, and
provided root ADB. Its CPU information reports **Revision `0003`**; the DT model
is **`[MATISSE-3G-OPEN] Rev-02-MTP-v2`**. The r02 model string must not be mistaken
for a measurement that the physical PCB is revision 2.

The live tree was copied from `/proc/device-tree` as a filesystem archive and
reconstructed with host `dtc -I fs`, because `/sys/firmware/fdt` is absent in this
kernel. It contains **5,468 property files**. Raw DT, cmdline, configuration,
logs and images stay outside Git: they can contain device identities. The public
observation publishes only a selected non-identifying projection, including
447 compatible/status nodes. Merely enabled DT nodes remain weaker evidence
than an actual chip ID or successful register transaction.

## Hardware evidence and native port implications

| Function | Observed under Android | Consequence for native Linux |
|---|---|---|
| Board identity | SM-T531/matisse3g; CPU Revision 0003; preserved r02 FDT | Refine source selection; do not merge unrelated Tab4 variants |
| Accelerometer | `STM`, `K2HH`; driver bound | K2HH identity now device-backed; native LIS2HH12-compatible IIO path still needs physical orientation acceptance |
| Grip/SAR sensor | `SEMTECH`, `SX9500`; probe completed and initialized I2C registers read back | Physical controller communication is established; native DT/driver and grip-event policy remain missing |
| Audio codec/transport | `wcd9306 detected`; `tapan-slim-ifd`, `tapan-slim-pgd`; ALSA `msm8226-tapan-snd-card` | WCD9306/SLIMbus path confirmed; native ADSP/codec/card still not brought up |
| Rear camera | `SILICONFILE_SR352`; chip ID `0xc2`; probe succeeded | Sensor identity established; native capture remains missing |
| Front camera | `SILICONFILE_SR130PC20`; chip ID `0xc1`; probe succeeded | Sensor identity established; native capture remains missing |
| ISA1200 vibration | Node in runtime DT; no bound controller/timed-output vibrator observed | Population remains unconfirmed; do not mark the motor working |
| FM | Actual kernel enables `RADIO_IRIS`/`RADIO_IRIS_TRANSPORT`; `iris_fm` binds | Corrects the earlier config-only inference; antenna, firmware operation and real reception remain untested |
| Modem / ADSP / video | `pil-q6v5-mss`, `pil-q6v5-lpass`, `pil_venus` bound | Supports hardware/resource research; proves no native data/call/audio/video function |
| Crypto engine | `qce` bound at `fd400000.qcom,qcedev` | Native integration/test vectors still required |

The running configuration differs from the inspected downstream defconfig.
In particular FM is enabled here. It also contains both
`CONFIG_HAPTIC_ISA1200=n` and the distinct
`CONFIG_CONFIG_HAPTIC_ISA1200=y`; the latter is **not** evidence that the normally
named option is enabled. No motor actuation was attempted. No audio playback,
image capture, FM reception or cellular call was accepted by this audit.

IR, optical light/proximity, compass/gyro, NFC, MHL, flash/AF and other optional
parts remain subject to the population qualifications in the full matrix.
An Android driver or generic DT template alone cannot settle every RF path,
external component or product option.

## BOOT restoration and return to Linux

| Boundary | Verified value / result |
|---|---|
| Physical BOOT | `mmcblk0p14`, start sector `209536`, 20,480 sectors / 10,485,760 bytes |
| Protected lk2nd | First 524,288 bytes, unchanged during the trial |
| Writable fastboot `boot` | Remaining 9,961,472 bytes; only this payload was flashed |
| Android candidate | 6,219,776 bytes, readback matched before boot |
| Rollback | Saved full payload checksum verified after upload into Android RAM |
| Restore | Original payload written at offset 524,288; complete physical BOOT read back |
| Equality | All 10,485,760 bytes equal the fresh pre-test copy |
| Before/after SHA256 | `f2e67d637182e79193912952f45341ceac4e621aeb7cefab4a8e55a6663192fc` |
| Native return | `7.2.9-t531-dirty #19`, matching BOOT SHA256, SSH and USB ACM, Phoc/Phosh processes |

The restore helper and image were placed only in Android `/dev` tmpfs and
vanished on reboot. Explicit flashing/block writes were restricted to BOOT;
no recovery, partition table, modem firmware or calibration partition was
flashed. Ordinary Android startup mounted its normal data/cache filesystems;
this test is not described as a globally read-only Android boot.
No new native physical display/touch acceptance is claimed from process checks.

The private complete backup and trial evidence are retained under the owner's
`private/stock-audit-20261022` directory. The internal bootstrap and current SD
kernel have returned to the pre-test boot configuration.

The protected-offset behavior was checked against lk2nd 23.1
[boot documentation](https://github.com/msm8916-mainline/lk2nd/blob/23.1/Documentation/boot.md),
[partition splitting](https://github.com/msm8916-mainline/lk2nd/blob/23.1/lk2nd/device/2nd/partition.c)
and [partition reading](https://github.com/msm8916-mainline/lk2nd/blob/23.1/lk2nd/fastboot/fetch.c).
This report records one controlled trial; it is not a generic flashing guide.

A subsequent [FM investigation](FM.md) tested actual receiver commands under
this preserved Android kernel, including DSP capture and process calibration.
Control operations worked after retry, but no RF reception was accepted. That
follow-up performed a separate verified BOOT backup/restoration.
