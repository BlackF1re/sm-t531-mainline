# Firmware reservations and shared RAM

* **SOURCE (legacy MSM8226):** `qcom,msm-mem-hole` excludes `0x08400000+0x04000000`, `0x0cb00000+0x02b00000`, `0x0fa00000+0x00500000` and `0x10000000+0x00600000`. Legacy `secure_mem`/`adsp_mem`/`qsecom_mem` specify contiguous-pool *sizes* (0x06d00000/0x02a00000/0x00d00000), not fixed physical base addresses.
* Legacy shared windows: RMTFS `0x0fd80000+0x00180000`; DSP/modem RFSA `0x0fd60000+0x00020000` (two names for the same window). Their vendor roles do not authorize blindly copying these reservations into the current mainline DT.
* **DEVICE/native:** firmware scanout at `0x03200000` constrains decompressor/DT placement. Patches reserve lk2nd ramoops `0x2ff80000+0x00080000`: two 128-KiB records and a 256-KiB console; warm-restart retention was observed, power-loss retention was not.
* Distinguish RAM-carveout, ION/CMA allocation, firmware live mappings and physical DRAM size. Check the deployed FDT and `/proc/iomem` before changing boundaries; firmware/NV contents remain private.
* Source: [source manifest](../docs/hardware-source-manifest.json), `msm8226.dtsi`, `msm8226-ion.dtsi`, patch 0023. See [boot](boot.md) and [firmware](firmware.md).
