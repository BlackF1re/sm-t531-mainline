# ISA1200 haptics candidate

* Source-only ISA1200, I²C `0x48` on GPIO12/13, enable32/clock34.
* Live Android DT includes it, but no bound device/timed-output vibrator was
  observed. Actual `CONFIG_HAPTIC_ISA1200=n`; a similarly named
  `CONFIG_CONFIG_HAPTIC_ISA1200=y` is not the same Kconfig symbol.
* Controller/motor population remains unconfirmed. Do not drive guessed pins
  or claim native vibration; require chip/motor evidence before FF integration.

Evidence: [Android probe data](../docs/android-hardware-observation-20261022.json), [pinned board sources](../docs/hardware-source-manifest.json).
