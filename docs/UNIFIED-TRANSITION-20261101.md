# Unified deployment attempt, 2026-11-01

Incomplete: production selection and unified runtime have not been verified.

Initial live state: Linux `7.2.9-t531-dirty`, separate Adreno card0 and
MDP card1, `/etc/modprobe.d/msm.conf` with `separate_gpu_kms=1`.
The repository already requires unified DRM; the device had reverted to its
older baseline.

The existing controller successfully prepared the retained, previously tested
`7.2.9-t531-unified2-dirty` trial from
`/var/lib/t531/unified2-candidate/.work/artifacts/unified2-trial`, using verified
baseline `/var/lib/t531/graphics-baselines/20261028T144702Z`.
Before reboot, the repository's unified `config/msm.conf` and activation script
were installed. Configuration backup and staging are retained under
`/var/lib/t531/unified-transition-20261101/`.

Reboot was requested successfully. Subsequent connections to 192.168.2.157
received connection refused on port 22 while ICMP replies continued. No USB ACM
console is exposed to this environment. The running kernel after reboot is
unknown. No production promotion, session confirmation, or performance claim
was made. The pending guard and golden recovery slot remain intact.

After recovering remote access, inspect the running release and guard state
before changing anything. Complete unified user/session configuration, validate
`/usr/local/libexec/t531-drm-probe --require-unified`, then promote the retained
unified2-production directory and verify its boot before confirming it. Do not
remove recovery artifacts to enforce topology; remove split settings from the
normal boot and session instead.

## Remote access recovered

SSH subsequently became available. Unified2 was running successfully in its
intentional SSH-only trial (`t531.native_kms=0`), with no failed system units.
The activation script loaded unified MSM successfully; the capability probe
reported card0/renderD128, GPU 305, atomic 1280×800 at 59.999 Hz, unified=true.
The split-device KWin overrides were archived under the transition backup and
replaced with repository configuration. KWin started. Session confirmation
succeeded and the controller staged/selected unified2-production. Production
boot confirmation is still pending at this point.

## Production runtime accepted

The production command line (`t531.native_kms=1`, no trial flag) and unified2
release were observed after reboot. Initial automatic graphics startup failed
because the SSH listener check raced service readiness. The activation script
now waits up to 45 seconds for the listener; shell syntax validation passed.
After installing it, restarting native graphics succeeded and the unified probe
passed. `confirm-boot` selected production persistently and cleared pending.
This does not establish unattended boot reliability: the readiness fix has not
yet been exercised through another reboot.

A premature manual shell start failed without a display. Once the Wayland
session environment was ready, restarting the shell produced a live
plasmashell PID 1053 with both native graphics and SDDM active. An obsolete
scene-observer preload drop-in referencing an inaccessible diagnostic library
was archived in the transition backup. Physical panel acceptance remains with
the owner. No 60-FPS result is claimed.

## Automatic startup and presentation check

A subsequent requested reboot verified the listener-wait fix without manually
starting graphics or the shell. Kernel: unified2; native graphics became active
at 30.485 s of kernel monotonic time, SDDM started at 30.496 s and its session
started at 36.185 s. Plasma was active with zero service restarts after both
measurements; no system units were failed. This is one reboot check, not a
cold-power-cycle or endurance acceptance. GPU runtime remains held on by the
pre-existing `40-gpu-runtime-diagnostic.conf`; runtime PM is not validated here.

The retained auto-drawer/profile-drawer tools performed two successful 22-second
recordings, ten gesture cycles each. The initially attempted recording failed
because the installed profiler lacked execute permission; its gestures still
ran. Consequently both successful runs are warmed measurements, not a genuine
cold first-use comparison. Invoking the profiler with bash resolved the tooling
issue. No animation settings or operating clock constraints were changed.

Presentation rates: 50.239 and 50.610/s. Second-run p50/p95/p99 intervals:
16.674 / 33.354 / 33.441 ms; 17.470% of intervals above 25 ms. No logged display
underruns or detected GPU/kernel faults during the recordings. Burst filtering
excludes gaps above 100 ms; this is DRM presentation evidence, not optical FPS.
The second run includes ten presentation bursts; the first includes nine.
60 FPS is not achieved. Results are in `graphics-startup-fps-20261101.json`;
raw traces remain at `/var/tmp/t531-fps-20261101-093541/` on the tablet.
