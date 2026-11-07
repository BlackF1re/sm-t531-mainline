# LP8556 backlight

* TI LP8556, I²C`0x2c`; Linux `lp855x_bl`,
  `/sys/class/backlight/lcd-backlight`, max255, register-based linear control.
* **SOURCE:** Samsung external-PWM configuration uses CTRL01=`0x80`,
  A0=`0x44`, A1=`0x6c`, A5=`0x24`; GP0 PWM M1/N127/D=2×level.
  Android maximum105 is a PWM count (105/127 duty), **not** register BRT max.
  ATT-only A7=`0xcb` does not apply to matisse3g.
* Current board patch0036 uses CTRL01=`0x85` register-only brightness and
  removes GP0 PWM. 0033 gates BL_CTL at zero/power-off; 0037 reads BRT/BL_CTL.
  A0/A1 retain ~23.0-mA sink current (`30 mA×0xc44/4095`), four output phases.
  No evidence supports increasing LED current or falsifying the kernel scale.
* **DEVICE, 2026-10-17:** exclusive 18-step sysfs/I²C sweep2…255 matched every
  requested/actual/BRT level; CTRL85 and ROM unchanged. Status02 read clears
  latched OVP/OCP/TSD/UVLO: initial38 contained old OVP, later30 had no fault.
  No numerical kernel clamp; optical endpoint acceptance remains separate.
* Actual Phosh0.58 GtkScale gave2/2/3/11/37 at0/25/50/75/100% because auto
  brightness ran with `HasAmbientLight=false`,0 lux. SensorProxy3.7 accepts
  ClaimLight subscriptions without a populated sensor; success is not presence.
  Unblank re-claimed the nonexistent light sensor and hid the auto toggle.
* `patches/phosh/0002-ambient-require-available-light-sensor.patch` serializes
  claim/release and gates availability, including disappearing/pending replies.
  Manual mapping remains `round(2×(255/2)^p)` →2/7/23/76/255. Actual GTK/sysfs/
  I²C endpoint checks after t5313 package installation matched all five values.
  This fixes the reported plateau without remapping brightness or LED current.
* Focused `test-ambient` tests need GNOME settings-daemon-common schemas;
  production build then uses tests=false. `tools/test-phosh-brightness.py
  --expect-manual` must run with the desktop session bus and exclusive display
  ownership; it changes brightness briefly. Hardware sweep tool:
  `tools/test-backlight-range.py`. Neither should run during other GUI tests.

Evidence: [register and GUI results](../docs/backlight-range-results.json),
`patches/linux/0033*`, `0036*`, `0037*`, `patches/phosh`.
Datasheet: [TI LP8556 SNVS871M](https://www.ti.com/lit/ds/symlink/lp8556.pdf).
