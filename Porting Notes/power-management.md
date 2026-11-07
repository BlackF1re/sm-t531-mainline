# System sleep, RPM/MPM and wake sources

Current default remains **s2idle**; six CPU/L2 modes passed bounded functional
checks on mainline, not whole-board energy/endurance acceptance.

| Selection | Implementation |
|---|---|
| s2idle/freeze | Freeze userspace/devices, per-core WFI/SPC |
| shallow/standby | Secondary CPUs offline; CPU0 WFI, L2 retention |
| deep + retention | CPU collapse, L2 retained |
| deep + GDHS | L2 gated-head-switch sequence and SCM flag |
| deep + standalone | CPU/L2 collapse without RPM handshake |
| deep + rpm | MPM wake routing/deadline, SAW/RPM coordinated collapse |

`/sys/power/state`: freeze/standby/mem; mem follows `/sys/power/mem_sleep`.
Hibernation is disabled. Source L2 mode wake latencies700/1000/12700 µs are
policy values, not measured physical latencies; coordinated cluster cpuidle
is still absent. Ordinary awake cpuidle remains per-core WFI/SPC.

## Required ordering and fixes

* 0133–0134: MPM preparation after nonboot CPU shutdown; SAW sequence starts
  retention0/GDHS4/standalone26/RPM54. No manual genpd refcount adjustments.
* 0137: report actual chained TLMM IRQ affinity to avoid false independent
  GPIO migration during CPU hotplug. 0144 marks legacy RPM-return IRQ wake
  like downstream. RPM SMD clock/regulator votes alone are not sleep handshake.
* Active-only memory votes0138, bootstrap clock sleep-set fix0139, MMSS gating
 0142; MDP gating/resource restore0136/0140, USB controller/PHY late/early0141.
* OCMEM0148 releases the existing graphics lock after late GPU suspend and
  restores security/banks/the same allocation before GPU resume. Clock re-voting
  alone left zero pixels after RPM; lock restoration fixed readback. CPU return
  with zero pixels or increased failed_* phase counters is a failure.
* Excluded experiment0143 fully unprepared DSI PHY interface clock: s2idle/
  retention returned but RPM did not. Ordinary disable retains parent prepare
  and its XO request. Do not reintroduce it as a completed power optimization.
  Diagnostic0145–0147 are not in main; historical source is Git`43648a2`.
* Production cmdline removes `clk_ignore_unused`; CPU critical clock remains
  `CLK_IS_CRITICAL`. TC358764/LCD enables use vendor order, L5 still retained.

## Preserved Android reference

Dirty Unicorns6.0.1 is not factory firmware. Its L2 maximum mode was4,
CPU0 coordinated-collapse idle enabled, CPU1–3 disabled; standalone idle
was enabled and retention idle disabled. Direct unplugged screen-off suspend
returned after~8.137s using MPM timer8s with RTC backup45s; XO/VMIN counters
still0. Connected suspend returned−EBUSY from USB. This does not establish
normal framework autosuspend or low power. The41 GPIO↔MPM pairs matched the
runtime Android DT; GIC SPI mappings subtract32, and vendor255 bypass entries
are not physical MPM pins.

## Reproduced independent aborts

* GPIO38 SD CD IRQ78 exceeded3million interrupts, mmc1 generated hundreds of
  thousands of wake events. Suspend aborted in filesystem sync with `-EBUSY`;
  it was not necessarily a completed sleep followed by wake. 0130 removes
  `cd-gpios`, uses `broken-cd` polling, retains data/power IRQs/removability.
  CD wake count became0; 16-MiB write/fsync/readback passed (~2.608s).
* A3xx deferred CP init can leave hardwareRPTR0/softwareWPTR528 on the next
  suspend:0131reconciles validated cursors only when needs_hw_init. A separate
  BMS30s poll activated a wake source;0132makes polling non-waking and suppresses
  unchanged notifications. Neither is evidence of an unsolicited physical wake.
* Wait for complete `PrepareForSleep(true/false)` before moving phases or
  clearing RTC alarms. An RTC return can leave DPMS off; the next Power event
  may wake only the display. Discover `pm8941_pwrkey` by name, not event number.

## Configuration and acceptance

`scripts/sleep-mode.sh`, `scripts/configure-sleep.sh`; installed command:

```sh
t531-sleep-mode status
sudo t531-sleep-mode s2idle
# Expert selections: shallow, retention, gdhs, standalone, rpm.
```

This changes policy for the next ordinary logind/systemd suspend, not immediate
sleep or measured battery life. Do not run an extra background suspend loop.
Network standby policy enables Wi-Fi power-save/WoWLAN ANY; advertised support
is not accepted notification wake/continuous connectivity or call/SMS wake.

**DEVICE, balanced OCMEM:** accepted suspended times s2idle14.180s,
shallow13.506, standalone13.686, retention29.364, GDHS28.962, RPM14.131,
RPM/key-path28.095. Complete pixels/scanout/resources, stable process IDs,
journals and all phase counters passed. Owner accepted both panels afterward.
Key injection through logind does not independently test physical key IRQ.
One 0.492-s retention attempt was excluded; use a sufficiently delayed alarm.
XO/VMIN counters remained0; DDR self-refresh, low sleep current and long-term
reliability are unverified. USB connection previously impeded sleep; don't
conflate local clock-gating success with low whole-board power.

Tools: `tools/audit-sleep-states.py`, `tools/check-suspend-cycle.py`.
