# Qualcomm JPEG hardware engine

* **SOURCE (SoC):** standalone `qcom,jpeg` at `0xfda1c000` in `msm8226-camera.dtsi`; GDSC `gdsc_jpeg` at `0xfd8c35a4` and legacy IOMMU `jpeg_iommu` at `0xfda64000`. This is distinct from Venus video coding, GPU shaders and the camera sensor itself.
* **Native:** no accepted JPEG DMA/encode/decode path, image format, contiguous buffer handling or sustained workload. Driver availability/probe is not evidence that the device produces correct images. Initialization requires its own clocks, power domain, IOMMU mappings and memory ownership.
* The shared camera tree describes the block, not a separate JPEG chip or physically fitted camera flash. Source: [source manifest](../docs/hardware-source-manifest.json), `msm8226-camera.dtsi`, `msm-gdsc.dtsi`, `msm8226-iommu.dtsi`.
