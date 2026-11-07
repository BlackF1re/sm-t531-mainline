# Board / PA thermistors

* Source paths: Samsung `sec-thermistor`, PA_THERM0/1, PMIC ADC/BCL.
* Exact fitted nets/channel assignments and calibration are not established;
  do not create generic thermal zones from shared-board ADC labels alone.
* Pinned research implementation: `arch/arm/mach-msm/sec_thermistor_8226.c`.
  That table is not proof of a measured board temperature on native Linux.

* **DEVICE:** Android thermal zones `pa_therm0`/`pa_therm1`
  reported22/−40 respectively. The −40 reading may be an absent/open or
  uncalibrated channel; neither value identifies an extra fitted thermistor.

Evidence: [pinned board sources](../docs/hardware-source-manifest.json).
