# Patch review and deployment boundary, 2026-10-17

This is a bring-up snapshot, not a completed production graphics release.
The native Linux patch series is applied to the pinned v7.2.9 base and the
built source matches that complete series. Number0117 is intentionally unused:
the brightness defect is fixed in Phosh rather than by changing LED current.

Focused review of0112–0121 and Phosh0002 found no clear new deployment blocker.
This is not an exhaustive upstream review of all earlier patches.0116 retains
Dmitry Baryshkov's original authorship and v4 message metadata; it remains
unmerged in the checked mainline/linux-next sources. BMS characterization
retains Samsung's GPL-2.0-only license and copyright.

The production commit excludes local experimental Mesa, Phoc, wlroots and
Pixman patch sets and their optional build path. In particular rejected tiled
uploads, cached compositor layers and their misleading presentation-only FPS
results are not installed. Local research files may remain untracked.
Only ordinary system Mesa/Phoc and the rebuilt Phosh are selected on-device.

The kernel series still contains explicitly gated bring-up diagnostics.
Firmware bridge power, LP11/deferred-video/PHY profile7, the Mesa inorder
workaround and the device GPU runtime hold are not a finished native power
implementation. Removing these requires separate source cleanup and hardware
acceptance; this snapshot does not silently classify them as production fixes.
The bounded NULL-domain guard does not prove all domain-lifetime races fixed.
GPU recovery after an actual fault remains unverified.

The latest ordinary Phosh drawer regression before the brightness rebuild
is33.14 DRM presentations/s, with zero logged underruns; p95 is about50ms.
The earlier59.993 result belongs to a simple fullscreen client using direct
scanout, not the entire composited interface. Memory/bus rates and unresolved
OCMEM/power-state limits are recorded in MEMORY-BUS.md. No overclock is applied.

Brightness has an actual GUI/register before-and-after acceptance: maximum
37→255 after fixing false sensor claims. Battery telemetry uses real measured
OCV, coulombs, voltage/current and temperature through power_supply/UPower.
Its nominal cell model,2.4% sense-resistor uncertainty, absent learned ageing
and untested full discharge/recharge prevent a gauge-accuracy claim.

See GRAPHICS-STABILITY.md, BACKLIGHT.md and BATTERY.md for exact tests,
artifact hashes and the rollback path. Internal boot/lk2nd are unchanged.


Wi-Fi follow-up, 2026-10-21: patches 0123–0125 validate TX context/header
lengths and injection flags, describe the actual level-high DXE IRQs, and
supply a valid local PHY address when DT lacks one. They were built as #10
with unchanged configuration/MSM module, and passed managed, WPA2 AP and
3/3 directed probe-injection acceptance. See [Wi-Fi evidence](WIFI.md) for
the corrected DT packaging, firmware hot-rebind failure/recovery and exact
limits. The historical legacy-scan candidate remains outside the series;
scan-based management capture alone was not unrestricted RFMON.

Final monitor follow-up, 2026-10-21: production patch0126 bounds SMD TX FIFO
waits; patch0127 adds guarded five-register RXP/DPU routing for the exact
stock WCN3660 firmware, saved-state restoration and monitor-only ciphertext
handling. Built-in kernel #12 passed management/control and encrypted payload
capture with extended IV on channels 1/6/36, actual probe/data TX responses,
helper failure rollback, original managed reconnection and independent WPA2
AP DHCP/ping/HTTP. All 126 production patch files match the built source;
new patches pass checkpatch without errors/warnings/checks. Persistent #12
boot was checked, with #10 retained for rollback. Configuration, native-ICC
DTB and MSM module are unchanged from #10. Full monitor requires exclusive
radio ownership; bad-FCS/FCS retention, arbitrary TX controls and reliable
firmware hot restart remain unvalidated or unresolved. See [Wi-Fi](WIFI.md)
and [aggregate results](wifi-results.json) for exact acceptance.
