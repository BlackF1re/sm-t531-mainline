# Battery thermistor

* PM8226 VADC-backed temperature is exported through standard battery
  `power_supply`; historical device samples were25.4–25.7 °C.
* ABI temperatures are tenths of °C. Patch 0121 fixes six battery-info getters
  without changing the internal whole-°C tables or undefined sentinel guards.
  Accepted limits read−50/600 and alert maximum450 in that ABI.
* The SMB358 temperature-inhibition policy must remain independent of display
  sliders/input-current requests. Sensor precision and full thermal charge
  protection still need external/load acceptance.
