# Samsung Galaxy Tab 4 SM-T531 — hardware

## Platform

| Component | Identification / specification | Presence |
|---|---|---|
| SoC | Qualcomm MSM8226, ID 158, revision 2.0 | Device |
| CPU | 4× Cortex-A7, ARMv7, NEON, VFPv4 | Device |
| CPU OPPs | 300 / 384 / 600 / 787.2 / 998.4 / 1094.4 / 1190.4 MHz | Device |
| L2 | Shared Cortex-A7 L2, SAW2 | Device |
| RAM | 1536 MiB; exact package/type unknown | Device |
| Memory controller | BIMC | Device |
| Interconnect | SNOC, PNOC, CNOC, MMSS NoC, GPU/MDP AXI | Device |
| On-chip memory | OCMEM SRAM, GMEM | Device |
| Clock/reset controllers | GCC, MMCC, RPM, APCS/SAW, PLL, GDSC | Device |
| Interrupts/timers | ARM GIC, architected timers | Device |
| Pin control | Qualcomm TLMM, PMIC GPIO/MPP | Device |
| DMA | Qualcomm BAM | Device |
| IOMMU | GPU ARM SMMU; display IOMMU | Device |
| Remote processors | RPM, Pronto/WCNSS, ADSP/LPASS, MPSS, Venus | Device |
| IPC | SMEM, SMD, SMSM, SMP2P, hardware spinlocks | Device |
| Secure firmware | TrustZone/SCM | Device |
| One-time storage | QFPROM/eFuses | Device |
| Crypto engine | Qualcomm QCE, BAM | Device |
| Random generator | Qualcomm PRNG, `0xf9bff000` | Device |
| Debug/trace | ARM PMU, CoreSight/JTAG fabric | Device |

## Storage

| Component | Identification / specification | Presence |
|---|---|---|
| eMMC | `016GE2`, 15,758,000,128 bytes; SDHCI1 | Device |
| eMMC layout | 26 partitions; [offsets and sizes](partitions.json) | Device |
| eMMC boot areas | boot0 / boot1, 4 MiB each | Device |
| Secure storage | RPMB | Device |
| Removable storage | microSD slot, SDHCI2, card detect | Device |
| Factory data | EFS, MODEMST1/2, FSG/FSC, PERSIST, PERSDATA, WCNSS NV | Device |

## Display and graphics

| Component | Identification / specification | Presence |
|---|---|---|
| GPU | Adreno 305B, chip ID `0x03000512` | Device |
| GPU OPPs | 19 / 200 / 320 / 450 MHz | Device |
| Display controller | Qualcomm MDP5 | Device |
| Display SMP | 7×4096 bytes; maximum 3 blocks per pipe | Sources |
| Display link | DSI, 28-nm PHY | Device |
| Bridge | Toshiba TC358764, DSI → LVDS | Device |
| LCD | 10.1-inch, 1280×800, nominal 60 Hz; supplier unknown | Device |
| Backlight | TI LP8556, I²C `0x2c` | Device |

## Input and sensors

| Component | Identification / specification | Presence |
|---|---|---|
| Touchscreen | Atmel maXTouch mXT1188S, I²C `0x4a` | Device |
| Physical keys | Power, Home, Volume Up, Volume Down | Device |
| Capacitive keys | Back, Recent Apps; maXTouch | Device |
| Cover sensor | Hall switch, GPIO110 | Device |
| Accelerometer | ST K2HH, I²C `0x1d` | Device |
| Grip/SAR sensor | Semtech SX9500, I²C `0x28`, IRQ66 | Device |
| Haptic controller | ISA1200, I²C `0x48`, enable32/clock34 | Sources |

## Power and USB

| Component | Identification / specification | Presence |
|---|---|---|
| PMIC | Qualcomm PM8226, SPMI | Device |
| Regulators | PM8226, RPM-controlled rails, board enables | Device |
| Charger | SMB358, I²C `0x6a` | Device |
| Battery | 6800 mAh design capacity | Sources |
| Battery measurement | PM8226 BMS1, IADC/VADC, thermistor | Device |
| SoC temperature | TSENS | Device |
| PMIC temperature | PM8226 temp-alarm, `0x2400` | Sources |
| Board/PA temperature | sec-thermistor, PA_THERM0/1, BCL | Sources |
| RTC | PM8226 | Device |
| Watchdogs | APSS watchdog, PM8226 PON watchdog | Device |
| Power/reset | PS_HOLD, PMIC PON/RESIN | Device |
| USB connector | Micro-USB 2.0 | Device |
| USB controller | ChipIdea, Qualcomm HS PHY; device/host hardware | Device |
| Cable/accessory detection | Silicon Mitus SM5502, I²C `0x25` | Device |
| VBUS supply/switch | Exact board ownership unresolved | Sources |

## Radio and location

| Component | Identification / specification | Presence |
|---|---|---|
| Shared connectivity | Pronto/WCNSS, WCN3660, Iris radio | Device |
| Wi-Fi | One radio; IEEE 802.11a/b/g/n, 2.4 / 5 GHz | Device |
| Bluetooth | WCN3660; 4.0 BR/EDR + LE | Device |
| Cellular modem | Integrated MPSS/Q6, RF front end | Device |
| Cellular standards | GSM/GPRS/EDGE, UMTS/HSPA | Sources |
| SIM | One SIM slot, UIM | Sources |
| Location | Qualcomm GNSS/GPS subsystem and antenna | Sources |

## Audio, cameras and video

| Component | Identification / specification | Presence |
|---|---|---|
| Audio DSP | Q6 ADSP/LPASS | Device |
| Audio transport | SLIMbus NGD/BAM | Device |
| Audio codec | Qualcomm WCD9306/Tapan, MCLK 9.6 MHz | Device |
| Speakers | Two; board enable GPIO23/24 | Sources |
| Microphone | Main microphone | Sources |
| Headset connector | 3.5-mm jack | Sources |
| Headset detection | Detect GPIO69, send/end GPIO111, ADC/micbias | Sources |
| Rear camera | Siliconfile SR352, approximately 3 MP, YUV | Device |
| Front camera | Siliconfile SR130PC20, approximately 1.3 MP, YUV | Device |
| Camera interface/ISP | CCI, MCLK, CSIPHY/CSID, ISPIF/VFE | Sources |
| Camera processing | CPP/VPE, JPEG engine; exact fitted resources unresolved | Sources |
| Video codec | Qualcomm Venus/VIDC | Device |

## Unconfirmed / revision-dependent

| Function | Candidate / description |
|---|---|
| FM | Qualcomm Iris/WCN3660; board RF/antenna path unconfirmed |
| Light/proximity | CM36653/TMD2672, early r00 descriptions |
| Compass/gyroscope | HSCDTD008 / generic variant descriptions |
| Infrared | MC96FR332/MC96FR116, early/common variants |
| NFC | SEC NFC / PN547 family alternatives |
| Navigation/notification lights | Revision-dependent GPIO/PMIC descriptions |
| Camera flash / autofocus / EEPROM | Generic vendor nodes; fitted components unconfirmed |
| External display | MHL/HDMI transmitter unconfirmed |
| ANT / ANT+ | Shared-radio service unconfirmed |
| Built-in Ethernet / dock | KS8851/HSIC reference-board descriptions |
| Other variant options | Fingerprint, barometer, sensor hub, S Pen, TV tuner, wireless charging |

Device = identified on the tablet; Sources = board/vendor documentation.
[Evidence and Linux support](../Porting%20Notes/README.md).
