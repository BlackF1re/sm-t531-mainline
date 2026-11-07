# Script entry points

Run host commands from the repository root. Host build defaults are
`../sources/` and `../build/sm-t531/`; `lib/host-paths.sh` defines overrides.
Device commands require the tablet and often root. Installation, deployment,
session selection and power tests change state; do not run them as health checks.

| Purpose | Entry points | Runs on |
|---|---|---|
| Kernel, initramfs, boot container | `build.sh`, `build-initramfs.sh`, `package-sd.sh` | Host |
| Userspace builds | `rootfs.sh`, `build-mesa.sh`, `build-phosh.sh`, `build-powerdevil.sh` | Host |
| SD deployment | `deploy-sd.sh`, `deploy-adb-sd.sh` | Host; writes SD |
| Stock backup / restore | `backup-stock` | Host; restoration requires explicit confirmation |
| Graphics installation | `install-graphics-stack.sh`, `install-mesa-shell.sh` | Tablet |
| Desktop setup and selection | `configure-plasma.sh`, `install-phosh.sh`, `select-mobile-shell.sh` | Tablet |
| Board services | `configure-network.sh`, `configure-wifi.sh`, `configure-charging.sh`, `configure-sleep.sh` | Tablet or target rootfs |
| SX9500 board calibration | `configure-grip.py` | Host validation/rule generation; `--install` applies on tablet |
| Runtime service helpers | `start-native-graphics.sh`, `phosh-session.sh`, `wifi-monitor.sh`, `sleep-mode.sh` | Tablet; normally invoked by installed units/session |
| Graphics capabilities / safe update | `graphics/build-probe.sh` (host); `graphics/snapshot.sh`, `graphics/ab.sh` (tablet) | See [A/B procedure](../docs/UNIFIED_DRM.md) |
| Recovery and crash preservation | `restore-native-from-bootstrap.sh`, `graphics/rollback-compat.sh`, `graphics/save-gpu-coredump.sh` | Tablet; rollback compatibility entry remains installed |
| General / graphics failure capture | `collect-device.sh`, `collect-graphics-failure.sh` | Tablet; output may contain private data |
| Graphics workloads / profiling | `profile-graphics.sh`, `profile-drawer.sh` | Tablet; bounded recordings, visible unlocked session required |
| Phosh display-power test | `check-display-power-cycle.sh` | Tablet; explicitly changes display power |
| Frozen bootstrap inputs | `init`, `init-usblog`, `kexec-sd.sh`, `bootstrap-command.sh`, `bootstrap-rescue.sh`, `volume-wait.c` | Packaged into recovery/bootstrap images; retain for reconstruction |
| Battery wakeup rule | `80-t531-bms-poll-no-wakeup.rules` | Installed udev input |

The installed `t531-graphics-rollback` name is supplied by
`graphics/rollback-compat.sh`; it delegates to the checked A/B controller.
Keep this recovery interface even though its name predates unified DRM.

One-time experiments are not installed by this index. Reusable diagnostic
sources and their limitations are catalogued in [tools](../tools/README.md).
