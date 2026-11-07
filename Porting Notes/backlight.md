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

For register control, write the standard sysfs brightness range0…255;
read actual_brightness and BRT to distinguish a kernel clamp from UI mapping.
The device sweep reached255 numerically; optical endpoint acceptance is pending.

Evidence: [register sweep](../docs/backlight-range-results.json),
`patches/linux/0033*`, `0036*`, `0037*`, `tools/test-backlight-range.py`.
[LP8556 SNVS871M datasheet](https://www.ti.com/lit/ds/symlink/lp8556.pdf).
