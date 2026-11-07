# ST K2HH accelerometer

* Device-identified STM/K2HH, I²C `0x1d`, Android bus2; native LIS2HH12-compatible
  ST IIO driver. `CONFIG_IIO_ST_ACCEL_3AXIS` is selected.
* IIO and iio-sensor-proxy exposure was observed. Six orientations, axis signs,
  range accuracy and correct screen/touch rotation are not physically accepted.
* Patch0022 quiesces active ST IIO triggers before system suspend; patch0020
  restores QUP clocks before client interrupt handling. Preserve both orderings.
* This is an accelerometer; rotation support does not establish a gyroscope.

Evidence: [Android probe data](../docs/android-hardware-observation-20261022.json), [pinned board sources](../docs/hardware-source-manifest.json). Kernel fixes: `patches/linux/0020*`, `0022*`.
