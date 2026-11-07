# Shared memory and remote-processor IPC

* **SOURCE:** MSM8226 uses SMEM, SMD, SMSM and SMP2P for shared data,
  message channels and remote-processor state/interrupt signaling.
* `qcom,smem` uses TCSR hardware mutex3; mutex controller
  `qcom,msm8226-tcsr-mutex` is at `0xfd484000`. RPM message RAM is separate.
* ADSP, MPSS and Pronto/WCNSS have distinct signaling endpoints; a registered
  channel alone does not establish that its firmware or service is running.

Source: `qcom-msm8226.dtsi` in the project kernel (base`5fce161649b4`
plus `patches/linux`). DT configuration is not full subsystem acceptance.
