# Phosh brightness integration (historical shell)

* LP8556 exposes linear register brightness0…255. Phosh0.58 applies the
  perceptual mapping `round(2×(255/2)^p)`; manual fractions0/25/50/75/100%
  should produce2/7/23/76/255. PWM duty units are not this register range.
* Actual GtkScale instead produced2/2/3/11/37: automatic-offset mode ran with
  `HasAmbientLight=false`, 0lux, clamping the lower part and compressing maximum.
  SensorProxy3.7 ClaimLight success accepts a subscription without a sensor;
  unblank re-claimed it and the unavailable ALS hid the auto toggle.
* `patches/phosh/0002-ambient-require-available-light-sensor.patch` gates sensor
  availability and serializes claim/release/disappearance/pending replies.
  t5313 actual GTK/sysfs/I²C checks restored2/7/23/76/255 without changing LED
  current, ROM, hardware scale or the manual perceptual curve.
* Phosh test utilities require the desktop session bus and exclusive display
  ownership; they change real brightness and must restore it.
