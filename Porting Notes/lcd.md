# LVDS LCD panel

* Physical10.1-inch1280×800,nominal60Hz; exact panel supplier is unconfirmed.
  Transport: MDP5→four-lane DSI/28-nm PHY→TC358764→LVDS; LP8556 drives backlight.
* Native DRM connector LVDS-1 and full test pattern/desktop were device-accepted.
  Short modeset success does not establish cold initialization, full supply
  ownership, stable sleep recovery or long-duration image correctness.
* Panel enable uses PM8226GPIO2 with vendor reset/enable ordering (0135).
  L5/firmware supply retention is still used; separate bridge/panel rails are
  incompletely mapped. A dark backlight is not proof the panel link is off.
* Source panel description is `dsi_panel_tc358764_wxga_video-r01.dtsi`.
  Do not select a generic similarly sized panel or infer physical PCB revision
  from its r02 DT model string.

* **DEVICE:** Android selects
  `qcom,mdss_dsi_tc358764_wxga_video`, continuous splash enabled, partial update
  disabled. Physical fb0 is1280×800, virtual1280×1600,32bpp/stride5120.
  `fb0/modes` prints `p-1`: do not infer panel refresh from that vendor string.
  fb1 is the registered writeback panel, not a second physical display.

Evidence: `patches/linux/0051*`, `0135*`, [vendor pins](../docs/hardware-source-manifest.json).
