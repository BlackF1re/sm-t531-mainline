# ARM CoreSight trace and debug fabric

* **SOURCE (SoC):** ETM0–ETM3 CPU trace sources at `0xfc33c000`–`0xfc33f000`; ETF/TMC `0xfc307000`, ETR/TMC `0xfc322000`, TPIU `0xfc318000`, STM `0xfc321000`.
* Routing comprises replicator `0xfc31c000`, funnels `0xfc319000`/`0xfc31a000`/`0xfc31b000`, A7SS `0xfc345000`, MMSS `0xfc364000`, plus CoreSight CSR `0xfc302000`; CTI blocks span `0xfc308000`–`0xfc310000` and CPU/L2/remote-processor endpoints. The vendor tree also describes audio/modem/WCNSS/RPM trace sources and JTAG-MM windows.
* **Status:** silicon debug IP, *not* proof of populated external JTAG pins, authorized register access or accepted native trace collection. Secure/clock-gated registers may fault; avoid speculative raw MMIO reads.
* Source: [source manifest](../docs/hardware-source-manifest.json), `msm8226-coresight.dtsi`. See [TrustZone](trustzone.md).
