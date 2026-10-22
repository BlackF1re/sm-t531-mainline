# SM-T531 hardware inventory and porting order

Updated **2026-10-22**. Baseline: **7.2.9-t531-dirty #19**, project `1511f60`, 120 applied production patches, native MDP5/DSI + Adreno, Phosh.

**This is a functional porting inventory, not a claim of complete hardware support.** It contains 108 individually tracked functions/options, not that many physical chips. Current read-only observations are separated from earlier physical acceptance. The machine-readable source is [status/hardware.yaml](../status/hardware.yaml).

The owner tablet, its prior acceptance records, board-specific Samsung/Qualcomm sources and the Samsung SM-T531 manual are the evidence. A shared SoC node, a driver option or a successful probe does not prove a populated device or working function. The Android kernel reports board Revision 0003; some chip revisions, panel supplier and optional components still need board/BOM confirmation; absolute physical completeness cannot be guaranteed from software alone. The first inventory snapshot was read-only. A subsequent owner-authorized Android boot trial temporarily replaced only the BOOT payload and restored the entire original partition byte-for-byte; see the Android audit below.

**Status:** `VERIFIED` = the explicitly stated physical test passed; `WORKING` = useful function demonstrated with remaining acceptance; `PARTIAL` = material gaps; `PROBES` = interface/driver only; `IMPLEMENTING` = infrastructure exists; `RESEARCHING` = identified but native bring-up pending; `BLOCKED` = specific unresolved failure; `REGRESSION` = observed failure; `UNKNOWN` = population/capability unestablished. Evidence and implementation states are separate in YAML.

**Important current limits:** GPU/settings can hang and crash Phoc; general composition is not 60 FPS. Charging works but SOC accuracy and a physical 4.8 V input floor are not validated. PMIC die-temperature driver is disabled. Watchdog expiry/reset failed. Bluetooth controller + one BLE mouse work; all profiles are not accepted. Audio/cameras/modem/GNSS are not brought up.

## Evidence and revision control

