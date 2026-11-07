# TLMM and PMIC pin control

* **SOURCE:** SoC TLMM `qcom,msm8226-pinctrl` at `0xfd510000` owns GPIO mux,
  direction, pulls and GPIO interrupts. PM8226 GPIO/MPP are separate SPMI blocks.
* Board signal numbers require their controller: SX9500 interrupt GPIO66 is
  a TLMM line; LCD enable PM8226GPIO2 belongs to the PMIC, not TLMM GPIO2.

Source: `qcom-msm8226.dtsi` in the project kernel (base`5fce161649b4`
plus `patches/linux`). DT configuration is not full subsystem acceptance.
