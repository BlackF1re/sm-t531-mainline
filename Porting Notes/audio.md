# Audio and headset

* **DEVICE under Android:** WCD9306/Tapan detected; `tapan-slim-ifd`,
  `tapan-slim-pgd`, ALSA `msm8226-tapan-snd-card`/`msm8226-asoc-tapan`.
  Transport SLIMbus NGD/BAM, MCLK9.6MHz, Q6 ADSP/LPASS/AFE/ASM/APR.
* **SOURCE:** two speakers, GPIO23/24 enables; main microphone and3.5-mm jack.
  Additional mic routes remain board-dependent. r02 earjack override:
  detect GPIO69, send/end GPIO111, ADC/micbias. Do not reuse early-r00 wiring.
* Native audio card/output/input are not brought up. Order: verified ADSP
  firmware/resources → remoteproc/APR → SLIMbus/WCD9306 → ALSA routes →
  UCM/PipeWire. Playback/recording/jack detection are separate acceptance tests.
* Bluetooth profile endpoints do not validate board audio or SCO/PCM routing.
  FM Android `MultiMedia2 Mixer INTERNAL_FM_TX`/PCM0,1 capture produced frames
  without RF lock; it is not audible reception or a native audio port.

Sources: `docs/hardware-source-manifest.json` (`sound/soc/msm/msm8226.c`,
board r02, vendor codec/SLIMbus),
[Android identification](../docs/android-hardware-observation-20261022.json),
[firmware](firmware.md), [FM](modem-gnss.md#fm).
