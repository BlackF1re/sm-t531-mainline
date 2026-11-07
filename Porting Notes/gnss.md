# GNSS / GPS

* GPS antenna/location capability is source-documented for SM-T531. No native
  satellite position fix is accepted; supported constellations and exact RF
  parts remain unestablished.
* Control through modem QMI LOC is a **HYPOTHESIS**, not an implemented path.
  Modem remoteproc/firmware/resource operation must first be established.
* No cold-fix, tracking, power/suspend or location-triggered wake acceptance.
  Preserve modem/WCNSS factory calibration; do not synthesize RF/NV data.

Evidence: [pinned board sources](../docs/hardware-source-manifest.json).
