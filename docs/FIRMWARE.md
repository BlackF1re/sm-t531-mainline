# Stock firmware provenance

Read-only audit on 2026-10-22, Samsung SM-T531 / matisse3g, running kernel #16.
Evidence state: **VERIFIED_DEVICE** for the live file comparisons;
**HISTORICAL_SOURCE** for the original Android mount log and backup capture.

## Sources on this tablet

| Partition | Device | Size | Inspected contents |
| --- | --- | --- | --- |
| apnhlos | mmcblk0p1 | 14 MiB | FAT `image/wcnss.mdt`, eight `wcnss.bXX` segments, and TrustZone-related images. |
| modem | mmcblk0p2 | 49.75 MiB | FAT `image/modem.*`, `image/mba.*`, `image/adsp.*`. |
| system | mmcblk0p23 | 2300 MiB | Android `etc/firmware/wlan/prima/`: WLAN NV, cfg.dat and qcom_cfg.ini. |
| persist | mmcblk0p21 | 8 MiB | Persistent device data; saved image contains sensor data, `.bt_nv.bin` and secure-data directories. |
| efs | mmcblk0p11 | 14 MiB | Saved image: factory/device data, including `wifi/.mac.info` and `.mac.cob`. Contents remain private. |

The historical Android mount log confirms `apnhlos`→`/firmware`,
`modem`→`/firmware-modem`, `system`→`/system`, and the usual `/persist` and
`/efs` mounts. Firmware files present on an image do not prove that every
corresponding peripheral is populated or working.

All nine installed files below in `/lib/firmware/qcom/matisse3g/` are
**byte-identical** to `apnhlos:/image/`:

- `wcnss.mdt`
- `wcnss.b00`, `.b01`, `.b02`, `.b04`, `.b06`, `.b07`, `.b08`, `.b09`

The installed `WCNSS_qcom_wlan_nv.bin` (29816 bytes) is byte-identical to
`system:/etc/firmware/wlan/prima/WCNSS_qcom_wlan_nv.bin`. The firmware API is
1.5.1.2 / CRM 12035159; see [Wi-Fi evidence](WIFI.md) for shared-image hashes.
The current Linux station MAC matches `wifi/.mac.info` in the saved EFS image;
the actual address and calibration data are not published.

This establishes equivalence to the tablet's stock partition files. It does
not reconstruct the historical sequence of their original Linux installation.
`WCNSS_cfg.dat` and `WCNSS_qcom_cfg.ini` are retained as Android-driver reference
material, not installed as native Linux driver configuration.

## Backups found and verified

The original private backup is `/home/paul/t531/private/device`, captured on
2026-10-11. Its existing `SHA256SUMS` verifies ten images: BOOT, RECOVERY, EFS,
MODEMST1, MODEMST2, FSG, FSC, PERSIST, PERSDATA and PARAM. All ten passed again.
`BOOT-lk2nd.img` is also present but is not covered by that original manifest;
this audit does not add an integrity claim for it. These are selected critical
partition backups, **not a full eMMC backup**. Original apnhlos/modem/system
images are not part of that set.

A new private file backup is
`/home/paul/t531/private/firmware-stock-20261022`: nine WCNSS executable-image
files, the WLAN NV file, and two Android reference configuration files. All
12 files passed SHA256 verification against the manifest generated during
read-only extraction. The directory is private; blobs, identifiers and raw
partition images are excluded from Git.

There is also a 7 MiB internal partition labelled `backup` (mmcblk0p17).
Its label alone does not establish its contents or make it a full device
backup; this audit did not interpret or alter that raw partition.

## Deployment and audit method

The kernel requests the WCNSS files at the DT paths under
`qcom/matisse3g/`; firmware stays outside the kernel binary. The current SD
rootfs already has the verified files. A clean `scripts/rootfs.sh` build
**does not yet import these private board-specific files automatically**;
the generic `firmware-qcom-soc` dependency does not establish that those custom
DT paths are populated. Rebuilding only the kernel preserves the installed
rootfs firmware.

Live apnhlos/modem were mounted with `ro,nodev,nosuid,noexec`; ext4 system,
persist and efs also used `noload` to prevent journal replay. Partition labels
and filesystem types were checked before mounting, every temporary mount was
removed, and the original backup images were inspected with read-only debugfs.
No internal partition, installed firmware, calibration or boot configuration
was changed. Private raw results are under `.work/firmware-audit-20261022/`.
