# Documentation map

Use the current guides for builds and deployment. Dated investigations preserve
observations about specific old builds; their commands and paths are not the
supported installation procedure. A successful probe or build is not hardware
acceptance.

| Purpose | Canonical starting point |
|---|---|
| Hardware inventory, implementation and acceptance gaps | [Hardware matrix](HARDWARE.md), `status/hardware.yaml` |
| Host prerequisites, paths and SD deployment | [Build & deployment](BUILD-DEPLOY.md) |
| Bootstrap, recovery and protected storage | [Recovery & safety](RECOVERY.md) |
| Supported graphics components and identity checks | [Single graphics stack](GRAPHICS-STACK.md) |
| Unified DRM architecture and trial mechanism | [Unified DRM](UNIFIED_DRM.md) |
| Current sleep selection and limitations | [Sleep stack](SLEEP-STACK.md) |
| Power-key/input handling | [Touch sleep](TOUCH-SLEEP.md) |
| Battery and charging | [Battery](BATTERY.md) |
| Backlight | [Backlight](BACKLIGHT.md) |
| Wi-Fi / Bluetooth / FM | [Wi-Fi](WIFI.md), [Bluetooth](BLUETOOTH.md), [FM](FM.md) |
| Firmware and calibration provenance | [Firmware](FIRMWARE.md) |
| Optional Phosh build and installation | [Phosh](PHOSH.md) |
| Accepted patches and unresolved bring-up issues | [Patch review](PATCH-REVIEW.md) |
| Source preservation and cleanup audit | [Worktree audit](WORKTREE-AUDIT-20261106.md) |

## Research and evidence

`GRAPHICS.md`, `NATIVE-KMS.md` and `GRAPHICS-STABILITY.md` retain the earlier
framebuffer, split-DRM and shell bring-up history. Dated `GRAPHICS-*`,
`ANDROID-*`, `SLEEP-*`, `OCMEM-*` and power-button reports describe their named
experiments; associated JSON files retain measured data and scope. Read the
current stack guide before applying conclusions to the running build.

Keep a result in its existing report rather than copying it into multiple
guides. New conclusions should cite their source, date, build and acceptance
limits. Private device identities, firmware/calibration, raw partition dumps
and unsanitized logs belong outside this repository. Historical Android images
are research inputs, not dependencies of native Linux operation.
