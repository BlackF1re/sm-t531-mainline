# Battery Current Limiter (BCL)

* **SOURCE:** Qualcomm `qcom,bcl` appears in shared `msm8226.dtsi`; the downstream matisse3g configuration selects `CONFIG_BATTERY_BCL`. BCL is a power/current-limit policy path, not an identified extra chip.
* Distinguish BCL limits from PM8226 BMS cell-current measurements, SMB358 charging current, TSENS thermal trips and CPU frequency policy. A DTS node or Kconfig flag proves neither calibrated thresholds nor actual throttling.
* **Native:** no independent BCL threshold/interrupt/throttling acceptance is recorded; do not invent a default policy. Source: [source manifest](../docs/hardware-source-manifest.json). See [battery](battery.md), [thermal](soc-thermal.md), [power management](power-management.md).
