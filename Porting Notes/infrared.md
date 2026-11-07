# Infrared transmitter candidates

* MC96FR332/MC96FR116 descriptions belong to early/common variants: r00/r01
  include IR, r02 omits it; full matisse3g driver is disabled and GPIO4/62 are NC.
* No fitted transmitter or native transmit acceptance is established. Do not
  infer SM-T531 wiring from Wi-Fi/US variants or enable those GPIOs blindly.

* **DEVICE:** no IR binding was identified and the custom kernel
  disables `CONFIG_IR_REMOCON_MC96FR116`. Early/common variant descriptions
  remain the reason IR was considered; no populated transmitter is established.

Evidence: [pinned board sources](../docs/hardware-source-manifest.json).
