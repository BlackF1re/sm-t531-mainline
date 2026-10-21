# WCN3660 managed, AP and raw monitor

Updated 2026-10-22. **VERIFIED_DEVICE:** the SM-T531 built-in WCN3660 now
receives management, control and payload Data/QoS Data in standalone monitor
mode, including non-self unicast and encrypted payload with its extended IV.
Directed probe and raw data injection elicited actual over-air responses.
Managed networking and WPA2 AP were tested again after monitor operation.
This is native wcn36xx/mac80211 support with the original firmware, not an
Android userspace dependency or a replacement firmware image.

Current support is consolidated in a single kernel patch:
[`0123-wifi-wcn3660-matisse3g-support.patch`](../patches/linux/0123-wifi-wcn3660-matisse3g-support.patch).
It includes WCNSS power/regulators, board DTS/IRQs, scanning, transport and
raw monitor/injection. The former mixed DT patch now contains charging only.
The tested
firmware is API **1.5.1.2**, CRM **12035159**, Pronto v2 / WCN3660. Capture is
exclusive: managed/AP service stops while the radio monitors a chosen channel.
Simultaneous unrestricted managed/AP + monitor is not implemented.

## Use

Install the board configuration and helper with `sudo scripts/configure-wifi.sh`.
Rootfs creation installs the same helper. From a local terminal or USB console:

```sh
sudo t531-wifi-monitor start 1
sudo t531-wifi-monitor status
sudo tcpdump -i mon0 -s 0 -w capture.pcap
# Stop tcpdump with Ctrl-C, then return to the saved managed connection:
sudo t531-wifi-monitor stop
```

For an allowed channel/width, for example: `sudo t531-wifi-monitor start 36 HT40+`.
Regulatory restrictions still apply; no transmission was requested on channel 36
in acceptance tests. `start` and `stop` submit asynchronous systemd jobs; use
`status` and `journalctl -u 't531-wifi-monitor-switch-*'` to inspect completion.
Starting monitor disconnects Wi-Fi SSH. The job survives that disconnection;
use USB/local access to stop capture. Reboot returns to normal managed startup.

The helper records the original MAC and NetworkManager connection UUID in a
root-only directory under `/run`, stops NM, creates exclusive `mon0` and retires
the inactive station. Stop restores `wlan0`, its MAC, NM and the saved connection.
An invalid-channel test exercised automatic rollback successfully. There is no
permanent test service, firmware modification or monitor autostart.

In-place station→monitor type changes with NM still running were unreliable
(no RX on initial 2.4GHz tests; occasional EBUSY). The exclusive handoff above
worked on all three tested channels. The exact contribution of scanning versus
interface-transition state has not been isolated; direct type-change operation
is not an accepted general workflow. The separate hcxdumptool test below
passed on channel 36 with both managers stopped.

## Receive-path fix

The original software monitor saw firmware-filtered traffic. Three independent
limits were identified by source inspection, stock firmware disassembly,
readback and packet captures:

1. The PHY had no valid permanent MAC; default monitor creation failed with
   EADDRNOTAVAIL. The consolidated patch supplies a local unicast fallback without replacing
   the factory station MAC.
2. RXP address and type/subtype filters rejected non-self/control traffic.
3. DPU unknown-key/error frames went to firmware BMU queue 8, bypassing Linux.
   Opening RXP alone therefore still missed encrypted payload.

The consolidated patch uses the stock HAL dump ABI (commands 7/8) to read/write only these
five whitelisted registers, with saved originals and write-readback checks:

| Register | Monitor operation |
| --- | --- |
| RXP config `0xfb080800` | Clear bit 2; preserve RX enable and other fields. |
| Type/subtype low `0xfb0808f0` | `0xffff0000`; keep the reserved-type mask. |
| Type/subtype high `0xfb0808f4` | Zero. |
| DPU error queue `0xfb081874` | Preserve upper bits, route low byte to host RX queue 11. |
| DPU error IRQ `0xfb081820` | Mask packet-error bits 20:0; retain other interrupt bits. |

DPU packet-error filter `0xfb081878` stays unchanged. Masking the packet-error
interrupts prevents firmware competing for the redirected descriptors. Linux
marks monitor RX as monitor-only and does not falsely report ciphertext as
already decrypted or IV-stripped. Short control frames no longer cause a
sequence-field access beyond their header.

