# PMIC, RTC, watchdog and miscellaneous SoC blocks

* PM8226/SPMI, RPM-controlled regulators, PON/RESIN and PS_HOLD provide board
  power/reset; rail existence does not establish every peripheral's sequencing.
* **DEVICE:** `rtc-pm8xxx` counter rate and relative alarm IRQ worked; relative
  RTC alarms woke s2idle. Calendar reads1971 and firmware denies counter writes.
  `CONFIG_RTC_HCTOSYS` is off; timesyncd saved time/NTP supplies wall clock.
  Calendar offset persistence and retention remain unresolved. A working alarm
  is not a working/settable calendar RTC.
* APSS `qcom_wdt` probed/feed/stop worked, but expiry did not reliably reset
  Linux and observed counter rate depended on load. PM8226 PON `pm8916_wdt`
  candidate feed/register readback also failed actual reset and was rolled back.
  No production watchdog-recovery guarantee; never rely on probe or timer logs
  instead of real reset/boot acceptance. Do not repeat expiry tests without
  explicit recovery planning and physical access.
* PRNG at`0xf9bff000` binds, but driver reports no TRNG and rng_available none.
  Do not advertise tested physical entropy. QCE at`fd400000` binds under Android;
  native QCE/BAM/clocks/DT integration and crypto vectors remain unaccepted.
* CoreSight/JTAG and external UART accessibility are not established. PMU
  supported events and register safety are documented in [cpu](cpu.md) and
  [display](display.md). Console BREAK/SysRq is disabled; inherited bootstrap
  SysRq crash was addressed by `sysctl.kernel.sysrq=0`, not by replacing SMP.

Sources: `config/kernel.fragment`, [task snapshot](../status/hardware.yaml),
[device observation](../docs/hardware-observation-20261022.json),
[vendor pin/config manifest](../docs/hardware-source-manifest.json).
