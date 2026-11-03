# OCMEM allocation restoration after RPM sleep

The Linux OCMEM driver kept the GPU's allocation in software but had no
system-resume callback to restore its firmware-backed graphics lock.
This is a demonstrated cause of broken rendering after RPM-assisted sleep
on SM-T531. It does not establish the cause of the remaining FPS deficit.

## Controlled device observations

With kernel `7.2.9-t531-pm-dirty`, packaged KWin Mesa, the original packaged
mobile-shell plugin and the production Mesa series in Plasma:

| Operation | Result |
|---|---|
| s2idle, shallow, standalone, retention, GDHS | CPU, scanout and complete pixel readback checks passed |
| RPM-assisted collapse | CPU returned successfully after 14.203 s; GMEM readback returned zero RGBA |
| Same pixel test with `FD_MESA_DEBUG=inorder,ttile,sysmem` | Passed |
| Reissue OCMEM interconnect frequency request | GMEM still failed |
| `qcom_scm_restore_sec_cfg(QCOM_SCM_OCMEM_DEV_ID, 0)` | Returned success; GMEM still failed |
| Restore secure configuration, then replay `qcom_scm_ocmem_lock()` for the existing 128-KiB graphics allocation | Returned success; all 28 complete 257×131 image checks passed without reboot |

The clock intervention was bounded and its module was unloaded. The SCM
interventions used the existing kernel API and allocation range. Private
diagnostic modules are not part of the production kernel or startup policy.
Reads of OCMEM control registers were inconclusive; the protected register
changed by firmware has not been identified. The causal result is restoration
through the graphics-lock API, not a claim about a specific MPU register bit.

## Integrated change

Patch `0148-soc-qcom-ocmem-restore-graphics-allocation-on-resume.patch`
retains a pointer to the active graphics allocation and restores security,
bank policy and the same allocated range during early system resume. The
GPU resumes later in the normal device-resume phase. Late suspend now
releases the firmware lock after GPU quiescence, balancing the next lock. Non-SCM hardware uses
the existing direct MPU programming path. Allocation addresses and sizes
come from the allocator; the fix does not hard-code this tablet's 128 KiB.

The rebuilt `7.2.9-t531-mainline-dirty` kernel booted from microSD with
MSM build ID `1337c9b68a8fcad3b3dda4619b790b4023b31826`. The first
RPM-assisted cycle passed the strict CPU, scanout, resource, process-health
and complete pixel-readback checks before and after sleep without a manual
SCM intervention. The first revision returned CPU and valid pixels in all six modes: s2idle
14.303 s, shallow 13.665 s, standalone 13.501 s, retention 13.954 s,
GDHS 14.017 s and RPM 14.222 s. Each had 28 complete image checks both
before and after sleep and no GPU/context/kernel faults in the checked
journals as initially filtered. However, the phase counters and a later
full journal inspection exposed five `failed_resume_early` events: firmware
rejected a duplicate graphics lock with `-EINVAL` when the old lock survived.
**That revision is rejected.** Pixel success alone is insufficient.

The revised patch balances late-suspend unlock and early-resume lock. The
checker now rejects increased `failed_*` phase counters and OCMEM resume
errors. A power-key trial also correctly rejected a process change caused
by an unfinished shell restart; it is not accepted as a resume qualification.
This was the intermediate status; the balanced revision was subsequently
qualified as recorded in “Accepted balanced revision” below.

## Separate unresolved work

Replacing packaged KWin Mesa with the newly built library produced a
pre-suspend GPU hang in one cold-boot run. Packaged KWin Mesa was restored;
the new library remains scoped to Plasma during qualification. Both use
the same unified GPU/KMS DRM device.

XO shutdown and VMIN counters remained zero in the measured sleep runs.
The experimental DSI PHY gating patch remains outside the production series.
No battery-life measurements were performed. Stable 60 FPS is not established.


## Accepted balanced revision

The final image SHA-256 is
`d476c3fb1032590d31285e49c468301f1ff8619abf75af1dc9af47e65d6cfe85`.
It booted from microSD; internal BOOT and lk2nd were not changed. The MSM
module matches the recorded main-series build ID above. Plasma loads the
immutable `mesa-dc3772cdf12b8a87` bundle, KWin retains packaged Mesa, and the
packaged mobileshell plugin was used for this initial seven-cycle series.
The cache plugin was subsequently restored and qualified separately; see
[the current stack](GRAPHICS-STACK.md). Diagnostic kernel patches are absent.

| Mode | Measured suspended time | Result |
|---|---:|---|
| s2idle | 14.180 s | Passed |
| shallow | 13.506 s | Passed |
| standalone | 13.686 s | Passed |
| retention | 29.364 s | Passed |
| GDHS | 28.962 s | Passed |
| RPM | 14.131 s | Passed |
| RPM via power-key input path | 28.095 s | Passed |

Every accepted cycle passed complete pixel checks before and after sleep,
scanout/resource checks, stable compositor/shell processes and journal checks.
All suspend/resume phase error counters remained zero. The button-path test
injects an input event through logind/PowerDevil; it does not independently
measure the physical key IRQ. One retention attempt with a 15-second alarm
was rejected for only 0.492 seconds of sleep after slow preparation, despite
valid rendering. The repeat used a 30-second alarm. Prematurely scheduled
initial attempts are excluded from this acceptance.

After the final cycle the user confirmed both panels visible and a working
interface. The slot was accepted and the pending marker removed. Default
policy remains s2idle; the other verified modes are available through
`t531-sleep-mode`. XO/VMIN remain zero. This qualification does not establish
fully gated whole-SoC sleep, long-term reliability, battery life or 60 FPS.


The automatic post-resume drawer workload completed with the same shell
process and no logged GPU fault or MDP5 underrun. The original packaged
plugin configuration measured 35.026 presentations/s, p95 33.424 ms. This
is not 60 FPS; prior approximately 50/s recordings used an experimental
cache plugin and do not describe that initial packaged-plugin configuration.
The current canonical cached stack subsequently measured 51.251/s after boot
and 50.732/s after s2idle/RPM sleep. See [GRAPHICS-STACK.md](GRAPHICS-STACK.md) and
`graphics-release-validation-20261103.json` for scope and measurement limits.
