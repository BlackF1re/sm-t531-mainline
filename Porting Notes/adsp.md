# Q6 ADSP / LPASS audio processor

* Android bound `pil-q6v5-lpass`; reference firmware is MODEM `image/adsp.*`.
  Native ADSP audio operation is not accepted.
* Required audio path: firmware/resources → remoteproc/APR → AFE/ASM →
  SLIMbus NGD/BAM → WCD9306 → ALSA machine routes → UCM/PipeWire.
* Bluetooth endpoint registration is not proof of working SCO/PCM or board
  audio. Actual playback/recording and restart/sleep behavior remain untested.

* **DEVICE:** secure `pil-q6v5-lpass` loaded ADSP into
  `0x0d900000–0x0f100000`, received power/clock-ready and reached ONLINE.
  This validates that Android firmware boot path, not native audio routing.
