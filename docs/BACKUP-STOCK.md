# Private stock-data backup and restoration

Entry point: `./scripts/backup-stock`. It uses Python 3's standard library on
the host, plus OpenSSH or Android platform-tools. There are no background
services, implicit reboots, bootloader installations, unlocks or erases.
`inspect` is read-only; `restore` shows a plan unless explicitly executed.

## Coverage and transport

| Backend | Captured by default | Requirements / limits |
|---|---|---|
| `ssh` | Full eMMC user area including GPT/PIT, gaps, every partition and the current complete BOOT; both 4-MiB eMMC boot areas; metadata and observed runtime addresses | Root Python 3, util-linux `lsblk`, verified host key; Linux/rescue on SD or RAM; no mounted internal partitions, swap or device-mapper holders |
| `lk2nd` | All 26 verified partitions, including BOOT reconstructed from the protected 512-KiB `lk2nd` prefix plus the virtual `boot` payload | Identified SM-T531, supported `max-fetch-size`, OEM read/hash/staging commands; partition tables/gaps and eMMC boot areas are not exposed by this path |
| Samsung stock Download Mode | Not implemented as a full read/restore backend | This is Odin, not standard fastboot. Heimdall offers PIT download and flashing, not general partition reads or the required full readback/identity contract |

The lk2nd implementation follows pinned upstream **23.1** sources:
[read/chunk protocol](https://github.com/msm8916-mainline/lk2nd/blob/23.1/lk2nd/fastboot/fetch.c),
[staged SHA-256](https://github.com/msm8916-mainline/lk2nd/blob/23.1/lk2nd/fastboot/hash.c),
[staging semantics](https://github.com/msm8916-mainline/lk2nd/blob/23.1/app/aboot/fastboot.c),
[board identity](https://github.com/msm8916-mainline/lk2nd/blob/23.1/lk2nd/device/device.c),
[BOOT offset](https://github.com/msm8916-mainline/lk2nd/blob/23.1/Documentation/boot.md).
Checked 2026-11-07. Other bootloaders are rejected rather than assumed compatible.

RPMB authenticated contents/key, OTP/eFuse/TrustZone secrets and volatile state
are outside this capture. Raw eMMC images do not include its EXT_CSD hardware
configuration. MicroSD is a separate medium and is not copied. These exclusions
are recorded in the manifest: “complete” means the declared capture selection
completed, not that every hardware secret was readable.

A backup made under current Linux contains the owner's modified BOOT/Android
storage, not an automatically recovered factory Samsung image. Existing earlier
Android/BOOT/NV backups remain private and are not overwritten or relabeled.
Runtime MAC/BT observations must not replace factory identities in EFS/NV.

## Inspect and capture

```bash
./scripts/backup-stock inspect --host root@192.168.2.157
./scripts/backup-stock backup --host root@192.168.2.157

# Already in lk2nd, without changing modes or flashing anything:
./scripts/backup-stock inspect --backend lk2nd
./scripts/backup-stock backup --backend lk2nd
```

SSH host-key checking is mandatory. The owner's existing `../private/known_hosts`
is used when present; otherwise normal SSH configuration applies. Override with
`--known-hosts /path/to/verified/known_hosts`. No password or key is stored by the
tool. `--serial SERIAL` selects one of several connected fastboot devices.

Captures go to `backup_stock/UTC_TIMESTAMP/`. Directories are 0700, files 0600;
`/backup_stock/` is ignored by Git and `make check` rejects tracked files beneath
it. Images are **not encrypted**. `--output /path/outside/the/repository` selects
another local destination. Inside the repository, other output locations are
rejected to prevent accidental publication.

A full capture is approximately 15.8 GB and can take a long time. The display
shows per-image size, progress/rate/ETA on a terminal, and verified completion.
An optional `--partitions BOOT,EFS,PERSIST` capture is explicitly partial;
use uppercase names from [the board profile](../hardware/partitions.json).
SSH also accepts `EMMC_USER`, `EMMC_BOOT0` and `EMMC_BOOT1` area names.

## Integrity, interruption and resume

```bash
./scripts/backup-stock verify backup_stock/SESSION
./scripts/backup-stock backup --host root@192.168.2.157 \
  --output backup_stock/SESSION --resume
```

Resume requires the original backend, selection, device identity and geometry.
For a partial capture repeat its `--partitions` selection. Completed images are
checked against both local hashes and current device content before skipping.
An interrupted image is restarted; there is no unverified byte-offset resume.
If storage has changed, start a new session rather than mix snapshots.

Each image is SHA-256 checked against the bytes read by the remote agent or
lk2nd staged buffer, then reread locally. Files and manifest checkpoints are
fsynced before completion is recorded. A `.partial` image or incomplete manifest
is never accepted as a completed backup. A manifest contains private CID/serial,
layout, exclusions, provenance and image hashes; hashes establish integrity,
not independent authenticity of an untrusted manifest.

The SSH safety check establishes unmounted, unused block devices. It does not
freeze independent modem/secure-firmware writes or provide a globally atomic
snapshot. Prefer a minimal rescue environment for a golden acquisition. The
script never silently unmounts partitions or stops services to pass the check.

## Plan restoration first

```bash
./scripts/backup-stock restore backup_stock/SESSION \
  --host root@192.168.2.157 --partitions BOOT
```

This validates the complete local backup selection and the live board, exact
partition geometry and **same** eMMC CID/fastboot serial, then prints the plan.
It performs no device write. A partition may be restored directly from the full
`EMMC_USER` image using its verified byte range, without keeping duplicate dumps.

Writing additionally requires `--execute`, a typed `RESTORE-fingerprint` token,
and `--critical` for BOOT, recovery, firmware/NV or whole user-area operations:

```bash
# Run only after explicitly approving the displayed plan and recovery method:
./scripts/backup-stock restore backup_stock/SESSION \
  --host root@192.168.2.157 --partitions BOOT --execute --critical
```

Noninteractive operation requires the exact token in `--confirm`; it cannot
bypass identity, layout, checksum or critical-selection checks. No `--all`
restore exists: name the intended partitions. `--partitions EMMC_USER` with the
SSH backend deliberately restores the **whole user area, including GPT/PIT and
bootloaders**, and requires the same critical confirmation. Do not use it for
an ordinary main-kernel update. eMMC boot0/boot1 writes are not supported.

SSH stages the complete selected image on SD/RAM, verifies its length and hash,
and rechecks the target before opening eMMC for writing. Insufficient staging
space or an interrupted upload causes no eMMC write. After writing it fsyncs and
reads back the full target. Power/transport failure during the actual block
write remains hazardous; neither this script nor a checksum makes that atomic.
`restore-last.json` journals completed targets. The tool never reboots.

For lk2nd, BOOT restoration first checks that the saved protected prefix equals
the live prefix, then flashes only the payload. A differing prefix requires SSH
rescue; it is never blindly flashed through virtual `boot`. Partition flashing
uses bounded fastboot sparse transfers and full readback. A lost transfer during
flashing can still leave a partial target; do not reboot after a readback error.

SSH captures bind to CID, lk2nd captures to its fastboot serial. The tool does
not guess a mapping between these identities: cross-backend restoration is
rejected. Use the original backend or a separately established recovery method.

## Validation status

**2026-11-07:** real SSH inspection of the SM-T531 passed; all 26 partition
geometries and both boot-area sizes were observed. A 1024-byte FSC read, local
verification and restore **plan only** passed without writes or reboot.
Host fault tests cover corruption, missing images, path traversal/symlinks,
wrong identity/geometry, changed-source resume, confirmation gates, BOOT prefix
reassembly, interrupted upload and staged/readback restoration on synthetic
files. Real restoration, lk2nd transfers and a full-size acquisition have **not**
been physically acceptance-tested. The tool is not claimed infallible.
