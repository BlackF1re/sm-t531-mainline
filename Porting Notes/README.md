# Porting Notes — SM-T531

Each component record is a self-contained statement of board identity, implementation,
accepted behavior and unresolved limits. DEVICE marks observed behavior, SOURCE marks
configuration, and HYPOTHESIS marks an unverified explanation; probe alone is not
functional acceptance. Keep tested configurations when they limit conclusions.

The index is navigation, not required reading. Procedures and build locks live
outside the notes. Firmware/NV, identities, calibration and raw backups remain
private. Historical results are archived at Git `e865aba`, not active facts.

## Platform

| Record | Component / area |
|---|---|
| [device-tree](device-tree.md) | Device Tree and board identity |
| [cpu](cpu.md) | CPU, voltage and idle |
| [memory](memory.md) | RAM and BIMC memory controller |
| [clocks](clocks.md) | MSM8226 clock and reset controllers |
| [interrupts](interrupts.md) | Interrupt controller and timers |
| [pinctrl](pinctrl.md) | TLMM and PMIC pin control |
| [ipc](ipc.md) | Shared memory and remote-processor IPC |
| [efuses](efuses.md) | QFPROM / eFuses |
| [interconnect](interconnect.md) | MSM8226 interconnect |
| [ocmem](ocmem.md) | OCMEM SRAM and graphics allocation |
| [pmic](pmic.md) | PM8226 PMIC and board supplies |
| [rtc](rtc.md) | PM8226 RTC |
| [watchdog](watchdog.md) | APSS watchdog |
| [pmic-watchdog](pmic-watchdog.md) | PM8226 PON watchdog |
| [random-generator](random-generator.md) | Qualcomm PRNG |
| [cryptography](cryptography.md) | Qualcomm QCE |

## Graphics

| Record | Component / area |
|---|---|
| [drm](drm.md) | Unified MSM DRM / GEM |
| [gpu](gpu.md) | Adreno 305B kernel driver |
| [gpu-smmu](gpu-smmu.md) | GPU ARM SMMU |
| [display-iommu](display-iommu.md) | Legacy display IOMMU / TrustZone |
| [mesa](mesa.md) | Mesa / Freedreno A3xx resource handling |
| [qt](qt.md) | Qt OpenGL swapchain depth/stencil |
| [kwin](kwin.md) | KWin Wayland and MDP5 overlays |
| [plasma-mobile](plasma-mobile.md) | Plasma Mobile drawer integration |
| [phosh](phosh.md) | Phosh / Phoc toolkit compatibility |
| [gpu-experiments](gpu-experiments.md) | GPU performance: results worth preserving |
| [mdp5](mdp5.md) | MDP5 display controller |
| [dsi](dsi.md) | MSM8226 DSI host and 28-nm PHY |
| [tc358764](tc358764.md) | Toshiba TC358764 DSI→LVDS bridge |
| [lcd](lcd.md) | LVDS LCD panel |
| [backlight](backlight.md) | LP8556 backlight |
| [brightness](brightness.md) | Phosh brightness integration |

## Power and storage

| Record | Component / area |
|---|---|
| [power-management](power-management.md) | System sleep, RPM/MPM and wake sources |
| [vadc](vadc.md) | PM8226 VADC |
| [iadc](iadc.md) | PM8226 IADC |
| [battery](battery.md) | PM8226 BMS1 / battery fuel gauge |
| [charger](charger.md) | SMB358 charging and input-current policy |
| [soc-thermal](soc-thermal.md) | MSM8226 TSENS |
| [battery-thermistor](battery-thermistor.md) | Battery thermistor |
| [pmic-thermal](pmic-thermal.md) | PM8226 die-temperature alarm |
| [board-thermistors](board-thermistors.md) | Board / PA thermistors |
| [emmc](emmc.md) | Internal eMMC |
| [sd-card](sd-card.md) | microSD / SDHCI2 |
| [boot](boot.md) | lk2nd, bootstrap and kexec |
| [firmware](firmware.md) | Firmware, calibration and factory identity |

## Input and sensors

| Record | Component / area |
|---|---|
| [touchscreen](touchscreen.md) | maXTouch touchscreen and sleep |
| [buttons](buttons.md) | Physical and capacitive buttons |
| [accelerometer](accelerometer.md) | ST K2HH accelerometer |
| [gyroscope](gyroscope.md) | Gyroscope |
| [magnetometer](magnetometer.md) | Magnetometer / compass |
| [ambient-light](ambient-light.md) | Ambient-light sensor |
| [proximity-sensor](proximity-sensor.md) | Optical proximity sensor |
| [grip-sensor](grip-sensor.md) | Semtech SX9500 grip / SAR |
| [hall-sensor](hall-sensor.md) | Hall cover switch |
| [haptics](haptics.md) | ISA1200 haptics candidate |
| [leds](leds.md) | Navigation / notification LEDs |
| [infrared](infrared.md) | Infrared transmitter candidates |
| [nfc](nfc.md) | NFC candidates |

## Radio and USB

| Record | Component / area |
|---|---|
| [wifi](wifi.md) | WCN3660 Wi-Fi |
| [wifi-monitor](wifi-monitor.md) | WCN3660 raw monitor / injection |
| [bluetooth](bluetooth.md) | WCN3660 Bluetooth |
| [modem](modem.md) | MPSS cellular modem |
| [gnss](gnss.md) | GNSS / GPS |
| [fm](fm.md) | Qualcomm Iris FM |
| [usb](usb.md) | ChipIdea USB controller and HS PHY |
| [muic](muic.md) | Silicon Mitus SM5502 MUIC |

## Audio and media

| Record | Component / area |
|---|---|
| [adsp](adsp.md) | Q6 ADSP / LPASS audio processor |
| [audio-codec](audio-codec.md) | WCD9306 / Tapan audio codec |
| [headset](headset.md) | 3.5-mm headset jack and buttons |
| [rear-camera](rear-camera.md) | Rear camera — Siliconfile SR352 |
| [front-camera](front-camera.md) | Front camera — Siliconfile SR130PC20 |
| [camera-isp](camera-isp.md) | MSM8226 camera interface and image processing |
| [video-codec](video-codec.md) | Qualcomm Venus / VIDC |

The directory is flat. Facts use component names, source versions, build
identities and test conditions rather than calendar dates. Unknown hardware
is not invented to complete a catalog.
