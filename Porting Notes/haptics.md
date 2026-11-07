# ISA1200 haptics candidate

* Source-only ISA1200, I²C `0x48` on GPIO12/13, enable32/clock34.
* Android DT exposes the node but no bound driver or timed-output vibrator.
  Actual `CONFIG_HAPTIC_ISA1200=n` despite misleading
  `CONFIG_CONFIG_HAPTIC_ISA1200=y`.
* Controller/motor population remains unconfirmed. Do not drive guessed pins
  or claim native vibration; require chip/motor evidence before FF integration.

* **DEVICE:** repeated full Android boot creates unbound
  I²C79:`0x48` (`vibrator`); DT uses SDA12/SCL13, motor-enable32/clock34.
  No physical motor conclusion follows from the disabled driver.
