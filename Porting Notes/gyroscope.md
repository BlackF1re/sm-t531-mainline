# Gyroscope

* Population is **UNKNOWN**: no positively identified gyro or current board DT
  device was established in the retained evidence. Generic gyro options in the
  shared vendor kernel do not identify a fitted chip.
* The full matisse3g reference config disables gyro options. No part number,
  I²C address, interrupt, native driver or physical test is known.
* K2HH accelerometer data and automatic orientation are not gyro evidence.
  Do not select an IMU driver or advertise angular-rate sensing from them.

* **DEVICE:** SensorService lists exactly two hardware sensors,
  K2HH and SX9500; no gyro HAL/input/DT identity was found. `gyro-rate=200`
  belongs to disabled nine-axis fusion with zero clients, not a gyro probe.
  `pm list features` advertises a gyro despite this; that declaration is not
  hardware evidence. Physical absence is still unproven.

Evidence: [pinned board sources](../docs/hardware-source-manifest.json).
