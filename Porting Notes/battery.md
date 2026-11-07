# PM8226 BMS1 / battery fuel gauge

* Separate BMS1 with external current-sense resistor, not an I²C MAX170xx or
  PM8916 voltage-mode gauge. Driver `drivers/power/supply/qcom_pm8226_bms.c`
  is added by 0118–0121. The supplier is the separate SMB358 charger.
* Board rev > 2: Rsense = 12.2 mΩ; rev ≤ 2: 13.5 mΩ. Device revision 0003 justifies
  12.2 mΩ, while preserved Android sense/current pairs imply 12.5 mΩ: ~2.4%
  calibration discrepancy, not externally resolved. Design 6800 mAh / 123 mΩ is
  family characterization, not learned capacity or measured aged-cell health.
* Recorded PMIC registers: presence 0x1208 bit 7; BMS IADC 0x3804/5=08/05,
  external sense 0x3848=1, BMS1 type 0x4004/5=0d/01; OCV 0x4090, signed average
  sense 0x4098, averageVBAT 0x409e, main signed 36-bit CC 0x408a, shadow 0x40a8.
  Main and shadow accumulators are not interchangeable.
* Snapshot holds only 0x4042 bit 0, waits 100 µs, restores its previous state on every
  exit. Propagate restore errors; never clear CC or rewrite OCV to force SOC.
  Accumulate signed 36-bit wraps in software. Voltage codes require VADC reference
  calibration / 1:3 prescaling; current conversion needs measured IADC gain.
* Standard Battery `pm8226-bms`: µV, µA, µAh, deci-°C; positive current = charging.
  Exports presence, status, voltage_now/ocv, current_now, charge_counter, capacity, temp.
  Samsung 31×5 OCV table retains attribution in simple-battery DTS.
* No learned FCC/aging or complete PMIC voltage trim/temperature compensation.
  Stale warm-boot OCV is possible. 100% from OCV + coulombs is not externally
  accepted SOC. Full charge/discharge, rest/recharge and calibration remain open.
* Synchronized GPU load changed net current +18.5 → −33.7 → +18.0 mA and removed
  133 µAh during load: changing export/sign, not absolute precision. The USB
  tester includes system load/losses and cannot directly equal battery current.
* 0132 removes wake activation from periodic 30 s BMS polling and avoids unchanged
  notifications; charger events still notify. SOC accuracy is a separate issue.
