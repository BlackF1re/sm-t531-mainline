# PM8226 BMS1 / battery fuel gauge

* Separate BMS1 with external current-sense resistor, not an I²C MAX170xx or
  PM8916 voltage-mode gauge. Driver `drivers/power/supply/qcom_pm8226_bms.c`
  is added by0118–0121. The supplier is the separate SMB358 charger.
* Source revision>2 selects12.2mΩ,<=2 selects13.5mΩ. Device revision0003 justifies
  12.2mΩ, while preserved Android sense/current pairs imply12.5mΩ:~2.4%
  calibration discrepancy, not externally resolved. Design6800mAh/123mΩ is
  family characterization, not learned capacity or measured aged-cell health.
* Recorded PMIC registers: presence0x1208bit7; BMS IADC0x3804/5=08/05,
  external sense0x3848=1,BMS1type0x4004/5=0d/01; OCV0x4090,signed average
  sense0x4098,averageVBAT0x409e,main signed36CC0x408a,shadow0x40a8.
  Main and shadow accumulators are not interchangeable.
* Snapshot holds only0x4042bit0,waits100µs,restores its previous state on every
  exit. Propagate restore errors; never clear CC or rewrite OCV to force SOC.
  Accumulate signed36 wraps in software. Voltage codes require VADC reference
  calibration/1:3prescaling; current conversion needs measured IADC gain.
* Standard Battery `pm8226-bms`: µV,µA,µAh,deci-°C; positive current=charging.
  Exports presence,status,voltage_now/ocv,current_now,charge_counter,capacity,temp.
  Samsung31×5 OCV table retains attribution in simple-battery DTS.
* No learned FCC/aging or complete PMIC voltage trim/temperature compensation.
  Stale warm-boot OCV is possible.100% from OCV+coulombs is not externally
  accepted SOC. Full charge/discharge,rest/recharge and calibration remain open.
* Synchronized GPU load changed net current+18.5→−33.7→+18.0mA and removed
  133µAh during load: changing export/sign, not absolute precision. The USB
  tester includes system load/losses and cannot directly equal battery current.
*0132 removes wake activation from periodic30sBMS polling and avoids unchanged
  notifications; charger events still notify. SOC accuracy is a separate issue.

Evidence: `patches/linux/0118*`–`0121*`,
`0132*`, `tools/check-battery-model.py`, `tools/check-battery-temperature.py`,
[pinned Samsung profile/source paths](../docs/hardware-source-manifest.json).
