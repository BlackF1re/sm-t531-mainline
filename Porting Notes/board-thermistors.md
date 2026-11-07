# Board / PA thermistors

* Source paths: Samsung `sec-thermistor`, PA_THERM0/1, PMIC ADC/BCL.
* Exact fitted nets/channel assignments and calibration are not established;
  do not create generic thermal zones from shared-board ADC labels alone.
* Pinned research implementation: `arch/arm/mach-msm/sec_thermistor_8226.c`.
  That table is not proof of a measured board temperature on native Linux.

Evidence: [Android probe data](../docs/android-hardware-observation-20261022.json), [pinned board sources](../docs/hardware-source-manifest.json).
