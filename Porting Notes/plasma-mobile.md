# Plasma Mobile drawer integration

* The retained quick-settings content-cache patch is shell-specific. It caches
  during dragging and the full transition, then resumes live content. It does
  not shorten animations or replace general DRM/Mesa/Qt correctness fixes.
* Original/cache/original DRM presentations35.026/51.432/34.735persecond.
  Canonical cache stack51.251afterboot, 50.732after s2idle/RPM, p95~33.4 ms.
  These are event counts, not optical distinct images or stable60FPS.
* Exact source condition differs from an old import-path prototype. The
  packaged plugin without the cache produced the earlier~35/s result; never
  compare it as though the cache and libraries were unchanged.
* Loaded shell libraries: Mesa25.0.7main series with `inorder, ttile`, scoped
  Qt6.11.2 GUI discard library and the matching plugin. KWin uses a separate
  fixed packaged Mesa. Avoid concurrent GUIs and verify actual visible gestures.
* The graphics installer stages version-locked shell libraries and plugin
  without restarting the session; loaded mappings must be verified. `tools/check-graphics-stack.py` verifies actual process mappings.
