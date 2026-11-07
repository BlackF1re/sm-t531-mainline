# MSM8226 camera interface and image processing

* Source graph: sensor CCI/I²C + MCLK/rails/reset → CSIPHY/CSID → ISPIF/VFE.
  Board endpoints are SR352 rear and SR130PC20 front; both have Android IDs,
  neither has accepted native streaming.
* Reference files: `msm8226-camera.dtsi` and
  `msm8226-camera-sensor-mtp-matisse_eur-r02.dtsi`. Establish the V4L2/media graph
  and actual DMA formats before tuning sensor controls or throughput.
* CPP/VPE/JPEG resources are source-described; exact fitted resources and
  native JPEG/mem2mem acceptance remain unresolved. Generic PM8226 flash nodes
  are not proof of a physical LED and must not be activated blindly.

* **DEVICE:** Android exposes two CSIPHY, two CSID, sensor-init,
  VFE, ISPIF, buffer-manager and CPP subdevices, plus SR352/SR130PC20.
  HAL is `Samsung MSM8226 Camera Wrapper`, module API0x100, two devices.
  A generic `msm_flash` node is present without a HAL flash-mode control.

Evidence: [pinned board sources](../docs/hardware-source-manifest.json).
