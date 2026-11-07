# PM8226 auxiliary IP: ADC_TM, GPIO/MPP, PWM and LEDs

* **SOURCE (PM8226):** QPNP ADC_TM at `0x3400`, die temperature alarm at `0x2400`; GPIO1–8 (`0xc000`…`0xc700`), MPP1–8 (`0xa000`…`0xa700`); six PWM/LPG channels `0xb100`…`0xb600`. These are *PMIC peripheral offsets on SPMI*, not SoC MMIO physical addresses.
* PMIC LED/flash/torch definitions exist in the shared DT. The r02 overrides disable WLED `leds@d800`; actual screen light uses external LP8556. Generic flash/LED nodes are not evidence of fitted camera flash or physical notification LEDs.
* Shared QPNP charger/vibrator entries are disabled; r02 specifies external SMB358 and an unbound ISA1200 candidate. Never enable PMIC output pins or LED current solely because generic blocks exist.
* **Native:** ADC/VADC/IADC, PMIC thermal and battery have separate test scopes; PWM/flash and every MPP output are not functionally accepted. Source: [source manifest](../docs/hardware-source-manifest.json), `msm-pm8226.dtsi`, `msm8226-sec-matisse3g-r02.dtsi`.
