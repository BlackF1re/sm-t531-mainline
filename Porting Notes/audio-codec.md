# WCD9306 / Tapan audio codec

* Android identified WCD9306 with `tapan-slim-ifd`, `tapan-slim-pgd`,
  `msm8226-tapan-snd-card` / `msm8226-asoc-tapan`. SLIMbus NGD/BAM, MCLK9.6MHz.
* Native card/output/input are not brought up. ADSP/LPASS APR/AFE/ASM and
  powered SLIMbus/codec routes must precede ALSA/UCM/PipeWire acceptance.
* Source board endpoints: two speakers, GPIO23/24 enables, main microphone and
  headphone DAC/amplifier. Additional mic routes remain board-dependent.
* Real stereo playback/recording, safe volume, routing and power transitions
  are unaccepted. Use matisse conditionals in `sound/soc/msm/msm8226.c` rather
  than treating every Tapan reference-board route as fitted.

* **DEVICE, 2026-11-07:** WCD9306 detection and Tapan ALSA card were repeated;
  ADSP is ONLINE. DT reset is GPIO72, MCLK9.6MHz, CFILT1/2/3=2800mV;
  h/px rails1.8V, cx1.2V, buck1.8–2.15V, helper1.775–2.125V (configured ranges).
  Generic PCM endpoints include FM, BT-SCO, HDMI and voice/VoLTE; registration
  does not establish those external connectors, radio standards or sound.

Evidence: [pinned board sources](../docs/hardware-source-manifest.json).
