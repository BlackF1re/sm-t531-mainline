# Plasma Mobile drawer integration

* The retained quick-settings content-cache patch is shell-specific. It caches
  during dragging and the full transition, then resumes live content. It does
  not shorten animations or replace general DRM/Mesa/Qt correctness fixes.
* Original/cache/original DRM presentations35.026/51.432/34.735persecond.
  Canonical cache stack51.251afterboot,50.732after s2idle/RPM,p95~33.4ms.
  These are event counts, not optical distinct images or stable60FPS.
* Exact source condition differs from an old import-path prototype. The
  packaged plugin without the cache produced the earlier~35/s result; never
  compare it as though the cache and libraries were unchanged.
* Loaded shell libraries: Mesa25.0.7main series with `inorder,ttile`, scoped
  Qt6.11.2 GUI discard library and the matching plugin. KWin uses a separate
  fixed packaged Mesa. Avoid concurrent GUIs and verify actual visible gestures.
* `scripts/install-graphics-stack.sh MESA_DIRECTORY QT_GUI_LIBRARY MOBILESHELL_PLUGIN`
  stages immutable files/diverts the packaged plugin; it does not restart the
  session. `tools/check-graphics-stack.py` verifies actual process mappings.

Evidence: `patches/plasma-mobile/0001-cache-quick-settings-during-drawer-motion.patch`,
[release timings](../docs/graphics-release-validation-20261103.json),
[stack audit](../docs/graphics-stack-audit-20261103.json).
