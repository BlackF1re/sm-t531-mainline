# KWin Wayland and MDP5 overlays

* Supported custom version `4:6.7.4-2+t531overlay1`; packaged Mesa
  25.0.7-2+deb13u1, OpenGL ES and `FD_MESA_DEBUG=inorder`. Kernel Adreno/MDP5
  share one DRM device. `config/t531-graphics.conf` sets QSG_RHI_BACKEND=opengl,
  KWIN_COMPOSE=O2ES,KWIN_USE_OVERLAYS=1; capability discovery replaces cardN paths.
* The single-top-overlay retry patch was active but initially missing from
  source packaging. It is retained under `patches/kwin`; isolated FPS benefit
  is unproven. The checker verifies package version and the mapped libkwin hash.
* MDP5 has7×4KiB SMP blocks,max3perpipe. Three fullscreen RGBA planes needing
  nine blocks cannot fit. Failed atomic plane candidates must be composited;
  enabling overlays cannot make every scene fit the hardware allocation.
* Before building6.7.4, the retained environment pins libvulkan-dev1.4.363.0-1.
  `tools/kwin-vulkan-api-probe.cpp` checks Vulkan-Hpp return types using C++23,
  `-fno-exceptions -DVULKAN_HPP_NO_EXCEPTIONS=1 -fsyntax-only`. This does not
  establish Vulkan rendering on A305.
* Import Wayland session environment before starting the shell; a premature
  no-display startup failure is not evidence of a GPU rendering fallback.

Evidence: `patches/kwin`, [stack identity](../config/graphics-stack.lock.json),
[stack audit](../docs/graphics-stack-audit-20261103.json),
`tools/check-graphics-stack.py`, `config/t531-kwin-graphics.conf`.
