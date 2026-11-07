# Qualcomm Iris FM

* WCNSS advertises real `APPS_FM` RPMSG service. Candidate V4L2 driver supports
  standard tuning, mute, 50/75 µs deemphasis, RDS reads/poll and bounded seek;
  endpoint first-open/last-close, bounded waits, removal wakes waiters.
  A control-handler/ioctl mutex reuse deadlock was fixed with separate locking.
* Candidate remains outside main kernel/config; source in
  [Git43648a2](https://github.com/BlackF1re/sm-t531-mainline/tree/43648a2/patches/candidates/fm).
  No autoload/driver override or installed FM service is supported.
* **DEVICE:** `/dev/radio0`, 49/49 v4l2-compliance1.30.1 checks passed.29Tomsk
  stations with wired headphones returned zero signal/no stereo/RDS. Both
  antenna selections, 23-byte calibration and temporary L16/L24/XO votes
  did not restore RF. Receiver disable lacked command-complete within 3s.
* Preserved Android also tuned six frequencies×two antenna choices with zero
  RSSI/stereo. An earlier enable returned−110. PCM0/1, 48 kHz/stereo/16-bit,
  684,032captured frames and successful calibration ioctls are not reception; its23-byte calibration used
  the vendor ARM time32 extended-control buffer ABI.
  Android SMD close may synthesize disable completion; not proof of RF off.
  Configured rails L16=3.0V, L24=1.3V match native; not physical voltage readings.
* **HYPOTHESIS:** FM pins may be unwired. Samsung service-manual textual view
  lists WCN3660A Wi-Fi/BT and FM pin labels41DATA/48SSBI/61HS_RX/68TXRX without
  visible net names; graphic no-connect crosses/physical continuity were not
  checked. Neither missing labels nor zero RF establishes absence. Inspect
  graphical schematic/population before another frontend rewrite.
* Keep test waits bounded and use a temporary sleep inhibitor; a lost SSH
  connection during these trials was once ordinary sleep, not a proven crash.
  No guessed GPIO/RF voltage/calibration values should enter production.
