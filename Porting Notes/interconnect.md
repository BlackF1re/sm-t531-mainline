# MSM8226 interconnect

## Active clocks and votes

**DEVICE, 2026-10-15/16, GPU workload; not just software requests:**

| Clock | MHz |
|---|---:|
| DDR / BIMC KPSS AXI | 533.33 |
| GPU AXI / core | 266.67 / 450.00 |
| SNOC / PNOC / CNOC | 240 / 100 / 75 |
| MDP core | 200 |
| Historical Linux DSI pixel / byte | 74.240 / 55.680 |

The active-rate samples use the BSP debug-clock counter against XO/4=4.8MHz,
not software requests. Saved mux/counter registers are restored and polling is
bounded. No operating PLL/rate/voltage is changed by the measurement.

**SOURCE, Android DT:** peak requests, not measured bandwidth:

| GPU MHz | GFX→DDR kB/s | GFX→OCMEM kB/s |
|---:|---:|---:|
| 450 | 4256000 | 6400000 |
| 320 | 3200000 | 5120000 |
| 200 | 1600000 | 3200000 |
| 19 | 0 | 0 |

6.4 GB/s over a 16-byte OCMEM bus implies a 400-MHz request; the actual OCMEM
physical rate remains unmeasured. Linux additionally supplies a nonzero average
DDR vote. Patch 0042 fixes GPU AXI scaling; 0055–0061 implement ICC/OCMEM voting.
Patch 0107 removes invalid RPM slave16/master55 messages: MMSS-to-DDR is local,
and the OCMEM virtual master has no physical master ports; slave18 aggregation
still supplies its clock. Do not suppress arbitrary ENXIO errors.

## QoS and sleep

* MMSS NoC QoS stride is `0x80`, not generic-provider `0x1000`.
  MDP/GPU mode 0=Fixed and zero priority/bandwidth/saturation were observed;
  BIMC mode `0x11` had no BKE limiter. Temporary BSP Bypass mode 2 gave
  34.05 vs 34.37 presentations/s: no established FPS improvement.
* Active-only CPU/GPU/MDP/OCMEM votes: patch 0138 (`RPM_ACTIVE_TAG`). Bootstrap
  maximum RPM clock requests must not leak into sleep-set (0139). MMSS local
  clock is released in suspend_late and restored in resume_early (0142).

Topology: APSS/CPU and [Adreno](gpu.md) request DDR through BIMC/SNOC/MMSS;
[MDP5](mdp5.md) is another display master. GPU-local allocations also use
[OCMEM](ocmem.md); its virtual master vote is not a physical DDR port.
The links identify endpoints, not missing setup instructions.

Evidence: [measured buses/QoS](../docs/phosh-performance-results.json),
`patches/linux/0055*`–`0061*`, `0107*`, `0138*`, `0139*`, `0142*`,
`tools/read-msm8226-qos.py`, `tools/measure-msm8226-bus.c`.
Low-load policy, contention and whole-board power remain unverified.
