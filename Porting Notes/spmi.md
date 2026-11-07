# SPMI PMIC bus / arbitration

* **SOURCE (SoC):** `qcom,spmi-pmic-arb`, node `spmi@fc4c0000`; hardware register windows: core `0xfc4cf000`, interrupt `0xfc4cb000`, configuration `0xfc4ca000` (each 4 KiB). Vendor GIC interrupts 190 and 187; do not confuse SPMI peripheral IRQ indices with GIC or TLMM GPIO numbers.
* PM8226 children expose PON, RTC, BMS, regulators, GPIO/MPP, ADC, LED and PWM functions. SPMI arbitration and RPM regulator votes are different mechanisms; both are needed for correct supply/interrupt integration.
* **Native:** PMIC battery measurements and RTC have bounded device results; those do not imply every SPMI child works. Source: [source manifest](../docs/hardware-source-manifest.json), `msm8226.dtsi`, `msm-pm8226.dtsi`. See [PMIC](pmic.md), [PMIC peripherals](pmic-peripherals.md).
