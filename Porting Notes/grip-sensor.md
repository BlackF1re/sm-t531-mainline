# Semtech SX9500 grip / SAR

* Device-identified under Android: SEMTECH/SX9500, I²C `0x28`, SDA/SCL GPIO0/1, interrupt GPIO66;
  initialized registers were read back successfully.
* Native DT/IIO integration is missing. The relevant Linux family is SX9500;
  physical grip transitions, channel assignment and modem SAR policy remain
  unaccepted. An Android probe is identity/communication evidence only.

* **DEVICE, 2026-11-07:** Android HAL exposes `SX9500 Grip Sensor`, private
  sensor type65560, on-change/no batching; bound at I²C33:`0x28`.
  Its `nirq-gpio` is GPIO66 (not an established Linux IRQ number).
  Shared audio DT also names GPIO66 as AUXPCM DOUT: verify actual ownership
  before enabling that reference AUXPCM route.

[Android boot audit](../docs/android-hardware-observation-20261107.json).

Evidence: [Android probe data](../docs/android-hardware-observation-20261022.json), [pinned board sources](../docs/hardware-source-manifest.json).
