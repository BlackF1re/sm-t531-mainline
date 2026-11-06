# Selected Android hardware reference

Moved from the private hardware summary/supplement on 2026-11-07. General facts are selected here; the existing GPU configuration table was
relocated from the dated comparison rather than copied. Primary dumps and
per-device data remain private. Existing driver identities, component inventory
and GPU benchmark datasets are referenced rather than copied.

## Platform and storage

**VERIFIED_DEVICE, historical Android/Linux observations:** MSM8226 SoC ID 158,
revision 2.0; four Cortex-A7 cores (`0xc07`). Android cpufreq steps were 300, 384,
600, 787.2, 998.4, 1094.4 and 1190.4 MHz; these are configured steps, not a new
stability test. Linux reported 1536 MiB RAM before reserved/CMA deductions.
The internal eMMC product name is `016GE2`; a product name is not its unique CID.
Evidence: private `FACTS/short_android_probes.txt` and the selected vendor DT.
The [storage profile](partitions.json) supplies current exact byte sizes.
Notably USERDATA has a half-KiB remainder that `/proc/partitions` rounds away;
backup sizing uses sysfs/lsblk bytes, not rounded KiB or a zero PIT length.

## GPU and display configuration

**VERIFIED_DEVICE (runtime DT) / VERIFIED_VENDOR_SOURCE.** The Android runtime
DT captured 2026-10-22 reports chip ID `0x03000512` (A305B) and these GPU OPPs:

| GPU MHz | GFX → DDR peak request, kB/s | GFX → OCMEM peak request, kB/s |
|---:|---:|---:|
| 450 | 4256000 | 6400000 |
| 320 | 3200000 | 5120000 |
| 200 | 1600000 | 3200000 |
| 19 | 0 | 0 |

These are requested DT values, not measured frequency or bandwidth. The vendor
MDP description provides seven SMP blocks of 4096 bytes, at most three per pipe;
this does not imply any three fullscreen RGBA layers fit.
Original evidence: private `DT/android_runtime_2026-10-22.dts` and
`DT/vendor_selected.dts`; the public [source manifest](sources.json) and
[Android audit](../docs/ANDROID-HARDWARE-AUDIT.md) retain provenance.

## Existing measurements and limits

Android GPU comparisons already reside in
[the dated report](../docs/ANDROID-LINUX-PIPELINE-COMPARISON-20261103.md) and
[its dataset](../docs/graphics-android-linux-comparison-20261103.json).
The minimum-clock controls in the comparison describe Linux pinning; they do
not prove Android's minimum frequencies were changed. Android before/after
frequency readings are observations, not per-sample physical clock measurements.

Historical Android FM logs accepted tuning ioctls at 87.7/95.7/104.6 MHz with
RSSI=0 and stereo=0; another start failed with -110. Neither result establishes
population or absence of a usable RF/antenna path. PCM frame production alone
is not reception evidence. Reception, recognizable station and RDS remain
unverified; see the existing [FM report](../docs/FM.md). Original short logs
remain private, with their capture date unknown.
