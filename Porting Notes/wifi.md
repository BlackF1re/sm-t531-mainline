# WCN3660 Wi-Fi

* One physical WCN3660 radio, 802.11a/b/g/n, 2.4/5 GHz; not 802.11ac.
  Native Pronto/WCNSS remoteproc + `wcn36xx/mac80211/cfg80211`; no Android HAL.
  Firmware API1.5.1.2/CRM12035159, Pronto v2, 48-MHz XO. Runtime firmware is requested under
  /lib/firmware/qcom/matisse3g/:wcnss.mdt, eight bXXsegments and the29816-byte
  board WCNSS_qcom_wlan_nv.bin. Private rootfs import is not automatic.
* Single production patch `0123-wifi-wcn3660-matisse3g-support.patch` includes
  board rails/IRQs, source/scan/transport and exclusive raw monitor/injection.
  Historical edge-IRQ rearm, PROMISC scan and mixed DT patch variants are obsolete;
  level-high IRQ and real software scanning are required for this image.
* Unsupported offload channel-list command208 is bypassed for the exact legacy
  image, not repeatedly timed out at cold boot. Clear scan state/channel/session/
  vif at start and completion. SMD TX uses `rpmsg_trysend`, retries EAGAIN up to
  10s; other errors and response timeout remain distinct. Hot WCNSS restart/NV
  reload can fail to reopen CTRL; do not hot-unbind as normal mode switching.
* PMF issue was AES-CMAC IGTK, not WPA2 CCMP/PSK: no AES-CMAC advertised,
  rmf=0. `config/wcn36xx-networkmanager.conf` disables default PMF for wcn36xx
  only; explicit profiles override it. WPA3/mandatory PMF are not accepted.
* **DEVICE/SOURCE:** NV2 lacks channel 144 (vendor conditional FEATURE_WLAN_CH144),
  firmware rejected only 144/status6 among39 candidates. OF `ieee80211-freq-limit`
  excludes it using per-radio channel copies; all 38 remaining accepted tuning.
  Do not widen regulatory rights or equate tuning with all-channel RF acceptance.

## Working scope and configuration

`scripts/configure-wifi.sh` changes installed board networking policy. Managed DHCP/SSH and factory MAC were restored after monitor trials.
Independent WPA2AP acceptance passed DHCP, 4/4gatewaypings andHTTP200. Mandatory
PMF/WPA3, P2P/concurrency, reliable hot restart and endurance remain unaccepted.

Monitor uses exclusive ownership and disconnects Wi-Fi SSH; it is not a normal
mixed managed/AP workflow. Regulatory rights and exact-image guards remain in
force regardless of test software.
