# ST K2HH accelerometer

* Device-identified STM/K2HH, I²C `0x1d`, Android bus 2; native LIS2HH12-compatible
  ST IIO driver. `CONFIG_IIO_ST_ACCEL_3AXIS` is selected.
* IIO and iio-sensor-proxy exposure was observed. Six orientations, axis signs,
  range accuracy and correct screen/touch rotation are not physically accepted.
* Patch 0022 quiesces active ST IIO triggers before system suspend; patch 0020
  restores QUP clocks before client interrupt handling. Preserve both orderings.
* This is an accelerometer; rotation support does not establish a gyroscope.

* **DEVICE:** Android SensorService exposes `K2HH Acceleration`,
  continuous mode up to 100 Hz, no batching; bound `K2HH` at I²C2:`0x1d`.
  Android uses vendor input/sysfs interfaces, not IIO.
