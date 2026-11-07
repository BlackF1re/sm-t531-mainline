# SMB358 charging and input-current policy

* External charger SMB358, I²C 0x6a (Android bus 19); native integration extends
  `drivers/power/supply/smb347-charger.c`. SM5502 reports cable/source type;
  PM8226 BMS separately measures net cell current.
* 0011/0015 supply source/temperature integration; 0016 enables termination.
  0122 starts attachment/temperature recovery at 500 mA instead of jumping to DCP
  maximum. Preserve charge current, float voltage, termination and thermal limits.
* `scripts/configure-charging.sh` installs `t531-charge-ramp.service`. It raises
  standard input_current_limit ceilings once per second:
  500 → 700 → 1000 → 1200 → 1500 → 1800 → 2000 mA. These are ceilings, not a guaranteed
  smooth input or battery-current ramp.
* Compare input_current_limit with completed hardware-AICL current_max. Back
  off/hold at AICL's result. An `online=0` transition rolls back one step,
  but does not distinguish voltage droop from disconnection. Five offline
  seconds reset policy; non-Charging states must not defeat AICL or thermal limits.
* Keep hardware AICL enabled. USBIN/DCIN ADC did not follow connector 5 V, so the
  requested software 4.8 V input floor is unverified. Do not invent ADC scaling.
* USB input includes system load and conversion losses. Near-full/thermal/
  termination behavior can independently reduce net battery current. Weak
  source, full termination/recharge and calibrated current acceptance remain open.

Configuration: `sudo scripts/configure-charging.sh`; status/logs:
`systemctl status t531-charge-ramp.service`,
`journalctl -u t531-charge-ramp.service`. The installation command starts
policy unless INSTALL_ONLY=1; do not run it during an unrelated measurement.

* **DEVICE:** Android USB was online while battery status said
  Discharging; logs repeatedly failed BMS and SMB358 properties. This custom
  ROM is not a clean charging-policy reference. Its `CURRENT_NOW=-50` is a
  vendor value; do not assume standard microamps without checking the driver.
