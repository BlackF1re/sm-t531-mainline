# Porting Notes — SM-T531

Canonical technical notes; no new hardware tests were performed during consolidation.
`DEVICE` = recorded device observation, `SOURCE` = source/configuration evidence,
`HYPOTHESIS` = unproven explanation. Acceptance applies to the named experiment,
not every feature of the component. Kernel base: v7.2.9 / `5fce161649b4`;
vendor reference: [Samsung/Lineage `3fa1853ed5d6`](../docs/hardware-source-manifest.json).

| Area | Notes |
|---|---|
| Board revision, DT selection, bindings | [device-tree](device-tree.md) |
| PMIC, RTC, watchdog, crypto/PRNG | [platform](platform.md) |
| CPU, voltage, idle | [cpu](cpu.md) |
| DDR, buses, clocks, OCMEM | [memory-interconnect](memory-interconnect.md) |
| Unified DRM, current GPU fixes | [gpu](gpu.md) |
| GPU measurements and rejected candidates | [gpu-experiments](gpu-experiments.md) |
| MDP5, IOMMU, DSI, bridge, LCD | [display](display.md) |
| LP8556 and brightness | [backlight](backlight.md) |
| maXTouch | [touchscreen](touchscreen.md) |
| Suspend, wake sources, RPM/MPM | [power-management](power-management.md) |
| SMB358, BMS, ADC, SOC | [battery-charging](battery-charging.md) |
| WCN3660/mac80211 | [wifi](wifi.md) |
| WCN3660/BlueZ | [bluetooth](bluetooth.md) |
| Firmware, calibration, identity | [firmware](firmware.md) |
| ADSP, WCD9306, jack | [audio](audio.md) |
| Sensors, keys, haptics | [sensors](sensors.md) |
| Camera/ISP, Venus, JPEG | [camera-video](camera-video.md) |
| Cellular, SIM, location, FM | [modem-gnss](modem-gnss.md) |
| ChipIdea, PHY, MUIC, OTG | [usb](usb.md) |
| eMMC, SD, bootstrap | [storage](storage.md) |

Operator procedures remain in [docs](../docs/README.md); the dry component list
is in [hardware](../hardware/README.md). JSON/TXT measurements, source manifests,
patches, configuration, scripts and diagnostic source are retained at their
existing paths. The 108-task [support snapshot](../status/hardware.yaml) is dated
2026-10-22; it is not the current graphics/sleep baseline.

Detailed superseded prose remains available in Git at `1894474`; use the
retained code and datasets cited per topic before repeating an experiment.
Private firmware/NV, raw DT/logs and backups remain outside Git.
