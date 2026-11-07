# PM8226 battery measurement and SMB358 charging

## Hardware and conversion

* PM8226 BMS1 + external sense resistor, separate SMB358 charger/I²C`0x6a`,
  SM5502 cable detection. Not MAX170xx or PM8916 voltage-mode BMS.
  Native driver lives in `drivers/power/supply/qcom_pm8226_bms.c` via0118–0121;
  SMB358 integration uses `smb347-charger.c`, patches0011/0015/0016/0122.
* **SOURCE:** physical revision0003 selects12.2mΩ (>2); <=2 selects13.5mΩ.
  Preserved Android log implies12.5mΩ: ~2.4% current/charge discrepancy remains
  externally uncalibrated. Design6800mAh/123mΩ is cell-family data, not health.
* **DEVICE register reference:** presence`0x1208` bit7; IADC type/subtype
  `0x3604/5=08/03`, BMS IADC`0x3804/5=08/05`, external sense select`0x3848=1`,
  BMS1`0x4004/5=0d/01`; OCV`0x4090`, signed average sense`0x4098`, average
  VBAT`0x409e`, main signed36 CC`0x408a`, shadow CC`0x40a8` (not interchangeable).
* BMS snapshot holds only `0x4042` bit0, waits100µs, restores previous state on
  every exit; propagate hold-restore failures. Never clear counter/rewrite OCV
  to fabricate SOC. Accumulate signed36 wrap in software.
* VADC VBAT/OCV use625/1250mV measured references and1:3 prescaler, not raw
  codes as millivolts. 0119 fixes unsigned negative-IADC subtraction and the
  missing ×1,000,000 in µV/µΩ→µA; read-only calibscale is3291/(gain−offset).
* Standard `power_supply` battery `pm8226-bms`: voltage_now/ocv, current_now,
  charge_counter/capacity/temp, supplier SMB358; positive current=charging.
  Preserve µV/µA/µAh and deci-°C ABI. 0121 multiplies six battery-info temperature
  getter values by10 while preserving sentinel/overflow guards.
* Samsung31×5 OCV table is retained with attribution in simple-battery DTS.
  No learned FCC/aging, complete PMIC trim/temperature compensation or full-cycle
  percentage acceptance. Retained OCV may be stale after warm boot; 100% from
  OCV/CC is not evidence of a full or healthy battery.

## Input ramp and measurement limits

* `scripts/configure-charging.sh` installs `t531-charge-ramp.service`:
  one-second input ceilings500→700→1000→1200→1500→1800→2000mA. 0122 resets
  attach/temperature recovery to500mA instead of jumping directly to DCP max.
* Compare `input_current_limit` with hardware AICL `current_max`. Back off/hold
  at completed AICL result; source undervoltage rolls back one step; five offline
  seconds reset policy. Non-Charging state must not defeat termination/thermal
  inhibition. These are ceilings, not guaranteed smooth USB or battery current.
* PM8226 USBIN/DCIN did not follow external5V while reference channels worked.
  A software4.8-V floor is not validated; do not invent voltage scaling.
  Hardware AICL remains enabled; input voltage threshold is a separate issue.
* USB-tester current includes system load/conversion losses; BMS is net cell
  current. Near-full/thermal/termination limits can reduce it independently.
  Historic synchronized GPU load changed BMS +18.5→−33.7→+18.0mA and charge
  fell133µAh during load, proving dynamic sign/export, not absolute precision.
* 0132 removes wake activation from periodic BMS notification polling; charger
  events still notify immediately. This addresses suspend aborts independently
  of fuel-gauge calibration.

Tools: `tools/battery-diag`, `tools/check-battery-model.py` (all155 table points,
signed/wrap/error paths, host UBSan and ARM/qemu),
`tools/check-battery-temperature.py`; [device evidence](../docs/battery-results.json).
Vendor code: pinned `qpnp-bms.c`, `qpnp-adc-current.c`,
`bms-batterydata-samsung-6800mah.c` in the [source repository](../docs/hardware-source-manifest.json).
PM8941 historical BMS proposals are not drop-in PM8226 implementations.
Termination/recharge, weak-source behavior and calibrated full-cycle SOC remain open.
