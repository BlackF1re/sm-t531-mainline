# maXTouch touchscreen and sleep

* **DEVICE:** Atmel mXT1188S, I²C`0x4a`, 16 MT slots, coordinate range0…4095.
  Android adapter5; an observed Linux adapter4. Discover by device/driver,
  not fixed event or I²C bus numbers. Driver `atmel_mxt_ts`, standard evdev.
* After sleep on #16: `BTN_TOUCH=1`, slot0 tracking9 at(35,1820), unchanged
  through a 12-s sample/three queries; physical keys were released. Rebinding
  only `4-004a` cleared all slots and restored PIN/Power behavior.
* **Established mechanism:** `mxt_stop` T7 deep sleep did not release MT slots;
  input suspend clears BTN_TOUCH but retains tracking IDs. Stop/start and
  queued reports can lose a lift event. T6 reset/calibration also retained slots.
  This explains stale state; the exact lost report was not captured.
* Patch0124 preserves Nick Dyer's authorship (historical Jiada Wang v11 12/56,
  source commit`26794433086dbc7dea18d2f6a1c8d61ab25bcfda`): quiesce
  threaded IRQ before stopping, release MT/pointer state, suppress transition
  reports while retaining T6 completions, wake/drain/restart/synchronize before
  reporting. I²C drain failures propagate. T9 Chromebook reset path was reviewed,
  not tested on that other hardware.
* **DEVICE, #17:** ten callback cycles with synthetic slots0/7/15 ended with
  all tracking IDs−1/BTN_TOUCH0; three logind s2idle/RTC cycles gave3success/0fail.
  Owner accepted PIN, touch and Power. Callback injection uses exclusive grab
  so synthetic contacts do not reach the compositor; callback tests alone are
  not system-sleep acceptance.
* Apparent volume gestures/display reactivation vanished after state reset,
  but separate GUI event chains were not traced. This touch driver disables
  its IRQ in suspend and does not enable it as a system wake source. Do not
  confuse shell DPMS reactivation with an accepted kernel wake source.

Sources: [0124 patch](../patches/linux/0124-input-atmel-mxt-release-contacts-across-sleep.patch),
`tools/mxt-pm-probe`.
Direct `rtcwake -m mem` once selected deep instead of configured s2idle and
failed DRM preparation: that is not touchscreen or deep-sleep acceptance.
