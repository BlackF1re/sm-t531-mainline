# WCN36xx Wi-Fi mode bring-up

Ongoing device investigation, 2026-10-20 UTC / 2026-10-21 Tomsk.
Initial tests used `7.2.9-dirty #9` and a separately built WLAN platform
driver with the USB recovery console. Production patches 0123–0125 were
then built and tested as kernel #10 on SD. Internal BOOT and the MSM module
were not changed. The standalone capture candidate is not in that kernel.

## Evidence so far

- VERIFIED_DEVICE: managed networking with the original WCN3660/IRIS firmware,
  API 1.5.1.2, CRM 12035159. Hardware scan message 208 times out; the existing
  driver patches fall back to software scanning.
- VERIFIED_DEVICE: mac80211 advertises software monitor interfaces, but the
  PHY permanent MAC is zero. Default monitor activation failed with
  `EADDRNOTAVAIL`; an explicitly assigned local unicast address fixes activation.
- VERIFIED_DEVICE: an associated station plus passive monitor captured radiotap
  packets. This observes the firmware-filtered receive path and does not prove
  unrestricted other-BSS/control-frame capture.
- VERIFIED_DEVICE: the owner's open test AP supplied DHCP; its gateway answered
  four of four ICMP requests. Three individually injected directed probe requests
  each elicited a probe response, with RX radio metadata. This establishes
  actual over-air management-frame transmission, beyond local TX echo/send().
  It does not verify every frame subtype, arbitrary source/rate/sequence or FCS.
- VERIFIED_DEVICE: unbinding/reprobing WLAN failed with `-ENXIO`: the DT requests
  rising edges for GIC hwirqs 177/178, while `wcn36xx_dxe_request_irqs()` programs
  both level-high. The existing mappings reject a new edge specification.
  Re-arming just these unbound IRQs to the DT mode allowed the built-in driver
  to rebind and restored managed networking, without a reboot. A DT candidate
  instead describes the level-high mode already used by the working driver.

Candidates and temporary recovery tools are not production acceptance. Raw
captures, network configurations and device identifiers stay private under
`.work/wifi-20261020` and `/var/lib/t531/wifi-20261020`.

## Authoritative sources

- Linux v7.2.9, `drivers/net/wireless/ath/wcn36xx/{main,txrx,dxe,smd,hal}` and
  `net/mac80211/{iface,tx}.c`, pinned project kernel plus recorded patches.
  The monitor interface flags added by mac80211 do not implement firmware
  promiscuous reception on their own.
- [Samsung/Qualcomm prima HAL header](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/drivers/staging/prima/riva/inc/wlan_hal_msg.h),
  retrieved and matched against the research copy on 2026-10-20 UTC; SHA256
  `ec316e219331373398a07d62c818be246a9826a4ea07b623510b1728e7b7720b`.
  ISC-style permissive license, original Qualcomm/Linux Foundation authorship.
  Defines monitor request/response IDs 302–305 and packed request layout;
  zero MAC filters means receive all. Source-level ABI presence alone does
  not establish implementation by this board's firmware.
- The same revision's `CORE/WDI/CP/src/wlan_qct_wdi.c`,
  `WDI_ProcessMonStartReq()` and `WDI_ProcessMonStopReq()`, supplies the
  corresponding request parameters and stop behavior.
