# Qt OpenGL swapchain depth/stencil

* The retained Qt6.11.2 backend fix discards temporary depth/stencil before
  presenting a window, preventing unnecessary A3xx GMEM→system-memory stores.
  It preserves normal drawing/depth tests; a captured scene uses LESS tests,
  so disabling depth is not equivalent.
* Historical controlled scene: preserving depth/stencil23.5–24.2ms,
  discarding19.4–19.6ms, no depth17.2ms. This explains part of lost budget,
  not stable60FPS by itself.60Hz permits16.67ms per frame.
* Install the hash-matching Qt GUI library, scoped to the shell, rather than
  silently replacing every system client. Kernel/KWin/Mesa identities must
  remain the qualified ones when comparing this intervention.

Evidence: `patches/qt/0001-discard-swapchain-depth.patch`,
[loaded stack identity](../config/graphics-stack.lock.json),
[release validation](../docs/graphics-release-validation-20261103.json).
