# MSM8226 clock and reset controllers

* **SOURCE:** GCC `qcom,gcc-msm8226` at `0xfc400000`; MMCC
  `qcom,mmcc-msm8226` at `0xfd8c0000`. Both expose clock/reset and GDSC domains.
* CPU APCS/KPSS mailbox/syscon is at `0xf9011000`; CPU voltage/sleep sequencing
  uses SAW/SPM. RPM supplies shared clock votes; local clock gating and RPM
  active/sleep votes are distinct controls.

Source: `qcom-msm8226.dtsi` in the project kernel (base`5fce161649b4`
plus `patches/linux`). DT configuration is not full subsystem acceptance.
