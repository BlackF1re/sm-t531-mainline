# Firmware, calibration and factory identity

**DEVICE:** installed board WCNSS files match the tablet's Android
partition files byte-for-byte; this establishes content identity, not the
historical order in which Linux obtained them. Android is a preserved custom
ROM, not proven factory Samsung. Firmware presence does not prove population.

| Internal partition | Contents / native use |
|---|---|
| APNHLOS, p1, FAT | `image/wcnss.mdt` +b00/b01/b02/b04/b06/b07/b08/b09; also TZ-related images |
| MODEM, p2, FAT | `image/modem.*`, `mba.*`, `adsp.*`; native services not accepted |
| SYSTEM, p23 | `etc/firmware/wlan/prima/WCNSS_qcom_wlan_nv.bin` (29816 bytes), cfg.dat, qcom_cfg.ini |
| EFS, p11 | Factory Wi-Fi `wifi/.mac.info`, `.mac.cob`; BT `/bluetooth/bt_addr` |
| PERSIST, p21 | Sensor/private data, `.bt_nv.bin`, secure-data directories |

DT requests nine WCNSS executable files and board NV under
`/lib/firmware/qcom/matisse3g/`; firmware is outside the kernel binary.
`rootfs.sh` does **not** import private board files automatically; generic
`firmware-qcom-soc` is insufficient to reproduce the installed device. Keep
native executable blobs/NV separate from prima Android config reference files;
copying cfg.dat/qcom_cfg.ini is not Linux driver configuration.

Private archives retain ten selected critical-partition images,
WCNSS/NV provenance and separate current/Android BOOT images; none is a
complete eMMC dump. Full backups must include eMMC user area and boot0/boot1;
lk2nd partition reads exclude raw gaps/GPT/boot areas. RPMB/OTP/eFuses,
secure secrets and eMMC hardware configuration are not ordinary raw backups.
Restore only after same-device identity verification and explicit consent.
Never clone calibration/identities; keep raw dumps/NV outside Git.
