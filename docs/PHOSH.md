# Optional Phosh build and session selection

Phosh is optional; the canonical tablet stack is described by the
[graphics install guide](GRAPHICS-STACK.md). Hardware/driver limitations apply
to both shells: [GPU notes](../Porting%20Notes/gpu.md),
[brightness](../Porting%20Notes/backlight.md).

* `scripts/build-phosh.sh` rebuilds pinned Phosh0.58.0/Debian0.58.0-1 packaging
  in an isolated armhf rootfs. `patches/phosh` provides legacy GNOME shortcut
  fallback and the absent-light-sensor correction; target t5313.
* `tools/fetch-phosh-runtime.py` and `config/phosh-runtime.lock.json` pin/check
  the runtime package set. `scripts/install-phosh.sh` uses no-removal apt
  deployment; inspect package compatibility and preserve rollback artifacts.
* `scripts/select-mobile-shell.sh` controls installed session selection;
  read its usage before changing a live session. Session setup/configuration:
  `scripts/install-phosh.sh`, `scripts/phosh-session.sh`, `config/t531-phosh*`.
* Build output is outside Git, beneath the shared host workspace. See
  [build prerequisites and paths](BUILD-DEPLOY.md). Installing packages alone
  does not reproduce private firmware, network identities or accepted graphics.

Historical acceptance used Phosh0.58.0-1~t5313/Phoc0.46; this is not a claim
that these versions are currently the latest. Recheck exact package/runtime
identities before relying on a previous benchmark. General profile tools:
`scripts/profile-drawer.sh`, `tools/auto-drawer.py`; confirm a visible unlocked
animation and avoid concurrent GUI workloads.
