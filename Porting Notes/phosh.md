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

* **DEVICE, historical Phosh/Phoc trial:** GTK before/after-paint timing found
  50/191 CPU frames above16.7ms, CPU p95~32.3–32.5ms, while DRM presented~50.96/s.
  Presentation counts therefore overstate distinct GTK content updates; that
  CPU preparation cannot be fixed solely by adding GPU planes.
* A private NEON Pixman IN_REVERSE comparison reduced GTK CPU p95 from30.657
  to28.662ms, DRM48.721→50.285/s (separate sessions, not same-process ABA).
  Solid fast paths passed16,697,344 exact pixels on host/device but gave
  49.634 vs49.667/s; no aggregate FPS gain. Neither is a general60FPS fix.
* Private output-layer/primary-reuse prototypes reached~50.065/s, not60.
  Grouped DSI signatures matched texture composition, but direct single-plane
  fractional alpha differed. Those prototypes lack physical panel acceptance
  and are not the production compositor.

Evidence: `patches/phosh`, [runtime package lock](../config/phosh-runtime.lock.json),
`scripts/build-phosh.sh`, `scripts/install-phosh.sh`, `scripts/select-mobile-shell.sh`.
