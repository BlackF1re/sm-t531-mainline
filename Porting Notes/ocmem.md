# OCMEM SRAM and graphics allocation

* Linux `qcom_ocmem` supplies firmware-backed graphics allocation to A305B.
  At450MHz, the source peak6.4GB/s over16bytes implies a400MHz request;
  physical OCMEM frequency remains unmeasured. Do not infer it from DDR clocks.
* **DEVICE:** RPM resume returned CPU but GMEM readback was zero;
  sysmem passed. Re-voting ICC or restoring SCM security alone did not fix it.
  Restoring security **and the existing OCMEM graphics lock** restored all
  28 full 257×131 image checks without reboot.
* Patch 0148 stores the allocator's actual allocation, unlocks after GPU late
  suspend and restores security/banks/range before GPU resume. The observed
  128-KiB allocation is not hardcoded. A first lock-only revision caused
  duplicate-lock `-EINVAL`/five `failed_resume_early` events and was rejected.
  The balanced unlock/lock revision passed the six sleep modes plus key path.
* Firmware-protected OCMEM register changes are not identified; the SCM causal
  result does not prove a specific MPU bit or explain remaining FPS loss.

Evidence: `patches/linux/0148*`, `0059*`, `0060*`.
