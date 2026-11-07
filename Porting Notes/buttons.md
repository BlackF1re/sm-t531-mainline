# Physical and capacitive buttons

* Device-observed: Power through PMIC `pm8941_pwrkey`; Home and Volume Up/Down
  through GPIO keys; Back/Recent mappings through maXTouch.
* Discover evdev devices by name, not fixed `eventN`. Explicit physical
  long-press/repeat and capacitive-key action acceptance remains incomplete.
* After an RTC resume, DPMS may still be off: the next short Power event can
  wake the display without attempting system suspend. Synchronize the complete
  logind `PrepareForSleep(true/false)` cycle when measuring key-triggered sleep.
* Earlier volume/PIN interference followed stale touchscreen slots, while the
  physical key bits were released. Do not diagnose stuck keys from the overlay.
