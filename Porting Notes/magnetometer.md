# Magnetometer / compass

* HSCDTD008 occurs in early board descriptions; it is not a device-identified
  compass on this SM-T531. No current DT device or physical magnetic sample
  was established; full matisse3g reference options are disabled.
* Population, exact wiring and calibration are **UNKNOWN**. Do not carry an
  early-r00 node into the r02-based native board without positive evidence.

* **DEVICE, 2026-11-07:** no compass among the two SensorService hardware
  sensors or identified I²C devices. Android nevertheless advertises
  `android.hardware.sensor.compass`; this generic feature is not a chip ID.
  No populated compass is established by this audit.

[Android boot audit](../docs/android-hardware-observation-20261107.json).

Evidence: [Android probe data](../docs/android-hardware-observation-20261022.json), [pinned board sources](../docs/hardware-source-manifest.json).
