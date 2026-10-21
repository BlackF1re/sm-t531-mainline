# WCN3660 managed, AP and raw monitor

Updated 2026-10-22. **VERIFIED_DEVICE:** the SM-T531 built-in WCN3660 now
receives management, control and payload Data/QoS Data in standalone monitor
mode, including non-self unicast and encrypted payload with its extended IV.
Directed probe and raw data injection elicited actual over-air responses.
Managed networking and WPA2 AP were tested again after monitor operation.
This is native wcn36xx/mac80211 support with the original firmware, not an
Android userspace dependency or a replacement firmware image.

Kernel `7.2.9-dirty #12` contains production patches 0123–0127. The tested
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
   EADDRNOTAVAIL. Patch0125 supplies a local unicast fallback without replacing
   the factory station MAC.
2. RXP address and type/subtype filters rejected non-self/control traffic.
3. DPU unknown-key/error frames went to firmware BMU queue 8, bypassing Linux.
   Opening RXP alone therefore still missed encrypted payload.

Patch0127 uses the stock HAL dump ABI (commands 7/8) to read/write only these
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
under `patches/candidates/wifi/`, excluded from production. The final path uses
normal channel-switch requests, not either failed monitor/scan workaround.

Patch0126 separately bounds SMD TX FIFO waits: retry `rpmsg_trysend()` only on
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
received21 matching ARP replies after three raw requests. These tests do not
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

The final #12 SD image SHA256 is
`f0b29e7f1a8badf1c21c406ca3093a6ee763d2086508d2e9ae388074847afa57`.
Configuration, native-ICC DTB, initramfs and cmdline are unchanged from #10.
The MSM module is unchanged, SHA256
`8f6a70bd3350add8a427263706952dc0fb04820e5f88fe5a54ec596c6351fa6f`.
Only the whitelisted T531_BOOT SD kernel image/checksum were replaced after a
one-boot trial. Internal BOOT/lk2nd, calibration and firmware were untouched.

The verified #10 backup is `/var/lib/t531/kernel-trial-backup`, image SHA256
`6602817e4293e3c9ecf06de9c05545f8ad265dace1255dac46b44a51e2a40ea1`.
The existing `t531-kernel-trial-restore --rollback` procedure restores it to
SD. The older #9 backup remains in `kernel-trial-before-wifi-0127`; #8 is in
`kernel-trial-before-wifi-0125`. USB recovery and the internal bootstrap remain
available. WLAN IRQ patch0124 describes level-high triggers already used by
the driver; historical edge-rearming diagnostics must not be reused with it.

Remaining limits:

- Stock firmware controls TX rates. Bad-FCS capture, FCS retention, arbitrary
  PHY/radiotap TX controls, every frame subtype and sustained-rate loss are
  not validated. This is not acceptance of every possible RFMON feature.
- Firmware channel-list request208 still times out; scan failures and the
  software-scan fallback remain.
- Hot WCNSS restart/NV upload is still unreliable. A restart failed to reopen
  WCNSS_CTRL before watchdog recovery; explicit CTRL reprobe later restored
  service. Do not hot-unbind WLAN as a normal mode-switch procedure.
- The earlier USB/SSH disappearance at 07:55 UTC was preceded by
  `PM: suspend entry (s2idle)`; pstore was empty after restart. A crash was not
  established. A temporary sleep inhibitor was used for diagnostics only.

All 126 production patch files applied to a temporary index of the pinned base
with zero differences from the built kernel source. Both new patches passed
checkpatch without errors/warnings/checks. Kernel, matching modules and the
standalone driver build passed; shell/Python/JSON and real-capture parsing were
checked. These build checks add no hardware acceptance beyond the tests above.
`tools/build-wifi-trial.sh` now builds the patched production driver separately
without installing/binding it; it does not apply historical scan candidates.

## Sources and evidence

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
