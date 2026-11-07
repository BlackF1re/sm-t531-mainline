# MSM8226 TSENS

* Native QCOM_TSENS, THERMAL and CPU_THERMAL are selected. Device observations
  included CPU thermal zones around 35–36 °C; these are samples, not fixed values.
* Sensor calibration, sustained thermal tests, trip policy and cpufreq cooling
  behavior are not fully accepted. A readable zone alone is not thermal safety
  or externally calibrated temperature evidence.

* **DEVICE:** Android exports six `tsens_tz_sensor0`…`5` zones,
  snapshots45–52. Their vendor temperature units differ from the PMIC zone's
  millidegrees; convert per driver rather than applying a universal scale.
