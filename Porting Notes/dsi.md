# MSM8226 DSI host and 28-nm PHY

* Four-data-lane DSI feeds TC358764/LVDS1280×800. Board profile in
  `config/msm.conf`: matisse_lp11_reset=1,matisse_defer_video=1,
  matisse_phy_profile=7 with unified separate_gpu_kms=0.
* CCF cached an indirect byte parent while hardware selected direct VCO,
  doubling the effective byte clock.0065 prepares RCG parents;0100 replays
  the byte mux during prepare. Command-fetch/BTA/per-lane PHY are board-specific.
* Reference firmware pixel/byte76.333/57.250MHz; historical native74.240/55.680.
  Firmware SDM DC10/seed0xed4f,postdiv3=5 implies~458MHz VCO. Profile7 gave the
  full test pattern. A nominal clock change without mux/PLL checks produced
  misleading61.68Hz flips; software requests alone do not prove physical rate.
*20,000FIFO/line samples found HS-underflow flags only in blanking,0in17,816
  active-line samples.0115 masks MSM8226 video-blanking FIFO IRQ sources while
  preserving real error handling. A nonzero sticky FIFO register is not by
  itself an active-pixel underrun.0108 preserves IRQ-time W1C syndrome;0109
  changes summary-ack order without demonstrated isolated FPS benefit.
* Full PHY interface-clock unprepare experiment0143 returned s2idle/retention
  but failed RPM return and is excluded. Disable can retain a parent prepare/XO
  request; neither method is a proven whole-SoC power solution.
* Never read powered-off PLL `fd922ac0` or complete clk_summary: recorded Oops
  can leave CCF locked and stall storage. Use only bounded active-host register
  allowlists. Keep modetest active during image checks; TPG alone bypasses MDP.

Evidence: [first-frame](../docs/native-first-frame-results.json),
[native KMS](../docs/native-kms-results.json), `tools/read-dsi-controller.c`,
`patches/linux/0065*`, `0068*`–`0078*`, `0086*`, `0099*`, `0100*`, `0108*`, `0109*`, `0115*`.