- [Read-only current-device observation](hardware-observation-20261022.json) records only sanitized, non-identifying facts. Interface reads are not new physical acceptance. Earlier tests name their build in the linked evidence documents.
- [Source manifest](hardware-source-manifest.json) pins Samsung downstream mirror `3fa1853ed5d6c3a8ef5a2fda9822705243bbc256`, all 31 files in the union of r00/r01/r02 include closures and the other inspected files by SHA256. The mirror contains later downstream/Lineage changes; it is not represented as a pristine Samsung release tarball. GPL headers/authorship are retained in research files, which are not copied into this document.
- [Samsung SM-T531 manual](https://downloadcenter.samsung.com/content/UM/201506/20150602135914448/SM-T531_UM_EU_Lollipop_Eng_Rev.1.0_150602.pdf), rev1.0, 2015-06-02: physical layout p7 (two speakers, microphone, SIM/SD/jack/antennas), plus phone/media/location features. Copyrighted PDF remains outside Git.
- r02 wiring agrees with the currently bound touch/accelerometer/charger/MUIC/backlight. The subsequent Android boot reports physical Revision 0003 while using the preserved r02 DT; the DT model is not a PCB revision measurement. r00 light/proximity/compass/button-light and r00/r01 IR nodes are **not** silently carried into the physical inventory.

## Android cross-check and restoration

The [Android hardware audit](ANDROID-HARDWARE-AUDIT.md) captures a real boot of the owner's preserved Android 6.0.1 kernel, 5,468 live DT properties, running kernel configuration and actual driver/ID reads. WCD9306, K2HH, SX9500 and both camera identities are now device-backed. ISA1200 remains a DT description without an observed bound driver. FM Iris is enabled/bound in that running Android kernel even though the previously inspected downstream defconfig disables it; [subsequent native/Android FM trials](FM.md) found no RF signal. **These observations do not upgrade native Linux acceptance.** Original BOOT was restored and verified over all 10 MiB; native #19, SSH/ACM and Phoc/Phosh returned.

## Functional matrix

Every row has a stable task ID. Hardware identified only from vendor sources is labeled **vendor** in the presence column; **unknown** is deliberately retained for template/variant options.

### Platform

| ID / function | Hardware | Presence | State | Implemented / observed | Remaining acceptance |
|---|---|---|---|---|---|
| `boot.internal` — Internal boot chain | Samsung bootloader, lk2nd 23.1, immutable bootstrap | device | WORKING | Normal internal boot -> SD kexec used repeatedly; internal BOOT unchanged. | Repeat cold boot, interrupted countdown and button recovery with release artifacts. |
| `boot.sd` — SD kernel and rootfs boot | kexec, appended DTB, Debian armhf | device | WORKING | Current #19 boots Phosh from microSD. | Repeat cold/warm/recovery boot matrix and failure fallback. |
| `boot.recovery` — Recovery and crash records | USB ACM, SD rollback, ramoops/pstore | device | PARTIAL | SSH/ACM and checked #17 rollback artifacts retained; pstore collected previously. | Automatic recovery from a genuinely wedged kernel is not accepted; watchdogs fail. |
| `boot.repro` — Reproducible image and board data | Kernel/DTB/modules/initramfs, WCNSS NV, factory BT identity | device | PARTIAL | Build/package scripts and current outputs exist; BT identity injected privately. | Clean checkout -> exact installed Phosh/rootfs/firmware/module manifest and reproducible release. |
| `cpu.smp` — CPU execution and SMP | MSM8226, four Cortex-A7; NEON/VFPv4 | device | WORKING | All four CPUs online; ordinary ARMv7 Linux runs. | Sustained multicore/memory/thermal acceptance; not a new stress run. |
| `cpu.dvfs` — CPU frequency and voltage | A7 PLL/APCS, seven stock OPPs, SAW/RPM-CX | device | PARTIAL | Stock steps and hotplug tested historically; active 1.19 GHz independently measured. | Validate all voltage/OPP transitions, load and resume without retained bring-up votes. |
| `cpu.idle` — CPU idle and hotplug | WFI, per-core standalone collapse | device | PARTIAL | WFI/SPC/hotplug exercised in earlier acceptance. | Idle residency, energy savings and repeated current-profile hotplug/idle. |
| `cpu.l2` — L2 cache and cluster low power | Cortex-A7 shared L2, SAW2 L2 | device | PARTIAL | Cache/cluster used; standalone cluster collapse implemented and tried historically. | Measure L2 rate/retention and whole-cluster sleep; deep suspend has a known DRM failure. |
| `memory.ddr` — System RAM and DDR clocks | 1.5 GB RAM, BIMC memory controller | device | PARTIAL | 1438952 KiB Linux MemTotal now; physical active DDR measured about 533.33 MHz. | Identify exact RAM part/type; idle/sleep DDR rates, self-refresh and contention tests. |
| `memory.interconnect` — Memory buses and bandwidth policy | BIMC, SNOC/PNOC/CNOC, MMSS NoC, GPU/MDP AXI | device | PARTIAL | ICC votes corrected; active GPU AXI 266.67 MHz, SNOC 240 MHz measured. | All masters/QoS, low-load scaling, latency and power states; measurements do not prove full correctness. |
| `memory.ocmem` — GPU on-chip memory | OCMEM SRAM and virtual NoC | device | PARTIAL | OCMEM driver and bandwidth votes used by GPU. | Measure actual OCMEM clock and validate allocation/low-power transitions. |
| `core.clocks` — Clock and reset infrastructure | XO, GCC, MMCC, RPM clocks, PLLs, resets/GDSCs | device | PARTIAL | Required storage/display/GPU/peripheral clocks operate. | Unused-domain shutdown and every low-power/resume clock/reset dependency. |
| `core.regulators` — PMIC and power rails | PM8226 SPMI, RPM regulators, fixed board enables | device | PARTIAL | Core and active peripheral rails operate through Linux frameworks. | Full rail ownership and sequencing, especially panel/bridge and remaining peripherals. |
| `core.interrupts` — Timers, interrupts and pin control | GIC, ARM timers, TLMM, PMIC GPIO/MPP | device | WORKING | Timer/IRQ/pinctrl framework supports the running system. | Pin/wake audit for unused peripherals and deep sleep; no separate physical acceptance of every pin. |
| `core.dma` — DMA controllers | BAM DMA and device DMA mappings | device | PARTIAL | BAM binds; active devices transfer data. | Exercise future audio/camera/USB/modem channels and fault cleanup. |
| `core.iommu` — Address translation and isolation | GPU ARM SMMU; legacy display IOMMU/TZ tables | device | PARTIAL | Native GPU/MDP mappings and observed NULL-domain failure fixed. | Repeated fault/recovery and suspend; camera/video contexts not brought up. |
| `core.ipc` — Remote subsystem communication | SMEM, SMD/RPMSG, SMSM, SMP2P, RPM, hwspinlock | device | PARTIAL | RPM and WCNSS use working native communication paths. | ADSP/MPSS services, restart and subsystem power coordination. |
| `core.scm` — Secure firmware interface | TrustZone/SCM, legacy secure IOMMU setup | device | PARTIAL | Required SCM calls/display mapping work. | Other secure services/permissions remain board-specific; RTC writes denied. |
| `core.nvmem` — Hardware calibration and identities | QFPROM/eFuses, per-device EFS and WCNSS NV | device | PARTIAL | QFPROM provider and private Wi-Fi NV/BT factory identity used. | Consumer-by-consumer calibration inventory; preserve private backups and never synthesize RF data. |
| `core.prng` — SoC random generator | Qualcomm PRNG at f9bff000 | device | PROBES | Driver binds but explicitly reports TRNG support not detected; rng_available is none. | Audit supported PRNG interface if useful; do not expose it as a proven physical entropy source. |
| `core.crypto` — Hardware cryptography | QCE/qcrypto/qcedev engine and BAM | device | RESEARCHING | Android binds qce at fd400000.qcom,qcedev; native QCE module exists but no board integration observed. | Identify engine version and native DT/DMA/clocks, then standard crypto test vectors/performance. |
| `core.debug` — Hardware diagnostics | ARM PMU; CoreSight/JTAG/trace fabric | device | PARTIAL | PMU cycle counter corroborated CPU rate; some other PMU events returned invalid zero data. | Validate supported PMU events; CoreSight/external UART/JTAG access not established. |

### Storage

| ID / function | Hardware | Presence | State | Implemented / observed | Remaining acceptance |
|---|---|---|---|---|---|
| `storage.emmc` — Internal storage | 16 GB eMMC, SDHCI1 | device | PARTIAL | Read-only critical-partition backups and size 30777344 sectors verified; controller bound. | Safe disposable-file read/write, timing modes, suspend and power-loss behavior; no destructive partition tests. |
| `storage.sd` — Removable storage | microSD, SDHCI2, card detect and supply loads | device | WORKING | Current rootfs boots/runs; prior ext4 write/readback passed. | Card hotplug outside rootfs, other cards, signal modes and sleep recovery. |
| `storage.integrity` — Storage recovery and safe updates | ext2 SD boot, ext4 rootfs, flush/atomic image replacement | device | PARTIAL | Checked SD-only kernel replacement and retained rollback used. | Filesystem/power-interruption tests, package-aware update and recovery-image reproducibility. |

### Display

| ID / function | Hardware | Presence | State | Implemented / observed | Remaining acceptance |
|---|---|---|---|---|---|
| `display.kms` — Native display controller and link | MDP5 -> 28 nm DSI PHY -> TC358764 -> LVDS LCD, 1280x800 ~60 Hz | device | PARTIAL | Real full-screen pattern and desktop accepted on native output; MDP/DSI/bridge/panel bound now. | Stable modeset/DPMS/sleep under application load and link/power acceptance. |
| `display.panelpower` — LCD and bridge power ownership | LCD rails/enables and TC358764 reset; exact panel supplier unconfirmed | device | PARTIAL | Working timing/PHY sequence; firmware power retention still used. | Identify all physical rails/panel variant and implement cold init + full off/on without firmware hold. |
| `display.backlight` — Backlight and brightness | TI LP8556 at I2C 0x2c | device | PARTIAL | Actual Phosh slider and BRT register span 2/7/23/76/255; DPMS checked. | Physical luminance/endpoints and repeated current-build sleep/power sequencing. |
| `display.scanout` — Presentation, vblank and buffer handoff | Native DRM/KMS with split render/display devices | device | PARTIAL | Full-screen direct scanout about 59.993 presentations/s; simpledrm is not desktop output. | General composition still about 33 FPS in historical drawer runs; fence/latency/tearing acceptance. |
| `display.gpu` — 3D acceleration | Adreno 305B, msm DRM, Freedreno Mesa 25.0.7 | device | PARTIAL | Hardware GLES rendering and ordinary Phosh work. | Settings workload still triggers Adreno hangs; no claim of general stable 60 FPS. |
| `display.recovery` — GPU and compositor fault recovery | A3xx recovery, fences, Phoc/wlroots | device | REGRESSION | Recovery patches exist; #19 settings test logged GPU hang then Phoc SIGSEGV/black screen. | Reproduce/isolate fault and recover automatically without losing the session; manual session recovery is insufficient. |
| `display.color` — Color, overlays and screen capture | MDP planes/blending, gamma/LUT; vendor mDNIe policy | device | PARTIAL | Owner accepted normal colors; software screenshots and basic planes used. | Plane/alpha matrix, color controls and screen-capture paths; Samsung mDNIe not reimplemented. |
| `display.console` — Early boot console and KMS takeover | Firmware framebuffer/simplefb -> native DRM console | device | WORKING | Owner confirmed boot text and subsequent desktop; early framebuffer intentionally remains transitional. | Repeat cold/kexec/rollback transitions without blue/black gaps or competing display owners. |

### Input and sensors

| ID / function | Hardware | Presence | State | Implemented / observed | Remaining acceptance |
|---|---|---|---|---|---|
| `input.touch` — Multitouch | Atmel maXTouch MXT1188S family, I2C 0x4a | device | WORKING | Owner accepted normal touch/PIN; standard evdev/libinput. | Full contact/edge/orientation matrix and long use on #19. |
| `input.touchpm` — Touch sleep/wake | maXTouch T7/T6 and queued MT slots | device | VERIFIED | Patch0124: 10 callback cycles, 3 real s2idle wakes, owner PIN/Power/touch acceptance on #17. | Repeat after future PM/display changes; deep suspend not covered. |
| `input.keys` — Physical keys | Power (PMIC), Home, Volume Up/Down (GPIO) | device | WORKING | Real Power and volume/Home input devices; owner accepted Power after touch fix. | Explicit each-key long-press/repeat/wake matrix and stuck-key recovery. |
| `input.touchkeys` — Capacitive navigation keys | maXTouch Back/Recent Apps keycodes | device | PROBES | Key mappings are present in DT and touchscreen input. | Physically press both and verify shell actions before declaring working. |
| `input.hall` — Cover magnet sensor | Hall switch, TLMM GPIO110 / SW_LID | device | PROBES | gpio-hall-sensor input device binds with wake capability. | Physical magnet/cover switch and screen/wake behavior. |
| `input.accel` — Accelerometer | ST K2HH, identified under Android; native LIS2HH12-compatible driver, I2C 0x1d | device | PROBES | Native IIO/SensorProxy present. Android separately identifies STM K2HH at the expected address. | Native six-orientation, axis/sign/range and sleep tests remain; Android identity is not mainline functional acceptance. |
| `input.rotation` — Automatic orientation | IIO -> iio-sensor-proxy -> Phosh/Phoc | device | PARTIAL | Service active and accelerometer advertised. | Physical rotation must rotate image and touch mapping correctly; do not equate D-Bus presence with acceptance. |
| `input.grip` — Grip/SAR sensor | Semtech SX9500, I2C 0x28 on GPIO0/1, IRQ66 | device | RESEARCHING | Android SX9500 driver probes, exposes SEMTECH/SX9500 and reads back initialized I2C registers; current native DT lacks it. | Port through native IIO SX9500, validate physical grip events and coordinate modem SAR policy. |
| `input.haptic` — Vibration | ISA1200, I2C 0x48 on GPIO12/13; enable32/clock34 | vendor | RESEARCHING | Live Android DT includes ISA1200, but no bound device/timed-output vibrator observed. Actual CONFIG_HAPTIC_ISA1200=n; CONFIG_CONFIG_HAPTIC_ISA1200=y is a distinct symbol. | Confirm fitted controller/motor before native force-feedback integration; a DT template is not physical presence. |
| `input.leds` — Navigation/notification lights | Revision-dependent button-backlight GPIO; PMIC LED templates | unknown | UNKNOWN | Only virtual mmc activity LEDs exposed now; button light appears in r00, absent in r02. | Confirm populated LEDs and wiring on actual PCB before adding a driver. |

### Power

| ID / function | Hardware | Presence | State | Implemented / observed | Remaining acceptance |
|---|---|---|---|---|---|
| `power.charging` — Charging and input-current control | SMB358 external charger at 0x6a, SM5502 cable detection | device | PARTIAL | Charging/net cell current measured; 500 mA startup + AICL-backed software ramp implemented. | Full terminate/recharge and weak-source/temperature tests; rapid current-limit ramp is not guaranteed actual input current. |
| `power.battery` — Battery telemetry | PM8226 BMS1, IADC/VADC, 6800 mAh design battery | device | PARTIAL | Standard power_supply voltage/current/temperature/charge counter and UPower data exist. | Cross-check external current/voltage reference and accumulated charge over time. |
| `power.soc` — State of charge and battery health | Coulomb/OCV model; aging and learned capacity | device | PARTIAL | Modeled percentage exported; known reboot-related SOC jumps documented. | Controlled charge/discharge cycle and retention/aging calibration; displayed percent is not validated capacity. |
| `power.vbus` — External supply voltage measurement | USB input analog route to ADC not established | device | BLOCKED | PM8226 USBIN/DCIN reads do not track the external 5 V supply. | Find electrically valid measurement point; requested 4.8 V software floor cannot currently be guaranteed. |
| `power.thermal` — SoC/battery temperature and cooling | TSENS, battery thermistor, thermal/cpufreq framework | device | PARTIAL | Current CPU thermal zones 35/36 C and battery about 25.4 C readable. | Calibrated thermal throttling, battery stop/recovery and system critical-temperature policy under real load. |
| `power.pmictemp` — PMIC die overtemperature protection | PM8226 temp-alarm at 0x2400 | vendor | RESEARCHING | DT describes it; CONFIG_QCOM_SPMI_TEMP_ALARM is off; no PMIC thermal zone now. | Enable and verify sensor/IRQ/cooling policy with safe non-destructive tests. |
| `power.boardtemp` — Board/RF thermistors and current limiting | Vendor sec-thermistor, PA_THERM0/1, PMIC ADC/BCL | vendor | RESEARCHING | Vendor describes thermistor ADC and BCL paths; current public thermal interface is incomplete. | Confirm fitted sensors, conversion tables and consumer policy without confusing VBUS/system voltage with thermistors. |
| `power.sleep` — System suspend | s2idle policy; standby/deep and CPU-L2 states | device | PARTIAL | Three real logind s2idle cycles passed on #17; installed policy selects s2idle. | Whole-system consumption and repeated #19 resume; direct deep test previously hit MDP resource failure. |
| `power.wake` — Wakeup sources | Power, RTC, Hall; touch/USB/radio as individually validated | device | PARTIAL | Power/touch interaction physically accepted; three RTC-alarm s2idle wakes passed. | Per-source matrix including unwanted wakeups; Wi-Fi/BT/modem wake not accepted. |
| `power.rtc` — Timekeeping and alarms | PM8226 RTC via rtc-pm8xxx | device | PARTIAL | Counter rate and alarm IRQ tested; relative RTC alarm used for real s2idle wake. | Calendar setting/retention unresolved: counter writes denied by firmware; safe offset persistence needed. |
| `power.watchdog` — Application processor watchdog | APSS qcom_wdt | device | BLOCKED | Probe, feed and stop worked; expiry did not reliably reset/recover Linux; counter rate load-dependent. | Resolve gating/reset routing and validate actual reset plus recoverable boot before enabling policy. |
| `power.pmicwatchdog` — PMIC watchdog | PM8226 PON watchdog, candidate pm8916_wdt | device | BLOCKED | Candidate feed/register readback passed but actual expiry failed to reset; candidate rolled back. | Understand secure clock/reset semantics; no production watchdog enabled. |
| `power.offcharge` — Charging with system off | SMB358/bootloader low-power charging path | vendor | UNKNOWN | Vendor low-power charging mode exists; no native acceptance recorded. | Unplug/replug and charge termination while Linux off, including low battery recovery. |
| `power.shutdown` — Restart, power-off and long Power reset | PS_HOLD, PMIC PON/RESIN and firmware | device | PARTIAL | Ordinary reboots and owner-forced Power resets used successfully. | Clean shutdown without USB power, charger-insert behavior, reset causes and low-battery shutdown. |

### USB

| ID / function | Hardware | Presence | State | Implemented / observed | Remaining acceptance |
|---|---|---|---|---|---|
| `usb.gadget` — USB device and console | Micro-USB 2.0, ChipIdea UDC, Qualcomm HS PHY | device | WORKING | USB ACM console and file/diagnostic transfer used; acm.usb0 active now. | Repeated plug/unplug, host compatibility, speed/error and suspend acceptance. |
| `usb.network` — USB networking/tether | Configfs ECM/RNDIS | device | IMPLEMENTING | Required gadget functions built; current gadget exposes ACM only. | Configure normal network function and pass real bidirectional traffic from an external host. |
| `usb.mtp` — USB file access/other gadget functions | FunctionFS/MTP; optional mass-storage/configfs roles | device | RESEARCHING | FunctionFS available; no MTP physical acceptance recorded. | Standard userspace file transfer and activation policy; do not export mounted root filesystem as raw mass storage. |
| `usb.host` — USB host / OTG data | ChipIdea host controller and HS PHY | device | PARTIAL | Host driver built and board supports OTG; no physical peripheral test accepted. | Known OTG cable with keyboard/mouse/storage, role switching and resume. |
| `usb.vbus` — OTG 5 V generation and protection | Board charger/power switch path; exact ownership unresolved | vendor | UNKNOWN | Vendor contains VBUS control and charger OTG descriptions. | Trace actual boost/switch route, current limit and backfeed protection before claiming powered host mode. |
| `usb.muic` — Cable, charger and accessory detection | Silicon Mitus SM5502 MUIC at 0x25 | device | PARTIAL | Native extcon driver binds and powers charging source detection. | Every relevant USB/charger/OTG cable type and attach/detach IRQ through suspend. |
| `usb.accessories` — Wired accessory routing | SM5502 UART/jig, LAN hub/dock and simultaneous power cases | vendor | RESEARCHING | Vendor enables LANHUB_TA and has UART selection GPIO; not native acceptance. | Identify supported physical accessories and verify only fitted paths; no standalone dock assumed. |

### Wi-Fi and Bluetooth

| ID / function | Hardware | Presence | State | Implemented / observed | Remaining acceptance |
|---|---|---|---|---|---|
| `radio.shared` — Shared wireless subsystem | Pronto/WCNSS + WCN3660, stock firmware/NV, SMD | device | PARTIAL | WCNSS running; shared stock firmware verified; Wi-Fi and BT initialize. | Reliable firmware crash/hot restart, rail/power ownership and calibration lifecycle. |
| `wifi.managed` — Wi-Fi station | One WCN3660 radio, 802.11a/b/g/n, 2.4/5 GHz | device | WORKING | Real managed DHCP/SSH traffic and return after monitor accepted. | Band/rate/security/roaming matrix, resume and stability; not Wi-Fi 5/ac. |
| `wifi.ap` — Wi-Fi access point | wcn36xx/mac80211 + hostapd | device | WORKING | WPA2 AP with independent client DHCP, ping 4/4 and HTTP 200 passed. | PMF-required/WPA3 are not established; all bands and multiclient behavior. |
| `wifi.monitor` — Monitor and raw injection | Standalone monitor RX/filter/raw TX | device | WORKING | Raw RX, authorized probe/data responses and hcxdumptool handshake capture passed. | Advanced radiotap/RF/FCS controls and loss characterization; exclusive monitor only. |
| `wifi.concurrent` — Concurrent Wi-Fi roles | Managed/AP plus monitor or multiple VIF combinations | device | RESEARCHING | Unrestricted monitor + normal data interfaces is not implemented. | Firmware/interface-combination support and real independent-client tests. |
| `wifi.p2p` — Wi-Fi Direct and wireless display transport | P2P GO/client; Miracast is a userspace feature | device | UNKNOWN | No native end-to-end P2P acceptance; not a separate Wi-Fi adapter. | Capability audit and peer connection/data; Miracast additionally needs video encode and policy. |
| `wifi.pm` — Wi-Fi power saving and restart | mac80211 power save, WCNSS suspend/wake/recovery | device | PARTIAL | Ordinary networking works; firmware hot-restart failure documented. | Sleep traffic recovery, WoWLAN capability and measured idle draw; no hot-unbind as normal mode switch. |
| `wifi.regulatory` — Radio channels, DFS and RF controls | Factory WCNSS NV + cfg80211 regulatory limits | device | PARTIAL | 38 supported channels tune in short test; NV lacks channel144, now correctly excluded. | Country/DFS/CAC/HT40/TX power/antenna features only as firmware and regulation permit. |
| `bt.controller` — Bluetooth controller | Same WCN3660; native btqcomsmd; Bluetooth 4.0 BR/EDR + LE | device | WORKING | HCI version6, factory identity, discovery and pairing observed. | Classic security/profile matrix and controller recovery; controller version is not BT5 from mouse branding. |
| `bt.ble` — BLE HID and basic GATT | BlueZ, HID over GATT, UHID/evdev | device | VERIFIED | Owner Baseus mouse paired/bonded; 982 relative + 2 button events; physical operation confirmed. | Other GATT devices and repeated reconnect; acceptance is this BLE HID test only. |
| `bt.classic` — Classic pairing, HID and profiles | BR/EDR, HIDP, SSP, BlueZ | device | IMPLEMENTING | Controller advertises Classic; kernel HIDP/profile infrastructure available. | Real Classic-device pairing and HID/data; BLE success does not cover Classic. |
| `bt.audio` — Bluetooth music and remote controls | A2DP/AVRCP through PipeWire/BlueZ | device | IMPLEMENTING | PipeWire Bluetooth endpoints registered. | Real output/input and codec/reconnect/latency acceptance; registration is not audio playback. |
| `bt.voice` — Bluetooth voice | HFP/HSP and SCO/eSCO/PCM audio route | device | RESEARCHING | Profile infrastructure alone does not implement this board voice route. | Audit SCO transport/PCM/ADSP path and real microphone+speaker call audio. |
| `bt.data` — Bluetooth networking and serial/file profiles | BNEP/PAN, RFCOMM/TTY; OBEX profiles | device | IMPLEMENTING | BNEP and RFCOMM modules enabled. | Real PAN traffic/RFCOMM transfer; OBEX/PBAP/MAP need explicit userspace services if desired. |
| `bt.pm` — Bluetooth sleep and reconnection | WCNSS/BlueZ bonding, radio wake/runtime PM | device | UNKNOWN | One recovery reconnect worked; no BT sleep acceptance. | Repeated system sleep, radio toggle, automatic mouse/audio reconnect and idle power. |
| `radio.coexistence` — Wi-Fi/Bluetooth coexistence | Shared WCNSS/antenna scheduling | device | PARTIAL | Both initialize on #19; no controlled simultaneous throughput/audio test. | Loaded Wi-Fi plus BLE/audio without resets, input stalls or excess draw. |

### Audio

| ID / function | Hardware | Presence | State | Implemented / observed | Remaining acceptance |
|---|---|---|---|---|---|
| `audio.dsp` — Audio DSP and transport | Q6 ADSP/LPASS, APR/AFE/ASM and SLIMbus NGD/BAM | device | RESEARCHING | Android binds pil-q6v5-lpass and exposes an ALSA card; native ADSP/SLIMbus remain disabled. | Native ADSP firmware/services and SLIMbus transfer before endpoint acceptance. |
| `audio.codec` — Analog audio codec | Qualcomm WCD9306/Tapan, detected under Android; SLIMbus, MCLK 9.6 MHz | device | RESEARCHING | Running Android reports wcd9306 detected, SLIMbus devices and msm8226-tapan-snd-card; current native system has no ALSA card. | Native codec/regulator/reset/IRQ integration and actual playback/recording acceptance. |
| `audio.speakers` — Built-in speakers and amplifier routing | Two speakers in SM-T531 manual; board GPIO23/24 enables | vendor | RESEARCHING | Physical endpoints documented, no accepted native sound. | Real left/right playback, gain/pop/protection and speaker power-off. |
| `audio.mic` — Built-in microphone recording | Main microphone; additional vendor mic routes need board confirmation | vendor | RESEARCHING | Manual shows microphone; vendor generic routing also names Sub Mic. | Record intelligible audio, gain/noise and channel selection; do not assume every generic route is populated. |
| `audio.headphones` — 3.5 mm stereo output | WCD9306 headphone DAC/amplifier and headset jack | vendor | RESEARCHING | Jack is present in manual/vendor wiring. | Real stereo audio, insertion/removal routing and safe volume. |
| `audio.headset` — Headset detection, microphone and buttons | Detect GPIO69, send/end111, ADC/micbias | vendor | RESEARCHING | Exact matisse3g earjack override found in r02 DTS. | Native ALSA jack/extcon classification and real 3/4-pole headset microphone/buttons. |
| `audio.policy` — Desktop audio integration | ALSA topology/UCM and PipeWire/WirePlumber | device | RESEARCHING | Userspace audio stack installed; built-in card absent. | Board UCM routes, mic permissions, calls/media selection and idle power. |

### Camera and video

| ID / function | Hardware | Presence | State | Implemented / observed | Remaining acceptance |
|---|---|---|---|---|---|
| `camera.rear` — Rear camera sensor | SR352, about 3 MP, vendor YUV sensor program | device | RESEARCHING | Android probes SR352, verifies chip ID 0xc2 and exposes SILICONFILE_SR352; no native capture node. | Native sensor driver, safe supplies and real image capture; Android probing is presence evidence only. |
| `camera.front` — Front camera sensor | SR130PC20, about 1.3 MP, vendor YUV sensor program | device | RESEARCHING | Android probes SR130PC20, verifies chip ID 0xc1 and exposes SILICONFILE_SR130PC20. | Native front sensor integration and actual captured images. |
| `camera.pipeline` — Camera receiver and image pipeline | CAMSS CCI, MCLK, CSIPHY/CSID, ISPIF/VFE, CPP/VPE where fitted | vendor | RESEARCHING | CCI SoC description exists disabled; vendor camera resources mapped. | MSM8226 native media graph, DMA/IOMMU/clocks and V4L2 streaming; modern CAMSS presence is not board support. |
| `camera.jpeg` — JPEG acceleration | Qualcomm JPEG engine in vendor camera subsystem | vendor | RESEARCHING | Vendor camera source describes engine; no native media node. | Confirm exact hardware/revision, native mem2mem integration and encode/decode test. |
| `video.codec` — Hardware video decoding and encoding | Qualcomm Venus VIDC, firmware and video IOMMU | device | RESEARCHING | Android binds pil_venus; current native system has no video/media nodes. | Native MSM8226 HFI/firmware/resources and real decode/encode; Android binding alone is not video acceptance. |

### Cellular and location

| ID / function | Hardware | Presence | State | Implemented / observed | Remaining acceptance |
|---|---|---|---|---|---|
| `modem.boot` — Cellular baseband and RF | Integrated MPSS/Q6 modem, MBA, RF transceiver/front end | device | RESEARCHING | Android binds pil-q6v5-mss; native modem DT remains disabled. No cellular traffic/call test performed in this audit. | Identify RF parts, preserve NV and bring up native remoteproc/RMTFS/QMI. |
| `modem.sim` — SIM and network registration | Single SIM slot, UIM/QMI, GSM/UMTS RF | vendor | RESEARCHING | Manual documents SIM/cellular use; no native modem service accepted. | Real SIM detection/PIN, antenna/bands and operator registration. |
| `modem.data` — Cellular packet data | GSM/GPRS/EDGE and UMTS/HSPA; BAM-DMUX/QMI networking | vendor | RESEARCHING | Generic modem/BAM-DMUX source exists, board modem disabled; SM-T531 is not LTE model. | Native control/data path and real IP traffic through an owner SIM. |
| `modem.sms` — SMS/MMS services | QMI messaging; MMS is userspace over mobile data | vendor | RESEARCHING | No native SMS acceptance recorded. | Send/receive real SMS and notification/wakeup; MMS needs separate data/APN/client acceptance. |
| `modem.calls` — Voice calls and call audio | 2G/3G modem voice + ADSP/codec routes | vendor | RESEARCHING | Stock manual documents calls; neither signaling nor audio is accepted in Linux. | Incoming/outgoing call, two-way audio, routing, suspend wake; emergency behavior requires separate care. |
| `modem.gnss` — Satellite positioning | Qualcomm location subsystem; GPS antenna; supported constellations need confirmation | vendor | RESEARCHING | GPS antenna/location documented; native position fix absent. | Establish firmware/control path (likely modem QMI LOC, still hypothesis), cold fix, tracking and suspend/power policy. |

### Unconfirmed or variant-only

| ID / function | Hardware | Presence | State | Implemented / observed | Remaining acceptance |
|---|---|---|---|---|---|
| `optional.alsprox` — Ambient light / optical proximity | CM36653/TMD2672 in early r00 templates | unknown | UNKNOWN | Missing from r02; relevant drivers disabled in full matisse3g config; HasAmbientLight=false now. | Treat as unconfirmed population, not a missing working sensor; BOM/physical confirmation first. |
| `optional.compassgyro` — Magnetometer / gyroscope | Early HSCDTD008 and other generic sensor options | unknown | UNKNOWN | No device in current DT; gyro/compass options disabled in full config. | No basis to promise these sensors; distinguish sensor fusion from a physically fitted gyro/compass. |
| `optional.ir` — Infrared remote transmitter | MC96FR332/MC96FR116 family, early/common board variants | unknown | UNKNOWN | r00/r01 include IR node; r02 omits it; full matisse3g driver disabled and GPIO4/62 marked NC. | Confirm actual fitted hardware before porting; Wi-Fi/US variants are not evidence for SM-T531. |
| `optional.nfc` — NFC | SEC NFC/PN547 generic family alternatives | unknown | UNKNOWN | Board NFC block commented out; matisse3g NFC configs disabled. | Not confirmed as fitted on SM-T531; no porting task unless BOM/physical evidence establishes it. |
| `optional.fm` — FM broadcast radio | WCN3660/Qualcomm iris FM capability; board RF route unknown | unknown | BLOCKED | [Native candidate](FM.md): `/dev/radio0`, 49/49 V4L2 API checks; all 29 supplied frequencies give zero signal/no RDS with wired headphones. Preserved Android also gives zero RSSI. Candidate stays outside production. | Service-manual text suggests unwired FM pins; visually verify schematic pins 41/48/61/68 before more driver work. Absence remains unproven. RF/RDS/seek, power-off and suspend are unaccepted. |
| `optional.videoout` — Wired external display | Possible MHL/HDMI accessory claims; no verified board transmitter | unknown | UNKNOWN | No dedicated connector in manual layout or board MHL transmitter identified in inspected DT; no accepted output. | Do not assume MHL from accessory listings or generic HDMI audio DAI; obtain schematic/BOM evidence. |
| `optional.flashaf` — Camera flash, autofocus and calibration peripherals | Generic PM8226 flash nodes; no proven physical LED/actuator/EEPROM | unknown | UNKNOWN | Vendor templates include flash even for this camera file; this does not establish physical population. | Confirm modules/flash/actuator/OTP/EEPROM before adding nodes; never activate generic high-current flash blindly. |
| `optional.ant` — ANT / ANT+ | Potential shared-radio service | unknown | UNKNOWN | No inspected board-specific source or native hardware test establishes usable ANT. | Find actual firmware endpoint/product support and a physical ANT peer before calling it present. |
| `optional.ethernet` — Built-in Ethernet / HSIC and dock | KS8851/HSIC generic reference-board nodes; USB Ethernet separate | unknown | UNKNOWN | KS8851 node disabled; no physical built-in Ethernet established; vendor lists USB dongle drivers. | Do not count generic node as a populated NIC; USB Ethernet can be tested after USB host works. |
| `optional.other` — Other product-family options | Fingerprint, barometer, sensor hub, S Pen, TV tuner, wireless charging | unknown | UNKNOWN | No positive SM-T531 board-specific evidence in inspected sources/current device. | Outside confirmed inventory until physical/BOM evidence; shared kernel options alone do not imply population. |

## Suggested sequence and acceptance gates

1. **P0 — reliable graphics and recovery.** Isolate the current settings/Adreno hang and Phoc failure; validate fence/IOMMU/recovery; complete LCD/bridge rail ownership and ordinary composition measurements. Recheck memory/interconnect/OCMEM active and low-power behavior. Stable operation comes before a blanket 60 FPS promise.
2. **P1 — power, protection and persistence.** Finish PMIC/board temperature exposure, charger termination/recharge and a calibrated battery model; resolve VBUS measurement. Then repeated sleep/wake and measured draw for display/touch/radios/storage. RTC calendar and actual watchdog reset need separate safe fixes. Preserve working rollback.
3. **P2 — audio and normal peripheral use.** ADSP -> SLIMbus -> WCD9306 -> ALSA card -> speakers/mic/headset -> UCM/PipeWire; in parallel sequencing terms, MUIC/5 V ownership -> OTG/USB peripherals. Accept rotation/Hall, confirm and port ISA1200/SX9500, then full Bluetooth music/data/reconnect and radio coexistence.
4. **Media acceleration.** Establish Venus firmware/HFI/resources and V4L2 decode/encode. Camera CCI/rails/clocks/CSI/VFE graph precedes SR352/SR130PC20 streaming and JPEG/app integration. These are independent from successful GPU rendering.
5. **Cellular/location.** MPSS/MBA/RMTFS/QMI -> SIM/network registration -> data/SMS -> voice signaling plus audio route -> location/real fix. Hardware privacy and RF calibration must stay intact.
6. **Optional hardware.** First establish population from this tablet/BOM for IR/ALS/compass/NFC/FM/MHL/flash/ANT and other templates; do not add guessed nodes to production. Wi-Fi PMF/P2P/concurrency are distinct firmware/driver tasks, not prerequisites for ordinary managed connectivity.

For every row: research exact hardware -> smallest separate patch/configuration -> build/source checks -> recoverable device deployment -> real endpoint acceptance -> classify evidence. Closing one row does not close every profile on the same chip. Explicit dependencies and per-row evidence are in YAML. This audit does not commit to time estimates.

## Source keys

| Key | Source | Scope |
|---|---|---|
| `live` | [VERIFIED_DEVICE](../docs/hardware-observation-20261022.json) | Read-only #19 probe/interface snapshot; earlier physical tests are separately dated. |
| `dt` | [VERIFIED_DEVICE](../docs/hardware-observation-20261022.json) | Read-only deployed DT compatible/status list, cross-checked with local board/SoC source; no claim local patches are merged upstream. |
| `config` | [VERIFIED_DEVICE](../config/kernel.fragment) | Checked against current .work/out/.config; required settings differ from generic defconfig. |
| `patches` | [VERIFIED_DEVICE](../patches/linux/) | Current applied 120-patch source; builds/patches are not physical acceptance. |
| `rng` | [VERIFIED_UPSTREAM](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/drivers/crypto/qcom-rng.c?h=v7.2.9) | Pinned base behavior: qcom,prng has hwrng_support=false; public upstream source link below. |
| `bt-driver` | [VERIFIED_UPSTREAM](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/drivers/bluetooth/btqcomsmd.c?h=v7.2.9) | Send callback handles CMD/ACL, not a demonstrated SCO transport. |
| `manual` | [VERIFIED_VENDOR_SOURCE](https://downloadcenter.samsung.com/content/UM/201506/20150602135914448/SM-T531_UM_EU_Lollipop_Eng_Rev.1.0_150602.pdf) | Samsung SM-T531 EU Lollipop English user manual rev1.0 (2015-06-02), layout p7, phone/messages/location/media chapters; manufacturer-copyrighted, not redistributed. |
| `vendor-board` | [VERIFIED_VENDOR_SOURCE](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/boot/dts/msm8226/msm8226-sec-matisse3g-r02.dtsi) | Board-specific r02; does not prove this physical PCB revision or every generic endpoint is populated. |
| `vendor-top-r02` | [VERIFIED_VENDOR_SOURCE](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/boot/dts/msm8226/msm8226-sec-matisse3g-r02.dts) | Includes SoC v2 and r02; earjack override detect69/sendend111. |
| `vendor-r00` | [HISTORICAL_SOURCE](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/boot/dts/msm8226/msm8226-sec-matisse3g-r00.dtsi) | Early revision options; NOT proof of fitted sensors/LED/IR on owner tablet. |
| `vendor-config` | [VERIFIED_VENDOR_SOURCE](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/configs/msm8226-sec_matisse3g_defconfig) | Samsung matisse3g variant fragment; positive board selections, not current Linux config. |
| `vendor-full-config` | [HISTORICAL_SOURCE](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/configs/lineage_matisse3g_defconfig) | Full downstream matisse3g config; downstream derivative, not an unmodified stock-kernel configuration. |
| `vendor-soc` | [VERIFIED_VENDOR_SOURCE](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/boot/dts/msm8226/msm8226.dtsi) | Shared MSM8226 hardware blocks; board population must be established separately. |
| `vendor-gpiomux` | [VERIFIED_VENDOR_SOURCE](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/mach-msm/board-matisse-gpiomux.c) | Includes variants and conditional NC GPIO tables; only MATISSE3G_OPEN applies here. |
| `vendor-ir` | [HISTORICAL_SOURCE](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/boot/dts/msm8226/msm8226-mc96irda.dtsi) | Included by early r00/r01; not r02. |
| `vendor-audio` | [VERIFIED_VENDOR_SOURCE](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/sound/soc/msm/msm8226.c) | Tapan/WCD9306 machine path with matisse conditionals; hardware revision still to read. |
| `vendor-therm` | [VERIFIED_VENDOR_SOURCE](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/mach-msm/sec_thermistor_8226.c) | Samsung board thermistor lookup/ADC implementation; exact fitted sensor nets unverified. |
| `vendor-camera` | [VERIFIED_VENDOR_SOURCE](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/boot/dts/msm8226/msm8226-camera-sensor-mtp-matisse_eur-r02.dtsi) | Camera supplies, enables/reset/clock and CSIPHY/CSID graph. Generic flash block is not population proof. |
| `vendor-sr352` | [VERIFIED_VENDOR_SOURCE](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/drivers/media/platform/msm/camera_v2/sensor/sr352_yuv.c) | Rear YUV sensor driver with matisse-specific tuning include. |
| `vendor-sr130` | [VERIFIED_VENDOR_SOURCE](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/drivers/media/platform/msm/camera_v2/sensor/sr130pc20_yuv.c) | Front YUV sensor driver with matisse-specific tuning include. |
| `vendor-camss` | [VERIFIED_VENDOR_SOURCE](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/boot/dts/msm8226/msm8226-camera.dtsi) | Shared camera DMA/ISP/JPEG resources; used as research, not transplanted Android HAL. |
| `vendor-display` | [VERIFIED_VENDOR_SOURCE](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/boot/dts/msm8226/dsi_panel_tc358764_wxga_video-r01.dtsi) | Board DSI/LVDS timing and PHY reference; final panel supplier not identified. |
| `recovery` | [VERIFIED_DEVICE](../docs/RECOVERY.md) | Acceptance scope/build/date stated in that document; historical test is not a fresh #19 acceptance. |
| `build` | [VERIFIED_DEVICE](../docs/BUILD-DEPLOY.md) | Acceptance scope/build/date stated in that document; historical test is not a fresh #19 acceptance. |
| `bt` | [VERIFIED_DEVICE](../docs/BLUETOOTH.md) | Acceptance scope/build/date stated in that document; historical test is not a fresh #19 acceptance. |
| `wifi` | [VERIFIED_DEVICE](../docs/WIFI.md) | Acceptance scope/build/date stated in that document; historical test is not a fresh #19 acceptance. |
| `memory` | [VERIFIED_DEVICE](../docs/MEMORY-BUS.md) | Acceptance scope/build/date stated in that document; historical test is not a fresh #19 acceptance. |
| `graphics` | [VERIFIED_DEVICE](../docs/GRAPHICS-STABILITY.md) | Acceptance scope/build/date stated in that document; historical test is not a fresh #19 acceptance. |
| `native` | [VERIFIED_DEVICE](../docs/NATIVE-KMS.md) | Acceptance scope/build/date stated in that document; historical test is not a fresh #19 acceptance. |
| `performance` | [VERIFIED_DEVICE](../docs/GRAPHICS-BOTTLENECK.md) | Acceptance scope/build/date stated in that document; historical test is not a fresh #19 acceptance. |
| `backlight` | [VERIFIED_DEVICE](../docs/BACKLIGHT.md) | Acceptance scope/build/date stated in that document; historical test is not a fresh #19 acceptance. |
| `touch` | [VERIFIED_DEVICE](../docs/TOUCH-SLEEP.md) | Acceptance scope/build/date stated in that document; historical test is not a fresh #19 acceptance. |
| `charging` | `VERIFIED_DEVICE`; local record `docs/CHARGING.md` (not published in this commit) | Acceptance scope/build/date stated in that document; historical test is not a fresh #19 acceptance. |
| `chargepath` | `VERIFIED_DEVICE`; local record `docs/CHARGE-PATH.md` (not published in this commit) | Acceptance scope/build/date stated in that document; historical test is not a fresh #19 acceptance. |
| `vbus` | `VERIFIED_DEVICE`; local record `docs/VBUS.md` (not published in this commit) | Acceptance scope/build/date stated in that document; historical test is not a fresh #19 acceptance. |
| `battery` | [VERIFIED_DEVICE](../docs/BATTERY.md) | Acceptance scope/build/date stated in that document; historical test is not a fresh #19 acceptance. |
| `rtc` | `VERIFIED_DEVICE`; local record `docs/RTC-WATCHDOG.md` (not published in this commit) | Acceptance scope/build/date stated in that document; historical test is not a fresh #19 acceptance. |
| `firmware` | [VERIFIED_DEVICE](../docs/FIRMWARE.md) | Acceptance scope/build/date stated in that document; historical test is not a fresh #19 acceptance. |
| `android` | [VERIFIED_DEVICE](ANDROID-HARDWARE-AUDIT.md) | Preserved Android kernel live-DT/config/probe cross-check; full BOOT restored. |
