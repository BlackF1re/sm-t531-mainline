# MDP5, DSI, TC358764 and LCD

* **DEVICE:** MDP5 v1.1 → DSI/28-nm PHY → Toshiba TC358764 → LVDS LCD,
  1280×800 nominal60 Hz; panel supplier unconfirmed. Native connector `LVDS-1`.
  Unified DRM/planes are described in [gpu](gpu.md).
* Firmware transport is RGB888/3840-byte stride; historical KWin XR24 uses
  5120-byte pitch. Old simpledrm performed CPU copy/format conversion; main
  desktop uses native KMS. NEON conversion patch0046 is legacy, not current
  desktop throughput. Early boot simplefb is deliberately retained.
* MDP SMP is seven 4-KiB blocks, max three per pipe. Three fullscreen RGBA
  planes needing nine blocks cannot fit: failed atomic overlay candidates
  must be composited. Patch0110 exposes the final mixer stage; 0111 reports
  resource exhaustion. Hardware overlays do not make arbitrary layer sets free.

## Necessary board initialization

* Display SMMU differs from GPU ARM SMMU: generic IDR0 read `fd928020` aborted.
  Use legacy qcom_iommu with secure config ID1, context0 `fd930000`; power parent
  before probing. GPU/display mappings remain distinct even in one DRM device.
* Patches0062–0067,0079–0101 preserve short descriptors, HLOS BFB tables,
  terminate-fault policy, context halt/TLB/ASID ordering and security attributes.
  **Causal result:** 0097 shared TrustZone initialization made nine page and
  three section translations match RAM; unmapping then produced a real fault.
  0098 avoids reserved TCR2 writes on short-descriptor contexts; 0101 issues
  TLBSYNC after releasing halt. Do not replace this with guessed global reads.
* CCF cached the indirect DSI byte parent while hardware used direct VCO,
  doubling byte clock. 0065 prepares RCG parents; 0100 replays the byte mux on
  prepare. Factory PHY timing/PLL/BTA/command-fetch settings are board-specific.
* Sole topology/profile config: `config/msm.conf`, `separate_gpu_kms=0`,
  `matisse_lp11_reset=1`, `matisse_defer_video=1`, `matisse_phy_profile=7`.
  TC358764 transfer length, first initialization, LP11 reset, per-lane PHY,
  deferred video and PLL comparison fixes are in patches0047–0100.
* **DEVICE reference:** bridge I²C SDA2/SCL3, address `0x0f`, ID `0x6500`.
  Register addresses big-endian, returned data little-endian. PPI LP count4,
  TX_RX_TA `0x50006`, all CLRSIPO4, lane enables `0x1f`, VP_CTRL `0x03f00120`,
  HTIM1/2 `0x00300002/0x00300320`, VTIM1/2 `0x00400002/0x00200500`,
  LV_CFG1, LV_PHY0 `0x48006`. Stored bridge timing words need interpretation
  with the vendor transport; do not equate them blindly to DRM dimensions.
* Captured MDP timing: HFP/HBP/HS=48/48/2, VFP/VBP/VS=32/64/2.
  Firmware pixel/byte ~76.333/57.250 MHz, historical native74.240/55.680;
  firmware SDM DC10/seed`0xed4f`, postdiv3=5 implies ~458-MHz VCO.
  Profile7 reproduced the full test pattern; current mode reports59.999 Hz.
  Changing mode clock without PLL/mux validation caused misleading 61.68-Hz flips.
* Patch0135 controls LCD enable through PM8226 GPIO2 with vendor reset/enable
  order. Separate bridge supplies are not fully identified; L5/firmware power
  retention remains. Backlight off is not proof of complete panel power-off.

## Errors, suspend and unsafe probes

* Null-context fault handling (0112), ARM32 premature DMA attachment (0113)
  and MDP-owned DMA domain (0114) fix crashes; never dereference absent domains.
* 20,000 FIFO/line samples found HS underflow flags only in blanking (zero in
  17,816 active-line samples). Patch0115 masks the MSM8226 video-blanking FIFO
  IRQ sources, retaining real error handling; old IRQ storms were not proof of
  visible payload underrun. 0108 preserves IRQ-time W1C syndrome; 0109 changes
  summary acknowledgement order, without an isolated FPS benefit.
* Blue flashes from real MDP mode-enable underruns required patch0116: flush
  the interface before starting its timing engine. Do not mask MDP underruns.
* Suspend: restore pipe/mixer/SMP allocator ownership (0136), MDP/VBIF/CTL and
  interrupt mask after runtime clock gating (0140). CPU resume alone does not
  validate scanout or pixel data; see [power management](power-management.md).
* **Unsafe:** unpowered PLL read at `fd922ac0`, full `clk_summary`, protected
  CBAR/global IOMMU reads and live MSM unload caused SIGBUS/Oops/hangs. A PLL
  Oops may leave CCF locked and stall storage. Use bounded powered allowlists
  in `tools/read-dsi-controller.c`; hardware TPG/white pattern alone cannot
  prove MDP buffer delivery. Keep modetest alive while visually checking it.

Primary data: [native KMS](../docs/native-kms-results.json),
[first-frame](../docs/native-first-frame-results.json),
[stability](../docs/graphics-stability-results.json),
[sleep release](../docs/sleep-release-validation-20261103.json).
Cold init/full rail ownership, endurance and GPU recovery remain incomplete.
