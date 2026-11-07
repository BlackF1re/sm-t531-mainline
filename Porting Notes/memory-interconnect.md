# Memory, interconnect and OCMEM

## Active clocks and votes

**DEVICE, 2026-10-15/16, GPU workload; not just software requests:**

| Clock | MHz |
|---|---:|
| DDR / BIMC KPSS AXI | 533.33 |
| GPU AXI / core | 266.67 / 450.00 |
| SNOC / PNOC / CNOC | 240 / 100 / 75 |
| MDP core | 200 |
| Historical Linux DSI pixel / byte | 74.240 / 55.680 |

`tools/measure-msm8226-bus.c` uses the BSP debug mux and XO/4=4.8 MHz.
Selector `0x155` is `gcc_bimc_kpss_axi_clk`, the BSP DDR measurement path;
`bimc_clk` naming can imply twice that rate. L2 uses KPSS diagnostic `0x1c`,
divide-by-4 and GCC selector 362. Registers are saved/restored and polling is
bounded. Never probe an unpowered DSI PLL or read the complete `clk_summary`.
An idle GPU may remain at 320 MHz until active devfreq update despite min=450;
the workload reading establishes actual 450 MHz in those cases.

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
* **DEVICE, 2026-11-03:** RPM resume returned CPU but GMEM readback was zero;
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

Sources: `tools/read-msm8226-qos.py`, [bus measurements](../docs/phosh-performance-results.json),
[OCMEM acceptance](../docs/sleep-release-validation-20261103.json),
[graphics acceptance](../docs/graphics-release-validation-20261103.json).
Low-load DDR/self-refresh, contention and whole-board power remain unverified.
