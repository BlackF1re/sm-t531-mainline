# Recovery & safety

> [!CAUTION]
> **Do not experiment with internal partitions as a recovery shortcut.** Wrong images, partitions, or device variants can prevent boot. Partition backup and restore commands below apply only to an already verified **SM-T531**.

## Recovery paths

| Situation | Safer starting point |
|---|---|
| SD kernel doesn't start | Internal bootstrap **recovery window** |
| Main graphics stack fails | SSH / USB ACM console and the project's graphics rollback tools |
| Need boot evidence | `save-logs`, `pstore`, lk2nd logs; preserve data before resets |
| Internal BOOT damaged | Verified private backup + Samsung Download Mode; **untested** restoration |

## Internal bootstrap recovery

The existing internal bootstrap is **frozen**. During its approximately **three-second** boot window, hold **either volume button** to enter recovery.

| Recovery action | Behavior |
|---|---|
| Press a volume button / `boot-sd` | Attempt the SD kernel |
| `mount-sd` | Mount SD boot/root read-only (no ext4 journal replay) |
| `mount-sd rw` | Explicitly allow writes |
| `umount-sd` | Unmount SD partitions |
| `mount-internal-boot` | Mount only the ext2 bootstrap payload read-only, after checks |
| `save-logs` | Save pstore/bootstrap evidence to SD rootfs `/var/log/t531-rescue` |

`mount-sd` does not remount an already mounted partition. To switch from read-only to writable access, run `umount-sd` before `mount-sd rw`. `save-logs` performs that writable mount/unmount itself. Automatic `boot-sd` also preserves previous pstore records under `/var/log/t531-pstore` before kexec.

Build a recovery initramfs **without rebuilding or replacing the frozen kernel**:

```bash
make rescue-initramfs
```

This needs an existing bootstrap kernel build providing
`../build/sm-t531/bootstrap/out/usr/gen_init_cpio` (or explicit `KERNEL_OUT`); the script exits if that tool is missing. It produces `bootstrap-initramfs.cpio.gz` and does not install it or change internal BOOT.

The actual device has verified bootstrap recovery and USB ACM diagnostic exchange; **USB Ethernet is not validated**.

## Graphics fallback

Current graphics updates use the atomic SD-slot controller documented in
[Unified DRM](UNIFIED_DRM.md), with host-independent slot logic in
`tools/graphics-ab/slots.py`. The supported entry point on the tablet is
`/usr/local/sbin/t531-graphics-ab`; it checks the board, SD layout and saved
baseline before changing a boot slot or restoring configuration.

A trial needs a verified matching kernel, module tree, initramfs, command line
and configuration snapshot. Its userspace timeout cannot recover an early boot
failure or a wedged kernel by itself. No validated watchdog recovery is claimed.
Preserve SSH/USB access and obtain approval before an update or reboot.

`/usr/local/libexec/t531-kernel-trial-restore` and snapshots named `#8` are
historical deployment mechanisms, not the default instructions for the current
stack. The repository's `t531-graphics-rollback` compatibility wrapper delegates
to the slot controller; older installed versions may behave differently. Check
which implementation is present before using it.

Never unload/reload MSM as a recovery shortcut, or read the full `clk_summary`
or a powered-off DSI PLL: those operations caused recorded aborts or hangs.
Do not mix kernel, DRM modules and Mesa configurations from different trials.

## Diagnostic access

```bash
# Host — substitute the correct ACM port after USB enumeration:
sudo picocom --baud 115200 --flow n /dev/ttyACM0

# lk2nd logs where available:
fastboot oem log && fastboot get_staged lk2nd.log
```

Only **one terminal reader** may hold an ACM port at a time. Boot messages alone do not establish that display/touch/graphics recovered.

> [!WARNING]
> **Preserve pstore before debugging a failure.** The reserved ramoops region is RAM-backed: controlled restart retention was tested; persistence after power removal was **not** established.

## Internal BOOT — emergency only

Confirmed partition/BOOT layout and immutable-source provenance are maintained
in [storage notes](../Porting%20Notes/storage.md#boot-chain). Verify them against
the actual device and private backup before any emergency restoration.

> [!IMPORTANT]
> The recovery commands below were **not physically tested**. They are **not** instructions for initial installation. Validate device, PIT, backup hashes and partition identity before any attempt.

```bash
# Illustration of the backed-up Android restoration sequence.
# Set BACKUP_DIR only after locating and verifying YOUR private backups.
: "${BACKUP_DIR:?Set the verified private backup directory first}"
(cd "$BACKUP_DIR" && sha256sum -c SHA256SUMS) &&
  heimdall flash --BOOT "$BACKUP_DIR/BOOT.img"
```

A saved `BOOT-lk2nd.img` represents the alternative **pre-bootstrap lk2nd** state. After `download-pit --no-reboot`, the next Heimdall operation **in the same Download Mode session** needs `--resume`; a fresh session does not.

**Never flash** a raw `zImage`, `RECOVERY`, PIT, bootloader, modem, or calibration partitions as part of normal kernel deployment. See [lk2nd boot documentation](https://github.com/msm8916-mainline/lk2nd/blob/23.1/Documentation/boot.md).

The inherited bootstrap SysRq failure and its correction are recorded in
[platform notes](../Porting%20Notes/platform.md).
