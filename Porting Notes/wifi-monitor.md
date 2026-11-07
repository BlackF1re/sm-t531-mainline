# WCN3660 raw monitor / injection

* One physical WCN3660, native wcn36xx/mac80211, exact accepted firmware
  API1.5.1.2/CRM12035159,Pronto v2. This path requires exclusive ownership;
  managed/AP must stop. No replacement firmware or Android HAL is involved.
* Production0123 contains all monitor/filter/channel changes. Saved-state
  restoration failure must block unsafe handoff. Regulatory rules still apply.

## Raw monitor mechanism

Monitor must have exclusive ownership; no unrestricted managed/AP+monitor.
Firmware filters otherwise hide non-self/control/encrypted payload frames.
Exact firmware/generation/RF guards protect the HAL dump ABI7/8; save/readback/
restore only these five registers, reapply after successful channel change:

| Register | Operation |
|---|---|
| RXP `0xfb080800` | Clear bit2, preserve RX enable/other fields |
| Type/subtype low `0xfb0808f0` | `0xffff0000`, preserve reserved type mask |
| Type/subtype high `0xfb0808f4` | 0 |
| DPU error queue `0xfb081874` | Preserve upper bits, route low byte to host queue11 instead of firmware8 |
| DPU error IRQ `0xfb081820` | Mask packet-error bits20:0, retain others |

DPU filter `0xfb081878` unchanged. Preserve saved baseline for entire monitor
lifetime; restoration failure blocks unsafe transitions. Ciphertext remains
monitor-only, not falsely decrypted/IV-stripped. Guard short control headers;
initialize monitor self-context/channel/HT40 offset. A local unicast monitor
fallback does not overwrite the factory station MAC. Vendor request302 timed
out; opening RXP alone did not recover encrypted payload; neither is a solution.

## Use and bounded acceptance

`scripts/configure-wifi.sh` installs the asynchronous systemd helper:

```sh
sudo t531-wifi-monitor start 1
sudo t531-wifi-monitor status
sudo tcpdump -i mon0 -s 0 -w capture.pcap
sudo t531-wifi-monitor stop
```

Channel36/HT40+ is supported subject to regulatory limits. Starting monitor
stops NM and disconnects Wi-Fi SSH; use local/USB access. Saved MAC/profile are
restored on stop; invalid-channel rollback passed. No persistent monitor service.
In-place type change with managers running was unreliable/EBUSY; don't confuse
it with the accepted exclusive workflow.

**DEVICE, kernel #16:** channels1/6/36 captured real management/control,
Data/QoS and encrypted payload/extended IV, including non-self unicast; no
reported kernel capture drops. Three probe/raw ToDS ARP transmissions elicited
223/236 external responses (retries included), beyond local TX echoes. No
injected deauthentication was required. WPA2 AP passed independent client's
DHCP,4/4 pings,HTTP200; managed DHCP/SSH/factory MAC returned afterward.
hcxdumptool/hcxtools6.3.5-1 passive channel36 test captured M1–M4 and a usable
M2+M3 pair from the authorized lab AP/client. No password cracking; PMKID and
2.4-GHz handshake capture were not established. Raw captures stay private.

Limits: FCS retention/bad-FCS, arbitrary radiotap PHY/rate/sequence controls,
every subtype, coexistence/P2P, sustained loss, restart and endurance remain
unvalidated. Zero kernel drops is not zero over-air/firmware loss.

Sources: `tools/wifi`,
`scripts/wifi-monitor.sh`, production0123.
Firmware b06 SHA256 `a57d7a162f15a9d281ec66f24c0e0f7b4f37d81e891ebd64356403bdfb9fd96e`;
MDT `aa09c377bfb663aafebf0b5d0bb43bfcb296fb15997a3725b25a756ba7352480`.
