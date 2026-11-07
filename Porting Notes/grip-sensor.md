# Semtech SX9500 grip / SAR

* I²C`0x28`, GPIO0/1 SDA/SCL, falling-edge IRQ GPIO66; VDD=L15 2.8V,
  SVDD=LVS1. Main CS0, reference CS1. GPIO66 must stay exclusive of AUXPCM.
* Native `sx9500`, `CONFIG_SX9500=m`, patches0149–0152. Standard IIO exports
  signed `in_proximityN_raw` (USEFUL), `_input` (background-compensated DIFF),
  raw triggered buffer and per-channel threshold events. Conversion waits are bounded.
* `in_capacitanceN_raw` uses the nominal Samsung small-range model; scale is
  `0.000000100` nF/code (0.1fF). `_calibbias` is applied internally; `_input`
  reports nF. Zero bias gives absolute nominal C; negative baseline gives ΔC.
  Physical accuracy still needs an external capacitance reference.
* EFS `/grip_cal_data`:12bytes, three LE signed32 integers: baseline,USEFUL,
  OFFSET. For legacy baseline≤100000, add300000; the extracted tuple then
  matches Samsung's formula. OFFSET is not blindly restored to live hardware.
* Private baseline is applied only to CS0 by `t531-configure-grip --install FILE`;
  a standard owner-only udev rule persists it, without daemon or Android mount.
  Rootfs accepts explicit `GRIP_CALIBRATION_FILE`; private values stay outside Git.
* Threshold/hysteresis are shared hardware controls in `events/`, with
  `_available` lists; per-electrode enables remain separate. DIFF is not mm.
* Device checks passed: signed raw and compensated reads on all four electrodes,
  CS0 baseline application/readback, threshold/hysteresis validation, signed
  triggered buffer with monotonic timestamps. Slow→fast sampling changes can
  retain the preceding scan; direct reads allow 900ms before reporting timeout.
* Grip/release event acceptance and suspend/resume remain unverified. Modem SAR
  control is not implemented by this IIO driver. Trial kernel boots with SX9500;
  K2HH startup timing is corrected separately by patch0153.

Sources: vendor `drivers/sensors/sx9500{,_reg.h}`, commit
`3fa1853ed5d6c3a8ef5a2fda9822705243bbc256`; kernel `sx9500.c` and
`Documentation/ABI/testing/sysfs-bus-iio-sx9500`;
[Semtech SX9500 datasheet](https://www.mouser.com/datasheet/2/761/sx9500-1278074.pdf).
