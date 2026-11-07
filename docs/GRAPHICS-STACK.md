# Install and verify the supported graphics stack

Exact components and hashes: [`config/graphics-stack.lock.json`](../config/graphics-stack.lock.json).
Architecture, accepted fixes and measurements: [GPU notes](../Porting%20Notes/gpu.md).

Use ARM artifacts matching the lock; install on the tablet as root:

```sh
scripts/install-graphics-stack.sh MESA_DIRECTORY QT_GUI_LIBRARY MOBILESHELL_PLUGIN
```

The installer stages root-owned immutable Qt/Mesa/plugin files, preserves the
packaged plugin via checked dpkg diversion and reloads user unit definitions.
It does not restart graphics, reboot or run suspend tests. Plan those actions
separately; preserve SSH and the verified SD recovery baseline.

After explicitly approved session activation or reboot:

```sh
python3 tools/check-graphics-stack.py
# Audit a staged manifest without replacing the installed one:
python3 tools/check-graphics-stack.py --lock /path/to/expected.lock.json
```

The read-only checker validates process mappings/hashes, KWin version/libkwin,
unified DRM, environment, module identity/resume callbacks, CD/BMS wake policy
and PowerDevil guard. It rejects logged GPU/resume faults and old enabled trial
guards; a current-boot failure must not be hidden by weakening the check.
It neither triggers suspend nor establishes optical FPS or battery life.