The driver checks Pronto generation, RF identity and the exact firmware
API/CRM before using this register ABI. It initializes the virtual monitor's
self context and channel, including HT40 secondary offset. Removal restores all
five registers; failed restoration retains saved state and blocks an unsafe
mode transition. Active mixed monitor/managed interfaces are rejected. Normal
managed/AP decryption handling is retained.

Vendor monitor request 302 did not reply in two 10-second trials. A legacy
PROMISC scan candidate captured management only; it remains historical research
in Git history; it is removed from the current patch tree. The final path uses
normal channel-switch requests, not either failed monitor/scan workaround.

The same patch bounds SMD TX FIFO waits: retry `rpmsg_trysend()` only on
EAGAIN with a 10-second deadline, instead of an unbounded `rpmsg_send()`. Other
transport errors and the separate response timeout are retained. Normal commands
passed; FIFO exhaustion has not been fault-injected. This does not establish
reliable WCNSS hot restart.

## Physical acceptance

All following final tests ran on the actual built-in driver in kernel #12.
Raw captures and identifiers remain private; aggregate results and SHA256s are
in [wifi-results.json](wifi-results.json). Counts exclude local TX echoes from
RX; response counts can include radio retransmissions.

| Exclusive monitor test | Requested duration | Actual RX | TX echoes | Encrypted payload / extended IV | Kernel capture drops |
| --- | --- | --- | --- | --- | --- |
| Installed helper, channel 1 | 25s | 5705 | 12 | 29 / 29, including 5 unicast | 0 |
| Channel1 | 8s | 1098 | 6 | 11 / 11, including 5 unicast | 0 |
| Channel6 | 8s | 376 | 0 | 4 / 4, all unicast | 0 |
| Channel36 | 8s | 171 | 0 | 2 / 2, multicast | 0 |

Management, ACK/CTS/RTS, BlockAck/BlockAckReq and payload Data/QoS Data were
received. No snaplen truncation was recorded. Extended-IV detection is a
structural capture check; it is not cryptographic decryption or FCS validation.
Zero tcpdump kernel drops does not prove zero loss on the air or in firmware.

In the 25s helper test, three directed probes elicited199 actual probe-response
records from the owner's AP. Three raw ToDS ARP requests from the unassociated
monitor elicited268 AP deauthentication responses (reason7: class3 from a
non-associated station), including retransmissions. These responses establish
probe and data-frame transmission beyond successful send()/local echo. The
monitor did not transmit deauthentication frames. An earlier associated test
received 21 matching ARP replies after three raw requests. These tests do not
establish every injection subtype/rate/sequence/FCS option.

After monitor removal, WPA2-PSK/CCMP AP passed an independent MT7921/Windows
client test: association/authorization, DHCP, four of four gateway pings
(1–10ms), and HTTP200 with the expected marker. An earlier open-AP test also
passed. The temporary AP/client profiles, DHCP and HTTP services were removed;
the original managed connection and factory MAC returned. Original-network
DHCP/SSH, native graphics/greetd and empty pstore were checked after boot.

## hcxdumptool acceptance, 2026-10-22

VERIFIED_DEVICE: Debian armhf `hcxdumptool` and `hcxtools` **6.3.5-1** were
installed and tested on kernel #12. NM and wpa_supplicant were stopped during
capture; hcxdumptool itself changed the existing `wlan0` to monitor mode.
A bounded wrapper saved the original MAC/profile and restored managed service
on exit. No kernel, firmware or tool-source changes were needed.

An initial two-minute default active run with `-F --rds=1` started, hopped
frequencies and stored two beacon records, but no EAPOL/PMKID. One firmware
channel-switch response returned status 6 during the all-frequency scan; the
failing frequency was not isolated. This does not establish working operation
on every advertised channel.

For a controlled acceptance, the spare independent MT7921/Windows client
connected to the owner's WPA2-CCMP test network on **channel 36 / 5180MHz**.
The tablet captured passively with:

```sh
hcxdumptool -i wlan0 -w controlled2.pcapng -c 36b --rds=1 --tot=2 \
  --attemptapmax=0 --attemptclientmax=0 --disable_beacon
```

