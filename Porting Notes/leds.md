# Navigation / notification LEDs

* Source descriptions are revision-dependent: button backlight appears in r00
  and is absent from r02; generic PMIC LED nodes do not prove population.
* Only virtual MMC activity LEDs were observed in native sysfs. Physical LED
  count/wiring, polarity and a real light-output test remain unestablished.

Evidence: [Android probe data](../docs/android-hardware-observation-20261022.json), [pinned board sources](../docs/hardware-source-manifest.json).
