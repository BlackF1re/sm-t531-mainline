# BLSP / QUP buses: I²C, SPI and UART

* **SOURCE (r02):** MSM8226 QUP controllers: I²C at `0xf9924000` (K2HH `0x1d`), `0xf9927000` (MXT1188S `0x4a`), `0xf9925000` (LP8556 `0x2c`); `0xf9926000` also appears as a QUP controller. Controller MMIO addresses are not Linux I²C adapter numbers.
* r02 GPIO-driven I²C pairs (SDA/SCL): GPIO0/1 SX9500 `0x28`, 2/3 TC358764 `0x0f`, 10/11 SMB358 `0x6a`, 12/13 ISA1200 `0x48`, 14/15 SM5502 `0x25`, 20/21 LP8556 `0x2c`. Backlight and MUIC have overlapping QUP/GPIO-I²C descriptions: do not activate competing masters on the same wires.
* SPI QUP1 `0xf9923000` is disabled in the r02 top-level DTS; the downstream KS8851 Ethernet client is disabled. Its legacy GPIO0–3 assignment conflicts with r02 GPIO-I²C clients; neither SPI Ethernet nor an external connector is established.
* Legacy UART `0xf991f000` is enabled in the r02 top-level DTS, but the actual tablet has no verified wired console. USB ACM is the accepted diagnostic transport.
* **Native:** K2HH, touchscreen, backlight and MUIC have their own accepted or bounded results; see their component notes. Source: [source manifest](../docs/hardware-source-manifest.json), `msm8226.dtsi`, `msm8226-sec-matisse3g-r02.{dts,dtsi}`.