The resulting PCAPNG contained 14 records, including **8 EAPOL messages:
M1=2, M2=2, M3=2, M4=2**. `hcxpcapngtool` identified 4 message pairs,
1 best pair and **1 authorized M2+M3 pair**. An independent structural parse
of the unchanged PCAPNG confirmed all four message counts. This establishes
actual handshake capture by the packaged software, not only process startup
or local TX echo. PMKID acquisition and handshake capture on 2.4GHz were not
established by this test. No password cracking was run.

Capture SHA256:
`de50a2331389ec1a3bf7c372a1d935faf5cbfe93039659b4f9c4e930df2bb67d`.
Raw handshakes, network identifiers and temporary client credentials stay
private. The temporary Windows profile/XML were deleted and its spare radio
returned to disconnected state. Both tool/wrapper exited 0; the original tablet
MAC/profile, managed SSH, greetd and native graphics returned. Pstore was empty;
only the known scan errors appeared in the final kernel check. Temporary
sleep inhibition was stopped. These results add no PMKID, active-monitor ACK,
arbitrary TX-option or all-channel acceptance.

## WPA2 and PMF

The earlier WPA2 AP failure was traced to AES-CMAC IGTK installation, not CCMP
or the PSK. The driver does not advertise AES-CMAC and its BSS configuration
sets `rmf = 0`. `config/wcn36xx-networkmanager.conf` defaults PMF to disabled
only for `driver:wcn36xx`; explicit profile settings take precedence. The final
AP test used profile PMF=default and picked up this board default. Existing
profiles requiring PMF must be changed explicitly if appropriate. WPA3 and
mandatory PMF are not established.

## Deployment, recovery and limits

The final consolidated-support kernel is `7.2.9-dirty #16`, SD image SHA256
`fb0948a3c72366d3bd5dea6810116fd40bdb3016270129f63ec1d0ae2e2e642b`.
Configuration, initramfs and cmdline are unchanged from #12. The only DTB
change is the standard `ieee80211-freq-limit` property excluding channel 144.
MSM module SHA256 remains
`8f6a70bd3350add8a427263706952dc0fb04820e5f88fe5a54ec596c6351fa6f`.
Only the whitelisted SD boot files are deployed; internal BOOT/lk2nd,
calibration and firmware are untouched.

The #12 rollback image, SHA256
`f0b29e7f1a8badf1c21c406ca3093a6ee763d2086508d2e9ae388074847afa57`, is retained
in `/var/lib/t531/kernel-trial-backup`. The older #10 backup is in
`kernel-trial-before-wifi-unified`; #9 remains in
`kernel-trial-before-wifi-0127`. The existing
`t531-kernel-trial-restore --rollback` procedure restores the verified backup.
Do not reuse historical edge-IRQ rearming diagnostics with the level-high DT.

Remaining limits:

- Stock firmware controls TX rates. Bad-FCS capture, FCS retention, arbitrary
  PHY/radiotap TX controls, every frame subtype and sustained-rate loss are
  not validated. This is not acceptance of every possible RFMON feature.
- This exact legacy firmware uses mac80211 software scanning directly. The
  unsupported channel-list208 command is no longer probed on each cold boot.
  Generic fallback remains for other images; legacy START_SCAN errors still
  require separate investigation when observed.
- Hot WCNSS restart/NV upload is still unreliable. A restart failed to reopen
  WCNSS_CTRL before watchdog recovery; explicit CTRL reprobe later restored
  service. Do not hot-unbind WLAN as a normal mode-switch procedure.
- The earlier USB/SSH disappearance at 07:55 UTC was preceded by
  `PM: suspend entry (s2idle)`; pstore was empty after restart. A crash was not
  established. A temporary sleep inhibitor was used for diagnostics only.

All 118 production patch files applied to a temporary index of the pinned base
with zero differences from the built kernel source. The consolidated patch passed
checkpatch without errors/warnings/checks. Kernel, matching modules and the
standalone driver build passed; shell/Python/JSON and real-capture parsing were
checked. These build checks add no hardware acceptance beyond the tests above.
`tools/build-wifi-trial.sh` now builds the patched production driver separately
without installing/binding it; it does not apply historical scan candidates.

## Consolidation and capability correction, 2026-10-22

The single production patch replaces historical patches 0013/0014, the WCNSS
part of 0015, 0031/0032 and 0123–0127. Their authorship remains in Git history;
charging stays in its own patch. This is a packaging change plus these fixes:

