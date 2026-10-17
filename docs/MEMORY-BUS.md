# SM-T531 memory and graphics fabric measurements

Evidence captured2026-10-15, MSM8226/Adreno305b, native split GPU/KMS,
Mesa25.0.7 Debian, Phoc0.46/Phosh0.58. No DDR or GPU overclock.

## Physical rates, not only software requests

`tools/measure-msm8226-bus.c` measures hardware debug-clock counter ticks
against XO/4 (4.8MHz). The selector table and integer counter conversion
come from the [Samsung clock driver](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/mach-msm/clock-8226.c).
In particular mux0x155 is named `gcc_bimc_kpss_axi_clk`; the BSP explicitly
uses it to measure DDR frequency instead of `bimc_clk` at twice that rate.

VERIFIED_DEVICE during visible drawer load at fixed GPU450MHz:

| Physical clock | Observed MHz |
| --- | ---: |
| DDR / BIMC KPSS AXI | 533.33 |
| GPU AXI | 266.67 |
| GPU core | 450.00 |
| SNOC | 240.00 |
| PNOC | 100.00 |
| CNOC | 75.00 |
| MDP core | 200.00 |
| DSI pixel | 74.240 |
| DSI byte | 55.680 |

Idle GPU can physically remain320MHz until the next active devfreq update,
even with min_freq450MHz; the under-load counter confirms450MHz. Do not
mistake the idle reading for a sustained GPU clock failure. The requested
OCMEM peak at GPU450MHz is6.4GB/s over a16-byte bus, i.e.400MHz; the static
A3xx3.6GB/s vote alone is not the final load vote. Actual OCMEM frequency
has not yet been measured. DDR scaling at low CPU/GPU load and sleep, bus
latency under contention, and fault recovery remain UNKNOWN.

The measurement tool changes only the debug selector/counter and its XO
reference branch. It saves and restores the original registers, verifies
restoration, rejects an already running counter, locks against another
instance, bounds polling, and requires powered MMSS clocks for MMSS
measurements. It does not program operating rates, voltage or PLLs. Never
read a powered-off DSI PLL or full clk_summary on this port.

Private raw evidence (may include identifiers; do not commit wholesale):
`.work/phosh/hardware-bus-clock-evidence/0105-hardware-bus-clock-profile3/`
and `.work/phosh/0107-evidence/`. Device copies are under
`/var/lib/t531/0105-hardware-bus-clock-profile3` and
`/var/lib/t531/0107-local-nodes-profile`. Public numeric results are in
`docs/phosh-performance-results.json`.

## RPM resource corrections

VERIFIED_VENDOR_SOURCE: in [msm8226-bus.dtsi](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/boot/dts/msm8226/msm8226-bus.dtsi),
MMSS-to-memory is a locally controlled NoC bridge, not RPM slave16. The
OCMEM graphics virtual master has no physical master ports; the
[NoC bandwidth code](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/mach-msm/msm_bus/msm_bus_noc.c)
skips its RPM master vote. Clock aggregation still uses OCMEM slave18.

Patch0107 removes the invalid slave16/master55 RPM messages and stops
ignoring arbitrary ENXIO errors. Real aggregate votes and clock rates are
unchanged. VERIFIED_DEVICE: the new kernel boots into native GUI, and the
recurring RPM ENXIO messages disappear. This is an interconnect correctness
fix; the FPS difference is too small to establish a performance benefit.

## Local QoS comparison

The vendor MMSS NoC QoS stride is0x80, unlike the common upstream ICC NoC
stride0x1000. Never simply fill in common-provider qos_port values for this
hardware. `tools/read-msm8226-qos.py` reads only a fixed, documented register
allowlist. The physical initial MDP/GPU modes both read0 (Fixed); priority,
bandwidth and saturation registers read0. BIMC CPU/MMSS mode reads0x11,
with BKE and priority overrides0, i.e. no BKE bandwidth limiter enabled.

A bounded diagnostic module temporarily selected the BSP Bypass mode2 for
MDP qport1/GPU qport2, without changing bus clocks or voltage. Both values
were restored after the test; the module was removed. It has a60-second
independent in-kernel restore timer. This experiment did not improve FPS:

