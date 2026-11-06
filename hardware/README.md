# SM-T531 hardware reference

General board facts belong here. Device-specific identities, raw partition
images, firmware/NV, calibration and unsanitized logs stay outside Git.
Implementation status is distinct from hardware presence and Android evidence.

| Reference | Contents |
|---|---|
| [Support matrix](SUPPORT.md) | Existing functional inventory and acceptance gaps; moved without creating a second matrix |
| [Task data](support.yaml) | Machine-readable inventory; its dated baseline remains historical |
| [Source manifest](sources.json) | Pinned vendor sources, URLs and hashes |
| [Android observations](android-observation-20261022.json) | Sanitized projection already published by the project |
| [Additional Android reference](ANDROID-REFERENCE.md) | Missing non-identifying facts selected from the private archive |
| [Storage geometry](partitions.json) | Verified partition offsets/sizes for this SM-T531 layout; used by the backup tool |

Current Linux graphics acceptance is maintained in
[the graphics stack guide](../docs/GRAPHICS-STACK.md), not duplicated here.
The [Android audit](../docs/ANDROID-HARDWARE-AUDIT.md) documents the source system:
Dirty Unicorns Android 6.0.1, not a verified factory Samsung ROM. Enabled DT nodes
and successful ioctls alone do not prove population or real-world operation.

Private factory data remains in the owner's external `private` archive.
New captures go under ignored `backup_stock/`; see
[backup and restoration](../docs/BACKUP-STOCK.md). A capture made now records the
current modified device, not automatically its original factory state.