- [Linux mac80211 injection interface](https://docs.kernel.org/networking/mac80211-injection.html):
  radiotap injection and optional controls. Firmware rate-control restrictions
  must be measured instead of assuming every radiotap request is honored.
- [Linux Wireless wcn36xx page](https://wireless.docs.kernel.org/en/latest/en/users/drivers/wcn36xx.html)
  is useful historical context; several claims are stale relative to current
  driver source, so the on-device tests and code take precedence.

## Recovery during trials

The test driver is named `t531-wcn36xx-trial`, distinct from the built-in
`wcn36xx`. A timed rollback is armed before changing the binding. The original
managed profile and station address are retained. The temporary IRQ recovery
module refuses a bound WLAN device and checks this exact board/GIC mapping;
it does not touch firmware or run automatically at boot. Permanent DT handling
must remove the need for this diagnostic step.

The vendor monitor-enable request 302 received no response in two 10-second
attempts on this firmware. That candidate path is BLOCKED for the installed
image; ordinary managed service recovered afterwards. No production claim or
firmware replacement follows from the header alone. Channel-only and legacy
PROMISC paths are being tested separately.

AP open mode passed an independent MT7921/Windows client test: beacon discovery,
association at 72.2 Mbit/s, DHCP lease, and HTTP retrieval of a public marker.
The test DHCP service omitted router/DNS options, preserving the host's Ethernet
uplink. This is functional AP acceptance, not just successful `start_ap`.

## WPA2 AP and PMF

VERIFIED_DEVICE: WPA2-PSK/RSN/CCMP AP passed the independent client test as
well: four-way handshake, authorized station, DHCP, HTTP marker (200), and
four of four gateway pings (0–1 ms). PMF was disabled for this test.
The failure before that setting was traced in wpa_supplicant DEBUG logs:
CCMP GTK index 1 installed successfully; AES-CMAC IGTK index 4 failed
cfg80211 key validation. The driver's advertised cipher list lacks AES-CMAC,
and its BSS configuration hardcodes `rmf = 0`. This is not a failed PSK or
broken CCMP data path.

`config/wcn36xx-networkmanager.conf` supplies PMF=disabled as the default only
for `driver:wcn36xx`; explicit profile settings take precedence. Install with
`sudo scripts/configure-wifi.sh` on the SM-T531. This retains WPA2 CCMP;
WPA3/mandatory PMF is not established. Existing AP profiles explicitly set
to optional/required PMF need `nmcli connection modify NAME wifi-sec.pmf disable`.
The [NetworkManager reference](https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html)
documents `wifi-sec.pmf` connection defaults and driver matching.

## Standalone capture: precise limits

The legacy `INIT_SCAN(PROMISC)` → `START_SCAN(channel)` path received 741
actual RX frames in a 12-second test: 738 beacons and three probe responses.
Six additional records were local echoes of the three injected requests.
All three requests using the registered radio address elicited an over-air
response. A longer test received 3777 records in 45 seconds, without kernel
capture drops. The cleaned implementation captured 393, 129 and 78 records
in five seconds each on channels 1, 6 and 36, and returned to managed service.
No transmissions were requested on channel 36 (NO_IR).

**PARTIAL, not unrestricted RFMON:** no data/control reception has been
established. A request using a different source address was accepted locally
but no response was received; arbitrary-source injection remains UNKNOWN.
The test tool's successful `send()` or a TX echo is never counted as physical
transmission acceptance. Rate selection, bad-FCS reception, arbitrary frame
subtypes and FCS retention have not been validated. Stock firmware rate
control remains enabled.

Channel switching alone, and INIT_SCAN(PROMISC) followed by SWITCH_CHANNEL
without START_SCAN, each captured only the six TX echoes, zero RX. Vendor
request 302 timed out. The legacy scan path therefore improves management
capture but is not evidence that firmware forwards all traffic. A second
client's attempt to join the owner's 802.11b AP failed on Windows, so it did
not supply a controlled unicast-data test. That is an inconclusive test,
not proof that the tablet drops such traffic.

Production patches 0123–0125 cover TX context/header validation, matching
level-high WLAN IRQs, and a valid local PHY MAC fallback. Candidate
`patches/candidates/wifi/0126-wifi-wcn36xx-legacy-scan-capture.patch` is deliberately
excluded from the normal kernel build. It removes the nonresponsive HAL302
experiment and does not advertise control/other-BSS data filtering support.
`tools/build-wifi-trial.sh` reproducibly builds it as a separate WLAN driver;
it does not install, bind or enable anything automatically.

The task's full managed/AP/monitor/injection acceptance is **not complete**.
The next acceptance requires controlled data/control reception and arbitrary
TX confirmation with an independent capture-capable receiver, or a proven
firmware receive-filter implementation for this exact WCN3660 image. Do not
replace calibration or flash another chipset's firmware to bypass this gap.

## Kernel #10 deployment and restart finding

VERIFIED_DEVICE: the corrected #10 native-ICC image booted with native
graphics/greetd, factory station MAC and managed DHCP/SSH. WPA2 AP with
PMF=default picked up the driver-specific NM configuration and passed the
external handshake/DHCP/HTTP test. Default-address monitor activation and
three of three directed probe responses passed using the built-in driver.

The initial #10 container was accidentally packaged with the base DTB;
native graphics did not start. USB remained usable and the one-boot restore
returned #9 to SD. The corrected DT was compared with the #9 artifact: only
the two WLAN IRQ trigger cells differ. The corrected image was booted and
tested before promotion. Its kernel configuration and MSM module are
byte-identical to #9.

- Previous SD image #9 SHA256:
  `81730fb3bfc9baf34dd827fa3171dc5e25884ffe961e11362b1eab6d8e51506c`.
- Corrected SD image #10 SHA256:
  `6602817e4293e3c9ecf06de9c05545f8ad265dace1255dac46b44a51e2a40ea1`.
- Unchanged MSM module SHA256:
  `8f6a70bd3350add8a427263706952dc0fb04820e5f88fe5a54ec596c6351fa6f`.

Hot WLAN rebinding no longer failed at GIC mapping with -ENXIO, but one
subsequent firmware NV upload (request 55) timed out. A later retry blocked
NetworkManager in `qcom_smd_send`, holding RTNL and blocking an `ip link`
query. This is a separate, unresolved firmware/transport lifecycle problem;
patch0124 does **not** establish reliable hot rebinding.

The timeout in `wcn36xx_smd_send_and_wait()` starts its completion wait only
after `rpmsg_send()` returns; `__qcom_smd_send()` can wait indefinitely for
TX FIFO space. Recovery was possible without restarting the tablet:
reconnect USB to obtain a fresh console after the blocked foreground query,
kill the blocked NetworkManager process, stop its restart job, and restart
WCNSS through remoteproc. The initial explicit NM activation raced device
creation; normal autoconnect then restored the original network and SSH.
No new pstore entry was present. Do not automatically hot-unbind WLAN in
normal startup or offer the experimental driver as a production mode switch.

The #9 backup remains under `/var/lib/t531/kernel-trial-backup`; the older
backup was retained under `/var/lib/t531/kernel-trial-before-wifi-0125`.
The existing `t531-kernel-trial-restore --rollback` procedure restores #9
on SD, with verified image/initramfs/cmdline/module hashes.

## Reproducibility checks

All 124 production patch files applied to a temporary index of the pinned
kernel base, with zero differences against the built source tree. Kernel,
native-ICC DTB and matching modules built successfully. The three production
Wi-Fi patches and candidate0126 passed checkpatch with zero errors/warnings.
The diagnostic driver and guarded IRQ helper built separately; shell syntax,
Python compilation and the public JSON dataset were checked. These software
checks do not extend the physical acceptance listed above. Rootfs creation
also installs the driver-specific NetworkManager default.
