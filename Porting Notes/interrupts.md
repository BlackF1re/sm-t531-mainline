# Interrupt controller and timers

* **SOURCE:** GIC `qcom, msm-qgic2`: distributor `0xf9000000`, CPU interface
  `0xf9002000`. ARMv7 architectural timer uses per-CPU PPIs2/3/4/1.
* GPIO IRQs cascade through TLMM/PMIC controllers. GPIO numbers, GIC SPI
  numbers and allocated Linux IRQ numbers are different namespaces.
