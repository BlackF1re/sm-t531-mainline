# Device Tree and board identity

* **DEVICE:** `samsung, matisse3g`, SM-T531, MSM8226 SoC ID 158/revision 2.0.
  Android cpuinfo revision is `0003`; DT model `[MATISSE-3G-OPEN] Rev-02-MTP-v2`
  does not prove physical PCB revision 2. Do not substitute matissewifi wiring.
* TrustZone secure-monitor firmware is accessed through Qualcomm SCM
  (`qcom, scm-msm8226` in the SoC DTS).
* Native board/SoC definitions are maintained through `patches/linux`, initially
  0001–0006; required configurations are `config/kernel.fragment`,
  `config/native-kms.fragment`, `config/native-icc.fragment`.
* **DEVICE:** preserved Android is Dirty Unicorns 6.0.1 userdebug,
  kernel `3.4.0-cyanogenmod-g6be37d8-00011-gcee6fdf-dirty`, not factory Samsung.
  Android completed boot, enabling actual driver/ID checks; raw runtime tree
  has 5,468 properties and remains private.
* **DEVICE:** the ROM's Samsung5.0.2 release fingerprint conflicts
  with SDK23/DU6.0.1 display properties. A fingerprint string alone cannot
  identify factory firmware or establish a trustworthy stock-policy baseline.
* A temporary QCDT metadata adaptation selected r02 without modifying FDT bytes.
  An independent unchanged full-BOOT test also selected r02.
* `/proc/device-tree` was archived and reconstructed using `dtc -I fs` because
  Android lacked `/sys/firmware/fdt`. Sanitize bootargs/identities before export.
* r02 positively identifies the touch/accelerometer/charger/MUIC/backlight
  wiring. r00/r01 ALS/proximity, compass, IR and button LEDs are variant options,
  not evidence of population on this tablet.
* `CONFIG_ARM_ATAG_DTB_COMPAT` is disabled: the immutable loader supplies a live
  FDT, while the packaged SD image must preserve its appended updated DT.
  The installed SD zImage is an Android-v0 container carrying appended DT,
  not a bare host zImage. Preserve decompressor/DT placement below firmware
  scanout 0x03200000; the internal BOOT prefix is 512 KiB, not part of virtual boot.

* **DEVICE:** flashing the unchanged original full Android BOOT
  and booting through Samsung's loader independently selected
  `[MATISSE-3G-OPEN] Rev-02-MTP-v2`. No QCDT metadata adaptation was used.
  The archived runtime tree contains 3,504 property files; this count is not
  directly comparable to earlier collector totals.
