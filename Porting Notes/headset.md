# 3.5-mm headset jack and buttons

* Source matisse3g r02 override: insertion detect GPIO69, send/end GPIO111,
  ADC/micbias; analog headphone output belongs to WCD9306/Tapan.
* Do not use early-r00 earjack wiring. Native ALSA jack/extcon classification,
  insertion/removal routing,3/4-pole headset microphone and button events have
  not been accepted. A source GPIO declaration is not an end-to-end jack test.
* The native audio card is not brought up; jack detection and audible output
  need separate acceptance rather than an Android audio-HAL dependency.

Evidence: [pinned board sources](../docs/hardware-source-manifest.json).