- Select the proven software-scan path before the exact legacy firmware's
  nonresponsive offload command. Reset software-scan state across start and
  completion so an old channel/session/vif cannot leak into a later mode.
- Keep the saved register baseline for the full monitor lifetime and reapply
  filters after successful tuning. A rejected channel no longer disables
  monitor RX or publishes a false channel; errors identify the requested channel.
- Honor standard OF frequency limits with private per-radio band/channel
  copies. Vendor NV2 explicitly lacks channel 144; a short on-device sweep
  confirmed status6 only there. The DT excludes that channel without widening
  regulatory permissions or modifying other radios' static channel templates.

The pre-limit #15 sweep accepted38 of39 channels; channel 144 was rejected.
Six-second monitor captures on 1/6/36 contained 943/395/167 records, followed by
172 records after the sweep; each reported0 kernel capture drops. An independent
WPA2 client passed DHCP, four of four pings and HTTP200 after monitor removal.
Final #16 acceptance: all 38 supported channels accepted tuning, while144
was rejected by nl80211 before a firmware command. Six-second captures on
1/6/36 contained 567/391/119 RX records;126 more were received after the sweep.
All 17 protected payload records retained an extended IV, with 0 kernel capture
drops. WPA2 AP again passed external DHCP, ping4/4 and HTTP200. hcxdumptool
captured M1/M2/M3/M4 and hcxpcapngtool identified an authorized M2+M3 pair.
An 8s raw-TX test then captured223 owner probe-response records after three
probes and 236 owner reason7 responses after three raw ToDS ARP requests
(retries included), beyond12 local TX echoes. No deauthentication was sent.
Managed DHCP/SSH, factory MAC and native graphics services returned; pstore
was empty. The final journal check contained no channel 208 timeout, channel
switch failure or legacy START_SCAN error. The #16 image is installed on SD;
#12 is retained for rollback. Exact counts/hashes are in
[wifi-results.json](wifi-results.json).
No endurance test was run. Consolidation does not implement the remaining
firmware/RF features listed above and must not be described as universal or
fully verified support for every WCN3660 function.

## Sources and evidence

The [stock firmware audit](FIRMWARE.md) confirms byte-for-byte agreement with
the tablet's apnhlos WCNSS images and system WLAN NV file, and records the
verified private backups and the remaining clean-rootfs import gap.

- **VERIFIED_UPSTREAM:** project base Linux v7.2.9,
  `5fce161649b4d779d1b76d9fcd52dc77779774b8`, wcn36xx and mac80211 sources.
  [Injection interface](https://docs.kernel.org/networking/mac80211-injection.html)
  describes radiotap TX controls; firmware support requires measurement.
- **VERIFIED_VENDOR_SOURCE:** [Samsung/Qualcomm prima HAL](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/drivers/staging/prima/riva/inc/wlan_hal_msg.h),
  revision `3fa1853ed5d6c3a8ef5a2fda9822705243bbc256`, retrieved 2026-10-20/21.
  ISC-style permissive header SHA256
  `ec316e219331373398a07d62c818be246a9826a4ea07b623510b1728e7b7720b`;
  WDI source describes monitor requests302–305. Their presence did not prove
  support in the installed image.
- **VERIFIED_DEVICE:** read-only analysis of the installed firmware identified
  dump handlers7/8 at firmware VAs `0x0d2be196`/`0x0d2be1da`, command table
  `0x0d4b0378`, RXP mask function `0x0d2aa96e` and DPU queue 8 handling.
  Live readback and captures established the five-register implementation.
  Firmware b06 SHA256
  `a57d7a162f15a9d281ec66f24c0e0f7b4f37d81e891ebd64356403bdfb9fd96e`;
  MDT SHA256 `aa09c377bfb663aafebf0b5d0bb43bfcb296fb15997a3725b25a756ba7352480`.
  Firmware binaries and experimental register tools are not committed.
- **VERIFIED_UPSTREAM:** [NetworkManager configuration reference](https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html),
  driver matching and PMF defaults. Runtime default selection was checked.

Vendor channel evidence: [vos_nvitem.c](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/drivers/staging/prima/CORE/VOSS/src/vos_nvitem.c),
pinned revision as above, retrieved 2026-10-22; NV2 lacks channel 144 and the
entry is conditional on FEATURE_WLAN_CH144. This source evidence is combined
with the actual firmware rejection, not inferred from another chipset.
