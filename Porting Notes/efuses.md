# QFPROM / eFuses

* **SOURCE:** `qcom,msm8226-qfprom` / `qcom,qfprom` at `0xfc4bc000`,
  4KiB aperture, exports NVMEM calibration cells including TSENS data.
* Preserve factory contents; an available NVMEM cell is not calibration
  acceptance. No fuse programming or security-state changes are required.

Source: `qcom-msm8226.dtsi` in the project kernel (base`5fce161649b4`
plus `patches/linux`). DT configuration is not full subsystem acceptance.
