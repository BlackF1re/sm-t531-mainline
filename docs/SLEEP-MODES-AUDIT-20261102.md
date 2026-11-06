# SM-T531 sleep-mode audit, 2026-11-02

The installed kernel is 7.2.9-t531-unified2-dirty. This audit separates
advertised states, implemented entry paths and successful device transitions.
A sysfs state name does not establish whole-SoC power savings.

## Stock reference and current implementation

The actual captured Android runtime DT and the pinned Samsung/Qualcomm source
agree on the CPU/system mode tables. Their presence establishes board
configuration, not measured stock residency in every mode.

| Layer / mode | Stock board configuration | Current Linux |
|---|---|---|
| CPU WFI | CPU mode 0; wake latency 1 us | Enabled on all four cores; usage counters increase |
| CPU standalone power collapse (SPC) | CPU mode 1; 500 us | Enabled on all four cores; 2 ms minimum residency |
| CPU power collapse coordinated with system (PC) | CPU mode 2; 550 us | No corresponding coordinated CPUidle state |
| L2 retention | Separate SAW retention sequence | Platform standby path only; no coordinated cluster idle governor |
| L2 GDHS | System mode 0; 700 us | No MSM8226 GDHS entry path in this driver |
| L2/APCS collapse without RPM | System mode 1; 1000 us | Implemented as platform `deep`, not as coupled CPUidle |
| RPM-assisted L2/APCS collapse | System mode 2; 12700 us, send-rpm-sleep-set | Not integrated in the installed profile |
| XO shutdown (`xosd`) | RPM firmware statistics interface | Count and accumulated duration both zero before and after all three modes |
| Voltage-minimum sleep (`vmin`) | RPM firmware statistics interface | Count and accumulated duration both zero before and after all three modes |
| DDR self-refresh / sleep bus votes | Whole-system coordination is required | No measured proof of DDR self-refresh or low sleep clocks |

Wake latencies are DT policy values, not measured latencies. XO/vmin are
firmware sleep outcomes, not extra names to append to the CPUidle table.

The stock reference is
[msm8226-v2-pm.dtsi](https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/boot/dts/msm8226/msm8226-v2-pm.dtsi),
checked online as well as against the captured runtime DT. Local source
provenance is recorded in [the hardware source manifest](../hardware/sources.json).

## System sleep selection

`/sys/power/state` advertises `freeze standby mem`; `/sys/power/mem_sleep`
advertises `[s2idle] shallow deep`. The installed systemd policy selects s2idle.
Hibernation is not compiled and no disk sleep interface exists. Hibernation
is not required for smartphone standby that preserves RAM and receives events.

The SPM driver uses L2 retention plus CPU0 WFI for standby; nonboot CPUs are
offlined by the suspend core. Its `deep` path flushes caches and requests CPU0
and L2 collapse through SCM, then restores the APC voltage before secondary
CPU and CPUFreq resume. It uses the no-RPM SAW byte sequence and does not
notify MPM/RPM of a coordinated system sleep. CONFIG_QCOM_MPM is disabled.
The existing RPM SMD clock/regulator/domain resource votes must not be confused
with an accepted system-sleep handshake.

Earlier rejected RPM/MPM experimental patches are retained privately. Their
logs show an attempt reaching L2 collapse and returning, followed by a stall
or reset during recovery. They are research, not an accepted implementation,
and were not restored during this audit.

## Smartphone standby gaps

The running Wi-Fi driver advertises WoWLAN-any, magic-packet and GTK rekey
support. Wi-Fi power saving is on, but WoWLAN is disabled. Existing system
sleep traces show deauthentication and reconnection on resume. Continuous
network reachability and network-triggered wake are therefore not accepted.
The driver already has ARP/IPv6/GTK offload and host-suspend functions; enabling
an advertised switch alone does not establish end-to-end notification wake.

Only the WCNSS remote processor is present as a running remoteproc in the
observed system. Modem/ADSP operation and call/SMS wake are not demonstrated;
DT status=okay is not a running cellular service. These are separate from
local power-button/RTC wake, which is already exercised.

Native display configuration retains firmware power during bring-up. The
TC358764 driver has a diagnostic firmware_power path which skips regulator
disable, and the native DT retains an always-on display rail. Actual complete
panel/bridge supply shutdown needs separate confirmation and ownership of the
supply sequence. An off backlight alone is insufficient evidence. Display SMP allocation errors also occur after wake; successful kernel resume does not constitute complete display power/stability acceptance.

Runtime PM already reports the GPU and its IOMMU suspended and the GPU power
domain off in a quiet awake snapshot. This is useful but does not establish
low whole-board sleep current. The CPU memory rail has an awake 1.28 V vote;
its sleep behavior must be measured rather than inferred from this snapshot.

## Energy acceptance

The device is currently charging from external power. Its battery current
reading therefore measures net battery charging, not the tablet's load.
No discharge-current or days-of-standby claim is made. Independent current
measurement and longer unplugged tests are still necessary; the 6800 mAh
design value does not describe the aged battery's usable capacity.

Required order for useful autonomy: reliable deep entry/resume; correct
APSS/RPM/MPM handshake and wake replay; actual sleep rail/clock and DDR
residency; panel/bridge shutdown; network offload and event wake; then long
unplugged current and wake-latency measurements. Each layer needs evidence
before enabling a deeper default. Adding every stock mode is not itself an
energy optimization.

## Device test results

The bounded transient systemd override completed all three modes:

| Mode | Actual suspended time | Kernel outcome |
|---|---:|---|
| shallow | 11.785 s | success +1; fail unchanged |
| deep | 13.798 s | success +1; fail unchanged |
| s2idle | 63.848 s | success +1; fail unchanged |

After each return the helper observes another 15 seconds without a further
suspend. Kernel counters go from success=6/fail=1 to success=9/fail=1; the older
failure is retained. The kernel log verifies all three requested mode names.
Deep explicitly reports standalone L2 collapse returned 0 and APC voltage
restore 0. This is one successful standalone deep cycle, not endurance or
RPM-assisted system-sleep acceptance.

Both RPM xosd and vmin counts and accumulated durations remain zero after
every mode. A final read-only mmap of the stock APSS master-stats SRAM window
finds num_shutdowns=0, shutdown_req=0 and bringup_ack=0. The first snapshot
method using pread returned EFAULT; no before/after master-stats delta is
claimed. The successful bounded mmap is included in tools/audit-sleep-states.py.
The raw active_cores value is firmware bookkeeping, not Linux's current
online-CPU count. CPUidle also records rejected SPC attempts; usage counters
are not assumed to mean every requested entry achieved power collapse.

SSH was unavailable longer than expected during the series. A provisional
suspicion of deep recovery failure was disproved by the stored completed
results. The owner confirmed the desktop was already visible. RTC sleep and
network recovery timing must be distinguished; those SSH timeouts are not
kernel suspend failures, but network readiness latency remains unaccepted.

The transient override was removed, s2idle restored, RTC wakealarm is empty,
and no sleep test remains running. Unified DRM probe passes, screen is on;
the user session remains available. The active state of GPU runtime PM and
all post-resume rail snapshots describe the awake system, not an in-suspend
power measurement. No permanent kernel/default sleep-policy change was made
by this audit.

Machine-readable results: [sleep-modes-results-20261102.json](sleep-modes-results-20261102.json).
This audit confirms partial low-power support and identifies missing integration;
it does not claim stock-equivalent standby or a measured autonomy improvement.
