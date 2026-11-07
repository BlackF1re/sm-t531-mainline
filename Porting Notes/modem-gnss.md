# Cellular, GNSS and FM

## Cellular and location

* SM-T531 is3G, not LTE: single SIM/UIM; source GSM/GPRS/EDGE, UMTS/HSPA.
  Integrated MPSS/Q6, MBA, RF front end; Android `pil-q6v5-mss` binds.
* Native modem is not accepted. Bring-up dependencies: preserved modem/MBA/NV,
  remoteproc/RMTFS/QMI → SIM/PIN/registration → BAM-DMUX/QMI data → SMS →
  call signaling plus [ADSP/codec audio](audio.md). Each needs real endpoint tests.
* GNSS/GPS antenna documented; native fix absent. QMI LOC routing is a
  **HYPOTHESIS**, supported constellations/RF parts not established. No call/SMS/
  location wake or continuous network standby acceptance.
* Preserve MODEMST1/2,FSG/FSC,EFS/PERSIST and radio calibration; firmware files
  on MODEM do not establish a running modem. No unverified RF/NV changes.

## FM

* WCNSS advertises real `APPS_FM` RPMSG service. Candidate V4L2 driver supports
  standard tuning, mute,50/75µs deemphasis,RDS reads/poll and bounded seek;
  endpoint first-open/last-close, bounded waits, removal wakes waiters.
  A control-handler/ioctl mutex reuse deadlock was fixed with separate locking.
* Candidate remains outside main kernel/config; source in
  [Git43648a2](https://github.com/BlackF1re/sm-t531-mainline/tree/43648a2/patches/candidates/fm).
  No autoload/driver override or installed FM service is supported.
* **DEVICE:** `/dev/radio0`,49/49 v4l2-compliance1.30.1 checks passed.29Tomsk
  stations with wired headphones returned zero signal/no stereo/RDS. Both
  antenna selections,23-byte process calibration and temporary L16/L24/XO votes
  did not restore RF. Receiver disable lacked command-complete within3s.
* Preserved Android also tuned six frequencies×two antenna choices with zero
  RSSI/stereo. An earlier enable returned−110. PCM0/1,48kHz/stereo/16-bit,
  684,032captured frames and successful calibration ioctls are not reception; its23-byte calibration used
  the vendor ARM time32 extended-control buffer ABI.
  Android SMD close may synthesize disable completion; not proof of RF off.
  Configured rails L16=3.0V,L24=1.3V match native; not physical voltage readings.
* **HYPOTHESIS:** FM pins may be unwired. Samsung service-manual textual view
  lists WCN3660A Wi-Fi/BT and FM pin labels41DATA/48SSBI/61HS_RX/68TXRX without
  visible net names; graphic no-connect crosses/physical continuity were not
  checked. Neither missing labels nor zero RF establishes absence. Inspect
  graphical schematic/population before another frontend rewrite.
* Keep test waits bounded and use a temporary sleep inhibitor; a lost SSH
  connection during these trials was once ordinary sleep, not a proven crash.
  No guessed GPIO/RF voltage/calibration values should enter production.

Sources: [FM results](../docs/fm-results.json),
[API compliance](../docs/fm-v4l2-compliance.txt), `tools/fm-diag`,
[source manifest](../docs/hardware-source-manifest.json),
[Samsung service manual p45](https://www.manualslib.com/manual/2076923/Samsung-Sm-T531.html?page=45)
(text-only retrieval2026-10-22; no scans redistributed).
