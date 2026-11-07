# BLSP / QUP buses: I²C, SPI and UART

* **SOURCE (r02):** hardware I²C QUP at `0xf9924000` (K2HH `0x1d`), `0xf9927000` (MXT1188S `0x4a`), `0xf9925000` (LP8556 `0x2c`); `0xf9926000` (SM5502 QUP representation); `0xf9923000` (QUP1 I²C in r02 top-level DTS). These MMIO addresses are not Linux adapter numbers.
* r02 GPIO-I²C pairs (SDA/SCL): GPIO0/1 SX9500 `0x28`, 2/3 TC358764 `0x0f`, 10/11 SMB358 `0x6a`, 12/13 ISA1200 `0x48`, 14/15 SM5502 `0x25`, 20/21 LP8556 `0x2c`. Overlapping QUP/GPIO descriptions do not establish two physical controllers: never activate masters simultaneously on shared wires.
* **CAUTION:** shared SPI QUP1 also claims `0xf9923000`. r02 uses `/spi0 { status = "disable"; }`, which neither targets the `spi@f9923000` phandle nor uses standard `"disabled"`. The KS8851 client likewise uses `"disable"`; do **not** assume these nodes are actually disabled. QUP1 I²C/SPI register-space collision and GPIO0–3 conflicts require reviewing the *effective FDT* before enabling either path.
* The shared legacy UART `serial@f991f000` specifies `status = "disabled"`; r02 does not demonstrate a wired console. Accepted diagnostics use USB ACM.
* **Native:** K2HH, touch, backlight and MUIC have separate accepted/bounded results. Source: [pinned source manifest](../docs/hardware-source-manifest.json), `msm8226.dtsi`, `msm8226-sec-matisse3g-r02.{dts,dtsi}`.
