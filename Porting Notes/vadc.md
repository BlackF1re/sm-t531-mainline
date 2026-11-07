# PM8226 VADC

* VBAT/OCV conversion uses measured625/1250mV references and a1:3prescaler;
  raw ADC codes are not millivolts. Recorded raw sample:VBAT=39467,ref625=31125,
  ref1250=37508. These are raw channel readings,not externally calibrated mV.
* Voltage trim/PMIC temperature compensation is incomplete. BMS retained OCV
  may be stale after warm boot; voltage precision needs an external reference.
* USBIN/DCIN did not follow external5V even though reference channels worked.
  A4.8V connector floor cannot be implemented from these values by guessing
  a scaling factor. Extcon cable state is not a voltage measurement.

Evidence: `patches/linux/0118*`,
`tools/battery-diag`, [vendor ADC/BMS pins](../docs/hardware-source-manifest.json).
