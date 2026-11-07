# MSM8226 TSENS

* Native QCOM_TSENS, THERMAL and CPU_THERMAL are selected. Device observations
  included CPU thermal zones around35–36°C; these are samples, not fixed values.
* Sensor calibration, sustained thermal tests, trip policy and cpufreq cooling
  behavior are not fully accepted. A readable zone alone is not thermal safety
  or externally calibrated temperature evidence.

Evidence: [native observation](../docs/hardware-observation-20261022.json),
`config/kernel.fragment` and [board source pins](../docs/hardware-source-manifest.json).
