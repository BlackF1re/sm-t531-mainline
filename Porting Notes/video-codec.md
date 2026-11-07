# Qualcomm Venus / VIDC

* Venus remoteproc/firmware appeared under Android. Native hardware video
  decode/encode has not passed acceptance.
* Integration requires verified firmware resources, HFI,
  clocks, IOMMU contexts and V4L2 mem2mem interfaces; file presence alone is not
  proof of a running codec. Exact blob selection/location is not established
  by the retained notes and must be verified, not inferred from ADSP/MODEM files.
* Test actual decode/encode and complete output frames independently of Adreno
  OpenGL. GPU acceleration does not establish Venus or JPEG support.

* **DEVICE, 2026-11-07:** Venus subsystem was OFFLINE without an active video
  workload; that idle snapshot is not a codec failure. Generic VIDC nodes
  alone do not validate encode/decode formats or sustained playback.

Evidence: [pinned board sources](../docs/hardware-source-manifest.json).
