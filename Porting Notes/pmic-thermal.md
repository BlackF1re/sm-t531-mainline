# PM8226 die-temperature alarm

* Source PM8226 `temp-alarm` peripheral at offset `0x2400`.
* The native die-temperature driver is disabled; no accepted PMIC temperature
  or overtemperature-alarm behavior is recorded. Do not treat TSENS or battery
  temperature as a replacement measurement of this die.

Evidence: [Android probe data](../docs/android-hardware-observation-20261022.json), [pinned board sources](../docs/hardware-source-manifest.json).
