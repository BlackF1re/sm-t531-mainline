# WCN3660 raw monitor / injection

* One physical WCN3660, native wcn36xx/mac80211, exact accepted firmware
  API 1.5.1.2 / CRM 12035159, Pronto v2. This path requires exclusive ownership;
  managed/AP must stop. No replacement firmware or Android HAL is involved.
* Production patch 0123 contains all monitor/filter/channel changes. Saved-state
  restoration failure must block unsafe handoff. Regulatory rules still apply.

## Raw monitor mechanism

Managed/AP and raw monitor cannot share ownership.
Firmware filters otherwise hide non-self/control/encrypted payload frames.
Exact firmware/generation/RF guards protect the HAL dump ABI7/8; save/readback/
restore only these five registers, reapply after successful channel change:

| Register | Operation |
|---|---|
| RXP `0xfb080800` | Clear bit 2, preserve RX enable/other fields |
| Type/subtype low `0xfb0808f0` | `0xffff0000`, preserve reserved type mask |
| Type/subtype high `0xfb0808f4` | 0 |
| DPU error queue `0xfb081874` | Preserve upper bits, route low byte to host queue 11 instead of firmware 8 |
| DPU error IRQ `0xfb081820` | Mask packet-error bits 20:0, retain others |

DPU filter `0xfb081878` unchanged. Preserve saved baseline for entire monitor
lifetime; restoration failure blocks unsafe transitions. Ciphertext remains
monitor-only, not falsely decrypted/IV-stripped. Guard short control headers;
initialize monitor self-context/channel/HT40 offset. A local unicast monitor
fallback does not overwrite the factory station MAC. Vendor request 302 timed
out; opening RXP alone did not recover encrypted payload; neither is a solution.

## Use and bounded acceptance

`scripts/configure-wifi.sh` installs the asynchronous systemd helper:

```sh
sudo t531-wifi-monitor start 1
sudo t531-wifi-monitor status
sudo tcpdump -i mon0 -s 0 -w capture.pcap
sudo t531-wifi-monitor stop
```

Channel 36/HT40+ is supported subject to regulatory limits. Starting monitor
stops NM and disconnects Wi-Fi SSH; use local/USB access. Saved MAC/profile are
restored on stop; invalid-channel rollback passed. No persistent monitor service.
In-place type change with managers running was unreliable/EBUSY; don't confuse
it with the accepted exclusive workflow.

**DEVICE, kernel #16:** channels 1/6/36 captured real management/control,
Data/QoS and encrypted payload/extended IV, including non-self unicast; no
reported kernel capture drops. Three probe-request and three raw ToDS ARP transmissions were recorded;
223 external probe-response and 236 deauthentication (reason 7) frames were
captured, including retries. They do not establish successful ARP delivery. No
injected deauthentication was required. WPA2 AP passed independent client's
DHCP, 4/4 pings, HTTP200; managed DHCP/SSH/factory MAC returned afterward.
hcxdumptool/hcxtools 6.3.5-1 passive channel 36 test captured M1–M4 and a usable
M2+M3 pair from the authorized lab AP/client. No password cracking; PMKID and
2.4-GHz handshake capture were not established. Raw captures stay private.

Limits: FCS retention/bad-FCS, arbitrary radiotap PHY/rate/sequence controls,
every subtype, coexistence/P2P, sustained loss, restart and endurance remain
unvalidated. Zero kernel drops is not zero over-air/firmware loss.
