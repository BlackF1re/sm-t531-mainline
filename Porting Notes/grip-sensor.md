# Semtech SX9500 grip / SAR

* Device-identified under Android: SEMTECH/SX9500, I²C `0x28`, GPIO0/1, IRQ66;
  initialized registers were read back successfully.
* Native DT/IIO integration is missing. The relevant Linux family is SX9500;
  physical grip transitions, channel assignment and modem SAR policy remain
  unaccepted. An Android probe is identity/communication evidence only.

Evidence: [Android probe data](../docs/android-hardware-observation-20261022.json), [pinned board sources](../docs/hardware-source-manifest.json).
