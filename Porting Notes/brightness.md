# Phosh brightness integration

* LP8556 exposes linear register brightness0…255. Phosh0.58 applies the
  perceptual mapping `round(2×(255/2)^p)`; manual fractions0/25/50/75/100%
  should produce2/7/23/76/255. PWM duty units are not this register range.
* Actual GtkScale instead produced2/2/3/11/37: automatic-offset mode ran with
  `HasAmbientLight=false`,0lux, clamping the lower part and compressing maximum.
  SensorProxy3.7 ClaimLight success accepts a subscription without a sensor;
  unblank re-claimed it and the unavailable ALS hid the auto toggle.
* `patches/phosh/0002-ambient-require-available-light-sensor.patch` gates sensor
  availability and serializes claim/release/disappearance/pending replies.
  t5313 actual GTK/sysfs/I²C checks restored2/7/23/76/255 without changing LED
  current, ROM, hardware scale or the manual perceptual curve.
* `test-ambient` needs GNOME settings-daemon-common schemas; production builds
  use tests=false after focused tests. `tools/test-phosh-brightness.py
  --expect-manual` needs the desktop session bus and exclusive display ownership;
  it briefly changes real brightness and restores the original GUI/raw value.

Evidence: [GUI/register observations](../docs/backlight-range-results.json),
`patches/phosh/0002*`, `tools/test-phosh-brightness.py`.