| Configuration | Active presentation FPS | Frame p50 / p95, ms | Submit-to-retire p50 / p95, ms |
| --- | ---: | --- | --- |
| 0105, measured clocks | 33.33 | 33.33 /49.99 | 22.19 /30.22 |
| 0107, corrected local RPM nodes | 34.37 | 33.33 /33.38 | 21.84 /27.92 |
| 0107, temporary BSP QoS Bypass | 34.05 | 33.33 /33.38 | 20.63 /28.09 |

All three runs: system Mesa, GPU450MHz under load, four automated open/close
cycles,15-second recording, zero logged MDP underruns. Presentation bursts
exclude gaps over100ms; these are DRM presentation timings, not optical
frame measurements. Submit-to-retire includes queueing and IRQ delivery,
not just GPU execution. Whole-recording GPU utilization includes pauses.
The approximately1FPS differences are not sufficient for a causal claim.
No Phosh animation/effect/texture quality setting was changed.

## Remaining DSI IRQ investigation

VERIFIED_DEVICE on0108 module: raw IRQ-time capture shows FIFO0x99991000,
timeout0x1, ACK0, PHY0x88888. The old worker reread W1C status after it was
cleared; patch0108 preserves the actual syndrome instead. DSI can generate
hundreds to thousands of interrupts per second while MDP scanout has no
logged underrun. Detailed FIFO bits include actual HS underflows as well
as ordinary empty flags; a nonzero register is not by itself an error.

The active HS timer is0xffff with resolution0, LP timer0xffffffff. The HS
status and its relationship to the IRQ source need distinguishing: timeout
mask bits can be masked even when sticky timeout status is nonzero. Neither
this observation nor its possible one-frame periodicity proves that the
timer causes the IRQ storm or the30FPS plateau.

