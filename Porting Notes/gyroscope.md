# Gyroscope

* Population is **UNKNOWN**: no positively identified gyro or current board DT
  device was established in the retained evidence. Generic gyro options in the
  shared vendor kernel do not identify a fitted chip.
* The full matisse3g reference config disables gyro options. No part number,
  I²C address, interrupt, native driver or physical test is known.
* K2HH accelerometer data and automatic orientation are not gyro evidence.
  Do not select an IMU driver or advertise angular-rate sensing from them.

Evidence: [Android probe data](../docs/android-hardware-observation-20261022.json), [pinned board sources](../docs/hardware-source-manifest.json).
