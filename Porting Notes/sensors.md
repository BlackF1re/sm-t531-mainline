# Sensors, keys and haptics

| Component | Known wiring / integration | Evidence / gap |
|---|---|---|
| ST K2HH accelerometer | I²C`0x1d`; Android bus2; native LIS2HH12-compatible IIO, iio-sensor-proxy | DEVICE identity/probe; six orientations, signs/ranges and rotation/touch mapping not accepted |
| Semtech SX9500 grip/SAR | I²C`0x28`, GPIO0/1, IRQ66 | DEVICE Android ID/register readback; no native DT/IIO/SAR policy |
| Hall cover | TLMM GPIO110, SW_LID | DEVICE input probe/wake capability; physical magnet behavior pending |
| Power/Home/Volume | PMIC `pm8941_pwrkey` / GPIO keys | DEVICE; discover event by name; wake behavior is separate from GUI DPMS |
| Back/Recent keys | maXTouch keycodes | DEVICE mapping; explicit physical key/action acceptance pending |
| ISA1200 haptics | I²C`0x48` on GPIO12/13, enable32/clock34 | SOURCE DT only; no bound Android vibrator, actual CONFIG_HAPTIC_ISA1200=n |
| TSENS / battery thermistor | Standard thermal/power_supply | DEVICE readings; calibration/load-cooling policy not fully accepted |
| PM8226 temp-alarm | Offset`0x2400` | SOURCE; native die-temperature driver disabled |
| Board/PA thermistors | sec-thermistor, PA_THERM0/1/BCL | SOURCE; exact fitted channels not externally validated |

Quiesce active ST IIO triggers before system suspend (0022); restore QUP clocks
before client IRQ handling (0020). SensorProxy presence is not physical rotation
acceptance. `ClaimLight` can succeed with no ALS: [backlight](backlight.md).

**Unconfirmed variants:** CM36653/TMD2672 ALS/proximity and HSCDTD008 compass
appear in early-r00 descriptions, not current r02. IR MC96FR332/116 omitted in
r02; GPIO4/62 marked NC, driver disabled. NFC block/config disabled; no positive
NFC, gyro, notification/button LEDs, fingerprint/barometer/hub/S-Pen/TV/wireless
charging population evidence. Confirm actual PCB before inventing DT nodes.

Sources: [Android probe projection](../docs/android-hardware-observation-20261022.json),
[board sources/config](../docs/hardware-source-manifest.json),
[historical task snapshot](../status/hardware.yaml), [touchscreen](touchscreen.md).
