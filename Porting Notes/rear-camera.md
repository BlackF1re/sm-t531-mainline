# Rear camera — Siliconfile SR352

* Android device ID `0xc2`, approximately3MP YUV sensor. Probe/identity is
  verified; native V4L2 image capture is not.
* Board controls must come from `msm8226-camera-sensor-mtp-matisse_eur-r02.dtsi`:
  rails, reset/enables and MCLK precede CCI access and CSIPHY/CSID→ISPIF/VFE.
* Reference sensor program: `drivers/media/platform/msm/camera_v2/sensor/sr352_yuv.c`,
  including matisse tuning. Do not assume generic MTP pin/rail sequencing.
* Native complete frames, formats and controls remain unaccepted. A fitted
  flash, autofocus actuator or calibration EEPROM is not established.

* **DEVICE:** camera HAL1 reports BACK/orientation0, fixed focus
  only, still sizes up to2048×1536, preview up to1024×768 and video up to1280×720.
  These are advertised modes, not tested frame capture. No `flash-mode` control
  was reported despite generic flash/autofocus package features and a
  `msm_flash` subdevice; neither proves a fitted flash or AF actuator.

Evidence: [pinned board sources](../docs/hardware-source-manifest.json).
