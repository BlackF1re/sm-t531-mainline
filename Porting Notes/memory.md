# RAM and BIMC memory controller

* MSM8226 exposes1536MiB before reserved/CMA deductions; the exact DRAM package
  and type remain unknown. Native MemTotal is smaller and is not physical size.
* Device-measured active DDR/BIMC KPSS AXI ≈533.33MHz. Debug mux selector`0x155`
  is the BSP `gcc_bimc_kpss_axi_clk` DDR measurement path; the `bimc_clk` name
  can imply twice that frequency. Counter reference is XO/4=4.8MHz.
* Low-load scaling, self-refresh and contention latency are unverified. A
  correct active frequency does not establish optimal bus policy or sleep power.
* The bounded reader saves/restores the mux/counter; it must not program
  operating rates or probe powered-off MMSS registers.

Evidence: [physical measurements](../docs/phosh-performance-results.json),
`tools/measure-msm8226-bus.c`.
