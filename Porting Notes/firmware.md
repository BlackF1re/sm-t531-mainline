# Firmware, calibration and factory identity

**DEVICE, 2026-10-22:** installed board WCNSS files match the tablet's Android
partition files byte-for-byte; this establishes content identity, not the
historical order in which Linux obtained them. Android is a preserved custom
ROM, not proven factory Samsung. Firmware presence does not prove population.

| Internal partition | Contents / native use |
|---|---|
| APNHLOS, p1,FAT | `image/wcnss.mdt` +b00/b01/b02/b04/b06/b07/b08/b09; also TZ-related images |
| MODEM, p2,FAT | `image/modem.*`, `mba.*`, `adsp.*`; native services not accepted |
| SYSTEM, p23 | `etc/firmware/wlan/prima/WCNSS_qcom_wlan_nv.bin` (29816bytes), cfg.dat,qcom_cfg.ini |
| EFS, p11 | Factory Wi-Fi `wifi/.mac.info`, `.mac.cob`; BT `/bluetooth/bt_addr` |
| PERSIST, p21 | Sensor/private data, `.bt_nv.bin`, secure-data directories |

DT requests nine WCNSS executable files and board NV under
`/lib/firmware/qcom/matisse3g/`; firmware is outside the kernel binary.
`rootfs.sh` does **not** import private board files automatically; generic
`firmware-qcom-soc` is insufficient to reproduce the installed device. Keep
native executable blobs/NV separate from prima Android config reference files;
copying cfg.dat/qcom_cfg.ini is not Linux driver configuration.

Existing private archive after cleanup:

* `PARTITIONS/dumps/`: ten original BOOT/RECOVERY/EFS/MODEMST1/MODEMST2/FSG/FSC/
  PARAM/PERSIST/PERSDATA images, not a complete eMMC dump.
* `FIRMWARE/firmware-original-2026-10-22.tar`:12original WCNSS/NV/reference files
  plus provenance/checksums. Old `.work` audit paths and pre-cleanup `private/device`
  paths are historical, not current prerequisites.
* `FIRMWARE/board-data/bluetooth-address`: validated EFS identity,0600.
* `BOOTSTRAP/immutable-20261022/`: current Linux/lk2nd physical BOOT and origin
  metadata; distinct from the earlier Android BOOT. Do not replace one with the other.
* The internal partition called BACKUP is only~7MiB; its name does not make it
  a full-device backup. `private.7z` was not inspected/changed during cleanup.

New captures use ignored `backup_stock/` with owner-only permissions:
`./scripts/backup-stock backup --host root@ADDRESS` and
`./scripts/backup-stock verify backup_stock/SESSION`. SSH requires verified host
keys,rootPython and offline internal storage. It captures the full user area plus
boot0/boot1; lk2nd captures exposed partitions, not raw gaps/GPT/boot areas.
RPMB keys/contents,OTP/eFuses/secure secrets and eMMC hardware config are not
ordinary raw backup data. A current capture is not automatically factory stock.
Restore defaults to a plan; writing needs --execute,same-device identity,
explicit target selection,critical gating where applicable and confirmation.
Do not clone calibration or assume transport loss during writing is atomic.
No calibration/NV, raw dumps, addresses, unsanitized DT or credentials belong
in Git. Do not fabricate calibration or clone identities to another tablet.
Read-only extraction used `mtools` for FAT firmware partitions and `debugfs`
for ext images; no internal filesystem mount or firmware rewrite was needed.
Sources: [storage geometry](../hardware/partitions.json),
[source manifest](../docs/hardware-source-manifest.json), private SHA/provenance.
