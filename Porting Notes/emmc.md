# Internal eMMC

* Device `mmcblk0`, product`016GE2`,15,758,000,128bytes,512-byte sectors;
 26partitions and4-MiB boot0/boot1. RPMB is separate from ordinary raw reads.
* USERDATA has a512-byte remainder beyond whole KiB. `/proc/partitions` rounds
  it away; a zero PIT length does not mean zero capacity. Use sysfs/lsblk bytes.
  PIT has30entries including GPT/PIT/MD5 special regions, not30Linux partitions.
* Ordinary main-kernel updates target SD, not internal eMMC. Selected old
  critical-partition backups are not a complete physical-device backup.
* Exact public offsets and sizes are pinned for SM-T531; same model name alone
  is insufficient identity for restoring factory NV to another eMMC.

Evidence: [partition geometry](../hardware/partitions.json),
`tools/stock-backup/agent.py` (board/CID/geometry and offline-storage checks).
