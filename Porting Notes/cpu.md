# CPU, voltage and idle

* MSM8226: four Cortex-A7, ARMv7/NEON/VFPv4, shared L2/SAW2; physical RAM 1536 MiB
  before reserved/CMA deductions. Exact DRAM package/type is unknown.
* **SOURCE/DEVICE:** OPPs 300/384/600/787.2/998.4/1094.4/1190.4 MHz.
  `config/kernel.fragment` selects schedutil and `ARM_QCOM_CPUFREQ_NVMEM`.
* Patches 0018, 0025–0029: SAW/SPM CPU voltage, CPU-memory rail, RPM-CX OPP
  voting. Patch 0021: secondary-CPU standalone collapse/hotplug. Restore APC
  voltage before secondary CPUs/cpufreq resume; changing frequency alone is
  insufficient to reproduce vendor DVFS.
* Ordinary cpuidle: WFI and per-core SPC. Source wake latencies 1/500 µs,
  SPC minimum residency 2 ms; source coordinated PC latency 550 µs is not an
  implemented coupled cluster-idle governor. System suspend separately selects
  L2 retention/GDHS/standalone/RPM; those paths do not add coupled cluster idle.
* **DEVICE:** PMU 483,499,967 cycles / 406.20 ms task CPU time ≈
  1.190 GHz at requested 1,190,400 kHz. CPU1/3 physical readings ≈1190.40 MHz;
  shared L2 ≈1190.40 MHz. Do not infer L2 frequency from cpufreq alone.
* CPU SCTLR has cache/MMU bits enabled; ACTLR SMP enabled. Dependent-load
  medians on CPU1: 4/16 KiB ≈2.52 ns, 64 KiB 11.13 ns, 256 KiB 13.84 ns,
  1 MiB 47.46 ns, 4/16 MiB ≈124/131 ns. These include TLB/loop/contention.
  Other PMU events returned invalid zero counts; no cache-miss claim follows.
* Cached 4.096-MB copy ≈4.6 ms, memset ≈1.5 ms, NEON RGBA 4×4 packing ≈9.4 ms.
  First touch added ~1002 minor faults; warm iterations added none. This does
  not prove a cache-enable bug or justify CPU tile packing as a GPU fix.

Sources: `tools/cache-latency.c`, `tools/cpu-cache-state`,
`tools/measure-msm8226-bus.c`, corresponding Linux patches above.
Low-load DVFS, thermal/voltage transitions and long hotplug/suspend acceptance
remain incomplete; no overclock is selected.

The L2 physical-clock reader uses the BSP measure_mux_APSS path:KPSS global
diagnostic register0x1c,divide-by4,GCC selector362 and XO/4. It restores/verifies
both KPSS and GCC state without programming operating PLLs/test-pad registers.
ARM PMU and CoreSight/JTAG fabric are SoC debug resources; CoreSight/JTAG
access and an external UART console have not been established.
