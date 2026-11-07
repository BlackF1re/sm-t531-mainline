# Front camera — Siliconfile SR130PC20

* Android device ID `0xc1`, approximately1.3MP YUV sensor. Native capture is
  not accepted; successful probe is identity evidence only.
* Reference program: `drivers/media/platform/msm/camera_v2/sensor/sr130pc20_yuv.c`.
  Use the matisse r02 camera DTS for supplies/reset/MCLK and the actual CCI/
  CSIPHY/CSID route; do not copy the rear sensor sequence by analogy.
* Bring-up needs powered ID, V4L2 formats/controls and complete frames through
  ISPIF/VFE. Flash/AF/EEPROM population is unestablished.

Evidence: [Android probe data](../docs/android-hardware-observation-20261022.json), [pinned board sources](../docs/hardware-source-manifest.json).
