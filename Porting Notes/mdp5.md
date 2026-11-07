# MDP5 display controller

* Device MDP5v1.1 drives1280×800 nominal60Hz through DSI→TC358764→LVDS.
  Native connector LVDS-1 shares one MSM DRM device with Adreno305B.
* MDP SMP:7×4KiB,max3blocks perpipe. Three fullscreen RGBA planes requiring
  nine blocks do not fit.0110 exposes the final mixer stage;0111 reports
  exhaustion. Keep allocator/atomic failures visible and composite rejected sets.
* Real blue flashes at mode enable required0116: flush interface programming
  before starting the timing engine. Do not mask real MDP underruns.
* Suspend requires pipe/mixer/SMP ownership restoration (0136) and MDP/VBIF/CTL
  state/interrupt-mask restoration after runtime clock gating (0140). CPU return
  alone does not verify scanout or the contents of GPU-produced buffers.
* Captured MDP timing HFP/HBP/HS=48/48/2,VFP/VBP/VS=32/64/2. Current native mode
  reports59.999Hz, which is a scanout clock, not GUI composition throughput.
* Historical firmware RGB888 stride3840 and KWin XR24 pitch5120 differ. Main
  desktop uses native KMS; simpledrm CPU RGB888 conversion is obsolete for it.
  Early console/recovery framebuffer remains deliberate.

Evidence: [native KMS](../docs/native-kms-results.json),
[stability](../docs/graphics-stability-results.json), `patches/linux/0104*`,
`0110*`, `0111*`, `0116*`, `0136*`, `0140*`.
