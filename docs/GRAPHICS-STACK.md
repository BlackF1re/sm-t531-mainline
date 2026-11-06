# Single production graphics stack

`main` is the sole project branch, locally and on GitHub. There are no
`patches/candidates` in the current tree. Historical experiments are retained
only in Git history (snapshot `43648a2`), not as supported build variants.
The immutable rescue/bootstrap and golden SD slot are recovery assets.
The main kernel profile defaults to `LOCALVERSION=-mainline`, matching the
qualified release instead of reusing the legacy golden kernel release name.

The supported component identity is recorded in
[`config/graphics-stack.lock.json`](../config/graphics-stack.lock.json).

| Component | Qualified configuration |
|---|---|
| Kernel | Main Linux patch series, unified Adreno/MDP5 DRM; balanced OCMEM restore |
| KWin | Custom 6.7.4-2+t531overlay1 with the retained single-overlay patch; packaged Mesa 25.0.7-2+deb13u1, `inorder` |
| Plasma | Main Mesa patches 0001/0002/0009/0010/0011/0012, `inorder,ttile` |
| Qt GUI | Qt 6.11.2 with the main transient depth/stencil discard patch |
| Mobileshell | Plasma Mobile 6.7.4-2 with the main quick-settings cache patch |
| PowerDevil | Packaged 6.7.4-2; the loaded action already includes the suspend transition guard |

Different Mesa libraries for KWin and Plasma are one fixed, qualified stack;
both use the same unified DRM device. The replacement KWin Mesa variant is
excluded because it previously hung. No precision/scissor/tile experiment,
full DSI PHY unprepare or early-resume tracing patch is selected.

## Restored performance fix

The cleanup replaced the cache plugin with the packaged original. On the same
kernel/Mesa/Qt and clock policy, original / cache / original measured
35.026 / 51.432 / 34.735 DRM presentation events per second. A fresh boot with
the canonical cached stack measured 51.251/s (p95 33.386 ms).
After s2idle and RPM sleep it measured 50.732/s; both sleep
checks passed complete pixel readback and all phase error counters stayed zero.

The cache holds quick-settings content during dragging and the complete drawer
transition, then resumes live rendering. It does not shorten animations. The
recovered ActionDrawer and QuickSettingsPanel source resources match the
qualified binary byte for byte. An older import-path prototype used another
condition and is excluded. The Qt patch was still marked as a candidate even
though its exact stripped binary was active; its source is now in `patches/qt`.

Repeated live session restarts produced one GPU hang and that trial was
rejected. Fresh-boot qualification is recorded separately. This is a restored
performance optimization, not a claim of stable 60 FPS or flawless recovery.
Presentation counts are not optical FPS; intervals above 100 ms are omitted
by the burst summary and could include severe stalls.

## Installation and verification

Use the already qualified ARM artifacts; package versions and hashes must
match the lock. Run on the tablet as root:

```sh
scripts/install-graphics-stack.sh MESA_DIRECTORY QT_GUI_LIBRARY MOBILESHELL_PLUGIN
```

The installer stages root-owned immutable Qt/Mesa/plugin files, preserves the
original packaged plugin through a checked dpkg diversion, and reloads user
unit definitions. It does not restart the session or run suspend tests.
Restart Plasma or reboot to load the installed stack, then run:

```sh
python3 tools/check-graphics-stack.py
```

This read-only check verifies actual process mappings, file hashes, unified
DRM, environment flags, kernel module identity, resume callbacks, card-detect
polling, BMS wake policy and the loaded PowerDevil guard. It also rejects
logged kernel GPU/resume faults and enabled legacy trial boot guards.
It reads no battery-life telemetry and does not trigger suspend.

See [`graphics-stack-audit-20261103.json`](graphics-stack-audit-20261103.json)
for preserved fixes, excluded trials and post-consolidation qualification.

The 2026-11-06 [worktree audit](WORKTREE-AUDIT-20261106.md) recovered the
active KWin patch from private build packaging. Its presence is verified, but
an isolated FPS benefit has not been established. The lock and read-only check
now also cover the KWin package version and the mapped libkwin binary.
