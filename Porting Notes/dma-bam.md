# SPS / BAM DMA and modem multiplexing

* **SOURCE (SoC):** Qualcomm SPS (shared pipe service) at `0xf9984000` (0x15000) and `0xf9999000` (0xb000); USB BAM `qcom,usb-bam-msm` at `0xf9a44000` (16 configured pipes); BAM-DMUX `qcom,bam_dmux` at `0xfc834000`.
* Other BAM consumers include legacy QUP SPI (DMA window `0xf9904000`, QUP1 disabled on r02) and Qualcomm crypto engine (BAM `0xfd404000`). Pipes, IRQs, bus clocks and memory ownership are per-client resources, not interchangeable DMA channels.
* **Porting:** USB BAM availability does not establish USB host operation; BAM-DMUX configuration does not establish a working MPSS/QMI data path. No independent native SPS/BAM-DMUX functional acceptance is recorded.
* Source: [source manifest](../docs/hardware-source-manifest.json), `msm8226.dtsi`, `msm8226-sec-matisse3g-r02.dts`. See [USB](usb.md), [modem](modem.md) and [QCE](cryptography.md).
