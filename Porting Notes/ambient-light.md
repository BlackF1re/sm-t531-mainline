# Ambient-light sensor

* CM36653/TMD2672 are early-r00 source candidates, not identified populated
  sensors on this tablet; the r02 description omits them.
* Recorded native state: SensorProxy `HasAmbientLight=false`, light level0lux,
  no IIO light sensor. No native illuminance acceptance or verified wiring.
* A successful SensorProxy ClaimLight means a subscription was accepted, not
  that hardware exists. This distinction matters when enabling automatic
  brightness; an unavailable sensor must not activate zero-lux offset mode.

Evidence: [Android probe data](../docs/android-hardware-observation-20261022.json), [pinned board sources](../docs/hardware-source-manifest.json). [Brightness observations](../docs/backlight-range-results.json).
