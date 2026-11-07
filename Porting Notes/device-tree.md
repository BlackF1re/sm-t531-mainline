# Device Tree and board identity

* **DEVICE:** `samsung,matisse3g`, SM-T531, MSM8226 SoC ID 158/revision 2.0.
  Android cpuinfo revision is `0003`; DT model `[MATISSE-3G-OPEN] Rev-02-MTP-v2`
  does not prove physical PCB revision 2. Do not substitute matissewifi wiring.
* Native board/SoC definitions are maintained through `patches/linux`, initially
  0001–0006; required configurations are `config/kernel.fragment`,
  `config/native-kms.fragment`, `config/native-icc.fragment`.
* **DEVICE, 2026-10-22:** preserved Android is Dirty Unicorns 6.0.1 userdebug,
  kernel `3.4.0-cyanogenmod-g6be37d8-00011-gcee6fdf-dirty`, not factory Samsung.
  Android completed boot, enabling actual driver/ID checks; raw runtime tree
  has 5,468 properties and remains private.
* The RAM/maintenance Android image changed QCDT selection metadata only:
  platform `0x9e`, variant `0x8`, revision `0x20000`. Selected r02 FDT bytes stayed
  unchanged, SHA256 `834eb73ec12f46211acd6e2f301f51c75dad429b5bd5cca0ab9114bcb6a62bc9`.
  This does not independently validate Samsung's original DT-selection logic.
* `/proc/device-tree` was archived and reconstructed using `dtc -I fs` because
  Android lacked `/sys/firmware/fdt`. Sanitize bootargs/identities before export.
* r02 positively identifies the touch/accelerometer/charger/MUIC/backlight
  wiring. r00/r01 ALS/proximity, compass, IR and button LEDs are variant options,
  not evidence of population on this tablet.
* `CONFIG_ARM_ATAG_DTB_COMPAT` is disabled: the immutable loader supplies a live
  FDT, while the packaged SD image must preserve its appended updated DT.
  The installed SD zImage is an Android-v0 container carrying appended DT,
  not a bare host zImage. Preserve decompressor/DT placement below firmware
  scanout0x03200000; the internal BOOT prefix is512KiB,not part of virtual boot.

Sources: [sanitized Android tree/probes](../docs/android-hardware-observation-20261022.json),
[Linux observation](../docs/hardware-observation-20261022.json),
[vendor source pins/include closure](../docs/hardware-source-manifest.json).
A bound driver establishes communication/probe, not full peripheral acceptance.
