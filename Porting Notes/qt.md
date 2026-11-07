# Qt OpenGL swapchain depth/stencil

* The retained Qt6.11.2 backend fix discards temporary depth/stencil before
  presenting a window, preventing unnecessary A3xx GMEM→system-memory stores.
  It preserves normal drawing/depth tests; a captured scene uses LESS tests,
  so disabling depth is not equivalent.
* Historical controlled scene: preserving depth/stencil23.5–24.2 ms,
  discarding19.4–19.6 ms, no depth17.2 ms. This explains part of lost budget,
  not stable60FPS by itself.60 Hz permits16.67 ms per frame.
* The fix is shell-scoped; comparing it requires matching kernel/KWin/Mesa
  identities, not a global Qt library replacement.