Patch0109 is a separate diagnostic candidate changing summary-ack order and
ignoring masked error processing, following a [later Qualcomm driver](https://android.googlesource.com/kernel/msm/+/ddc71b24ab0b8cb5bc73f6e9a89bdb48da052cd8/drivers/video/fbdev/msm/mdss_dsi_host.c).
The pinned older Samsung BSP still acknowledges the summary first. This
candidate does not change display timings, error masks, clocks or voltage.
VERIFIED_DEVICE: clean-boot comparison gives33.89FPS on0108 and33.81FPS
on0109; recurring DSI IRQs remain. This candidate has not fixed the IRQ
storm and is not a demonstrated performance improvement. Current module0111
includes this change; its ordering must be reviewed separately from FPS.

Bounded GPU counters and the independent texture-layout AB-A comparison
are described in [GRAPHICS-BOTTLENECK.md](GRAPHICS-BOTTLENECK.md). They
support substantial texture-path cost at correctly measured operating
rates: four bilinear blended layers25.55 →15.91 →25.41ms. They do not
validate low-load DDR scaling, suspend or general bus QoS under contention.


VERIFIED_DEVICE,2026-10-16: after a long system suspend/resume (about10704s
sleep on this boot), repeated hardware-debug-counter measurements during
ordinary Phosh drawer animation give DDR533.337MHz, GPU AXI266.666MHz,
GPU450.003MHz. All debug registers are restored/read back. Recording:
`0110-after-resume-hardware-clocks`,32.273FPS, no logged MDP underruns.
This verifies those three active rates for this resume; it does not prove
all suspend/resume behavior, low-load DDR policy, or OCMEM physical rate.


VERIFIED_DEVICE: CPU frequency is independently checked with the Cortex-A7
PMU cycle counter, not only cpufreq:483,499,967cycles over406.20ms task CPU
time gives1.190GHz, matching1190400kHz. A400ms integer workload is pinned
to CPU1. This does not measure L2 frequency. Other PMU events (instructions,
L1/L2 refills) return zero in a later memory test and are not accepted as
valid cache evidence. Actual active CPU/GPU/DDR/GPU-AXI rates therefore all
match their requests in the measured cases; no overclock is applied.

A cached CPU-memory microbenchmark, pinned to CPU1, copies4.096MB in
median about4.6ms and packs4x4 RGBA with NEON in about9.4ms after warmup;
memset about1.5ms. First-touch adds1002 minor faults; later iterations have
zero. This supports significant CPU packing cost even in cached memory;
it does not prove a frequency or cache-enable bug. The attempted direct
CPU tile upload is not a demonstrated performance fix. Private evidence:
`cpu-hardware-clock-perf.txt`, `cpu-tile-memory-bench.txt`.


2026-10-16 additional CPU clock cross-check (VERIFIED_DEVICE): native
memory/compositing workload pinned to CPU3 records11,853,682,844 cycles
in9,958.19ms task-clock (1.190GHz); CPU1 records11,837,204,446 cycles in
9,983.24ms (1.186GHz including startup). This independently confirms the
CPU clock during that workload on two cores. It does not establish every
core or idle transition. No PLL/MMIO setting is changed. Evidence:
`.work/phosh/pixman-cpu3-stat.csv`, `pixman-cpu1-perf.txt`.

## CPU cache control and dependent-load latency

VERIFIED_DEVICE,2026-10-16: `tools/cpu-cache-state/` reads standard CP15
registers on all four Cortex-A7 cores. SCTLR=0x10c5387d enables MMU, data
and instruction caches; ACTLR=0x00006040 enables SMP coherency. CCSIDR
reports32KiB L1D,32KiB L1I and1MiB shared L2. The temporary cache selector
is restored and read back on each core; the module is then removed.

VERIFIED_UPSTREAM: [Arm Cortex-A7 TRM, ACTLR table4-53](https://documentation-service.arm.com/static/5e8f089d88295d1e18d3b906)
defines ACTLR[14:13]=3 as three outstanding L1 data prefetch requests,
the reset value. L1/L2 read-allocation disable bits are clear. No control
register is changed to tune this result. Evidence:
`.work/phosh/cpu-cache-state-device.txt`.

`tools/cache-latency.c` then traverses a shuffled single cycle of64-byte
cache lines. Each load depends on the previous one, preventing parallel
loads; three2,097,152-load samples per size are pinned to each core.
Ordinary Phosh stays running. CPU1 andCPU3 remain at1190400kHz.

| Working set | CPU1 median ns/load | CPU3 median ns/load |
| --- | ---: | ---: |
| 4KiB | 2.524 | 2.523 |
| 16KiB | 2.527 | 2.545 |
| 64KiB | 11.131 | 11.010 |
| 256KiB | 13.836 | 13.615 |
| 1MiB | 47.459 | 49.788 |
| 4MiB | 123.848 | 123.386 |
| 16MiB | 131.459 | 132.039 |

The observed tiers support functioning caches, in addition to their enable
bits. Shared-cache contention, TLB misses and loop overhead are included;
this is neither an isolated DRAM latency nor an L2 clock measurement.
It does not validate every idle/suspend transition or prove optimal memory
throughput under simultaneous CPU/GPU/display load. Raw72 samples:
`.work/phosh/cache-latency-device.jsonl`; public medians in
`docs/phosh-performance-results.json`.

VERIFIED_DEVICE: L2 frequency is now measured independently as well.
The extended `tools/measure-msm8226-bus.c` follows the exact BSP
`measure_mux_APSS` path: KPSS global diagnostic register0x1c, divide-by4,
GCC debug selector362 and XO/4 counter. It saves/restores and verifies the
diagnostic register in addition to GCC state; no operating mux, PLL or
test-pad register is programmed. A bounded CPU workload runs first onCPU1,
thenCPU3, with ordinary Phosh active. Three readings per clock/load give:

| Physical clock | Observed MHz |
| --- | ---: |
| CPU1 | 1190.402 |
| CPU3 | 1190.398 |
| Shared L2 | 1190.402 |
| DDR | 533.332 |

All18 measurements verify diagnostic-register restoration. Raw evidence:
`.work/phosh/l2-hardware-clock-device.jsonl`. L2 is not observed stuck at
a low clock in these active cases. OCMEM physical rate and general
idle/suspend clock policy remain unverified.
