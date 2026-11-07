# Silicon Mitus SM5502 MUIC

* Device-identified cable/accessory controller at I²C `0x25` (Android bus15).
  Native selection: `CONFIG_EXTCON_SM5502`.
* Source accessory tables include UART/jig, LAN-hub/dock and simultaneous
  power cases; their physical behavior is not accepted simply from the table.
* Charger type reporting, USB role and the board5-V supply/switch are separate
  responsibilities. Exact VBUS ownership/current capability is unresolved;
  do not invent a regulator/GPIO or derive connector voltage from extcon state.

Evidence: [Android probe data](../docs/android-hardware-observation-20261022.json), [pinned board sources](../docs/hardware-source-manifest.json). `config/kernel.fragment`.
