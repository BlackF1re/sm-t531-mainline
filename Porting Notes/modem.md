# MPSS cellular modem

* SM-T531 is3G, not LTE: single SIM/UIM; source GSM/GPRS/EDGE and UMTS/HSPA.
  Integrated MPSS/Q6, MBA and RF front end; Android `pil-q6v5-mss` binds.
* Native service is not accepted. Integration order: modem/MBA firmware and
  NV → remoteproc/RMTFS/QMI → SIM/PIN/registration → BAM-DMUX/QMI data → SMS →
  call signaling plus ADSP/WCD9306 audio routing.
* A firmware file or enabled DT node is not a running modem. No native data,
  SMS/call, call/SMS wake or continuous network-standby acceptance is recorded.
* Preserve MODEMST1/2,FSG/FSC,EFS/PERSIST calibration. No guessed RF/NV changes.

* **DEVICE, 2026-11-07:** in a fully booted preserved Android, modem subsystem
  was OFFLINE and baseband property empty, while ADSP/WCNSS were ONLINE.
  `/firmware-modem` was mounted; SMD nodes and GSM/CDMA package declarations
  do not establish modem boot, SIM service or CDMA hardware. This custom ROM
  is not a known-working telephony reference.

[Android boot audit](../docs/android-hardware-observation-20261107.json).

Evidence: [Android probe data](../docs/android-hardware-observation-20261022.json), [pinned board sources](../docs/hardware-source-manifest.json).
