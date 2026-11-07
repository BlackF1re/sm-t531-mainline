# Camera, ISP, JPEG and video codecs

* **DEVICE, Android:** rear Siliconfile SR352/chipID`0xc2`,~3MP YUV;
  front SR130PC20/ID`0xc1`,~1.3MP YUV. Driver probes are identity evidence,
  not Linux image-capture acceptance.
* **SOURCE:** MSM8226 CAMSS CCI/I²C, camera MCLK/rails/reset/enables,
  CSIPHY/CSID → ISPIF/VFE; CPP/VPE/JPEG resources require per-block confirmation.
  Exact pins/rails are in pinned `msm8226-camera-sensor-mtp-matisse_eur-r02.dtsi`
  and `msm8226-camera.dtsi`, not generic MTP assumptions.
* Native port needs V4L2/media graph, powered sensor IDs, CCI/resources, YUV
  formats and complete frames from both sensors before controls/performance.
  Autofocus/flash/EEPROM/OTP are not established as populated. Generic PMIC
  flash nodes do not authorize high-current LED activation.
* **DEVICE:** Venus/VIDC remoteproc/firmware appears under Android. Native
  codec path needs correct firmware/HFI, clocks/IOMMU and V4L2 mem2mem tests.
  Working Adreno OpenGL does not validate video decode/encode or JPEG.
* No native capture, AF/flash, hardware codec playback/encode or energy
  acceptance is recorded. These remain separate from desktop graphics work.

Sources: [source pins/paths](../docs/hardware-source-manifest.json),
[Android IDs](../docs/android-hardware-observation-20261022.json),
`status/hardware.yaml` camera/video task dependencies; [firmware](firmware.md).
