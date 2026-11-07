# PM8226 RTC

* `rtc-pm8xxx` counter rate and relative alarm IRQ were device-tested;
  relative RTC alarms woke s2idle. Calendar read1971 and firmware denied
  counter writes. A working alarm is not a settable/retained calendar RTC.
* `CONFIG_RTC_HCTOSYS` is disabled. timesyncd saved time/NTP supplies wall clock;
  a safe persistent calendar offset and retention acceptance remain unresolved.
* Schedule a sufficiently delayed relative alarm: a retention test slept only
  0.492s after slow preparation and was rejected. Check actual suspended time,
  not only a successful `rtcwake`/kernel return.

Evidence: [device observation](../docs/hardware-observation-20261022.json),
[sleep results](../docs/sleep-release-validation-20261103.json), `config/kernel.fragment`.
