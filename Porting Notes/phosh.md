# Phosh / Phoc toolkit compatibility

* Historical acceptance used Phosh0.58.0-1~t5313/Phoc0.46 with native MSM GPU/KMS.
  The canonical tablet graphics session later changed to Plasma Mobile; do not
  treat the old Phosh benchmark as the current shell/library configuration.
* t5311 SIGTRAP came from unconditionally reading GNOME49 brightness-shortcut
  keys on GNOME48. The retained0001patch checks schema/key availability and
  falls back to legacy keybindings; this is not a GPU crash or renderer fix.
* t5313 also contains the absent-light-sensor state fix. Runtime dependency
  versions/hashes are pinned in config/phosh-runtime.lock.json; installer uses
  a coherent no-removal package update rather than missing-schema workarounds.
* `scripts/build-phosh.sh` builds the pinned source/package set in an isolated
  armhf rootfs. `scripts/install-phosh.sh` deploys it; session selection takes
  explicit phosh|plasma and terminates local graphical sessions, not SSH.

Evidence: `patches/phosh`, [runtime package lock](../config/phosh-runtime.lock.json),
`scripts/build-phosh.sh`, `scripts/install-phosh.sh`, `scripts/select-mobile-shell.sh`.
