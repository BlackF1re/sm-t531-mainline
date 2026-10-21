# Native WCN3660 Bluetooth

Updated 2026-10-22. Kernel `7.2.9-t531-dirty #19` enables the standard
`btqcomsmd` driver through a WCNSS Bluetooth DT child (patch0125).
The existing stock WCNSS firmware provides the observed
`APPS_RIVA_BT_CMD` and `APPS_RIVA_BT_ACL` SMD channels. No UART attachment,
Android service, replacement firmware or persistent helper daemon is used.
BlueZ 5.82 and PipeWire Bluetooth support were already installed.

**VERIFIED_DEVICE:** the controller initializes as HCI version 6, advertises
BR/EDR and LE, and discovery receives real advertisements. The owner's
Baseus F01B 5.0 was paired, bonded and connected through BlueZ; its HID over
GATT service resolved and appeared as a normal UHID/evdev mouse. A 20-second
sample recorded 982 relative events, 2 button events and 523 input frames.
The owner confirmed working image and mouse after session recovery.

RFCOMM/TTY, BNEP/PAN, HIDP and UHID are enabled as normal kernel modules.
Audio endpoints are registered by PipeWire, but audio playback, calls/SCO,
PAN traffic, RFCOMM data, Classic pairing, Bluetooth suspend/reconnect and
endurance have not been accepted on hardware. Controller and BLE HID are
working; this is not a claim that every Bluetooth profile is verified.

## Private factory identity

The EFS backup contains the factory text address at `/bluetooth/bt_addr`.
It was validated and kept in ignored `.work/board-data/bluetooth-address`.
The separate 9-byte PERSIST `.bt_nv.bin` contains a different address; it
was not substituted for the EFS identity.

`scripts/package-sd.sh` reads `BT_ADDRESS_FILE`, defaulting to that private
file, and inserts standard little-endian `local-bd-address` into the staged
DTB. Public DTS and Git contain no device address. Packaging fails for a
missing, malformed, zero or multicast address. A clean build needs the
verified per-device EFS address file and the existing stock WCNSS firmware.
Preserve `.work/board-data/` during future cleanup. The kernel binary and
public source DTB remain free of the private address.

`-t531` isolates the new module configuration from the previous
`7.2.9-dirty` tree. The trial/rollback helper now records the saved kernel
release, so rollback metadata goes to the matching module directory.
The tested #19 image is on SD; #17 and its original modules remain intact.
Restore with `sudo /usr/local/libexec/t531-kernel-trial-restore --rollback`
and reboot. Internal BOOT/bootstrap was not changed.

## Graphics failure observed during acceptance

While the mouse was working, opening settings produced two Adreno hangchecks
naming `gnome-control-center`. Phoc then crashed with SIGSEGV in
`wlr_render_pass_add_rect`. The screen went black. Bluetooth remained
available, and the mouse had already delivered the real events above.
The graphical user session was cleanly restarted, the mouse reconnected,
and the owner confirmed that image and mouse worked. No GPU/Mesa workaround
was installed for this test. The GPU/settings failure remains unresolved;
its deeper cause was not isolated against the previous kernel.

Build checks: all 120 production patches match the source; patch0125 has
zero checkpatch findings; the WCNSS DT schema check passes. Identity byte
order and invalid-address rejection were checked with synthetic data.
