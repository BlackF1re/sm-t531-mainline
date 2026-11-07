# Adreno 305B kernel driver

* Device ID `0x03000512`, Freedreno FD305 hardware GLES. MSM8226 OPPs are
  19/200/320/450MHz; physical450MHz was verified under load. Idle may retain
  320MHz until active devfreq update despite a450MHz minimum request.
* Production is unified MSM DRM with MDP5, `separate_gpu_kms=0`; the GPU still
  has its own IOMMU mapping context. Native GPU driver is DRM MSM/A3xx.
* A305B requires three VBIF clients (0027). Drain VBIF before suspend (0024),
  reset ring pointers before recovery (0105), omit unsafe HLSQ crash reads (0106).
* If `needs_hw_init`, synchronize software ring cur/next with validated hardware
  WPTR before suspend (0131). Otherwise second sleep can compare RPTR0 with
  stale WPTR528 and return−EBUSY. Keep ring-drain/RBBM/VBIF/fence checks enabled.
* Device,2026-11-06: a lockup/recovery at~109s occurred despite matching loaded
  identities. Settings/live session restarts have also hung/crashed compositors.
  Permanent runtime-PM `on` and replacing KWin's Mesa with a test shell library
  are not accepted solutions; recovery/endurance and stable60FPS remain open.
* Counter sampling must distinguish pending GPU work from idle. HLSQ register
  probing is unsafe; overlapping pressure counters are not additive stage time.

* **DEVICE, 2026-11-07:** Android KGSL uses `msm-adreno-tz`, reports450MHz
  maximum and three power levels; snapshot frequency320MHz. Cumulative
  `reset_count=155` was observed without an attributable workload; this is not
  evidence that Android GPU operation was fault-free or a native regression.

[Android boot audit](../docs/android-hardware-observation-20261107.json).

Evidence: [physical clocks](../docs/phosh-performance-results.json),
[stack lock](../config/graphics-stack.lock.json), `patches/linux/0024*`, `0027*`,
`0105*`, `0106*`, `0131*`, `tools/sample-gpu-busy.py`.
