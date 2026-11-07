# WCN3660 Bluetooth

* Shared WCNSS firmware and WCN3660, Bluetooth4.0 BR/EDR+LE; native `btqcomsmd`
  DT child via0125. SMD services `APPS_RIVA_BT_CMD`/`APPS_RIVA_BT_ACL` were
  observed. No UART attach, Android service, alternate blob or helper daemon.
* `config/kernel.fragment`: BT_QCOMSMD, RFCOMM/TTY, BNEP/PAN, HIDP, UHID modules.
  BlueZ5.82/PipeWire were present in acceptance; service registration does not
  validate audio/SCO. Driver send callback supports CMD/ACL, not proven SCO.
* **DEVICE, kernel #19:** HCI version6, advertisements/discovery; Baseus
  F01B5.0 paired/bonded/connected, HoG resolved into UHID/evdev.20-s capture:
  982relative events,2buttons,523input frames; owner confirmed real mouse use.
* Classic pairing, A2DP/AVRCP playback, HFP/HSP/SCO, RFCOMM/PAN traffic,
  sleep/reconnect/coexistence and endurance have not passed acceptance.
* Factory text address is EFS `/bluetooth/bt_addr`; PERSIST's9-byte `.bt_nv.bin`
  contains a different address and was not substituted. Public DTS contains
  no factory identity. `scripts/package-sd.sh`/`tools/set-bluetooth-address.py`
  validate the private file and inject little-endian `local-bd-address` into
  staged DTB. Default `../private/FIRMWARE/board-data/bluetooth-address`,0600;
  override `BT_ADDRESS_FILE`. Missing/zero/multicast/malformed values fail.
* During mouse acceptance, settings caused Adreno hangchecks and Phoc SIGSEGV
  in `wlr_render_pass_add_rect`; BT/input persisted. Session restart restored
  image/mouse. That incident does not establish a Bluetooth transport failure.

Sources: [0125](../patches/linux/0125-arm-dts-qcom-matisse3g-enable-bluetooth.patch),
[board source pins](../docs/hardware-source-manifest.json). No per-device address is public.
