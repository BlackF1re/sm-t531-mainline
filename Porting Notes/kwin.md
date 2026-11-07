# KWin Wayland and MDP5 overlays

* Supported custom version `4:6.7.4-2+t531overlay1`; packaged Mesa
  25.0.7-2+deb13u1, OpenGL ES and `FD_MESA_DEBUG=inorder`. Kernel Adreno/MDP5
  share one DRM device. `config/t531-graphics.conf` sets QSG_RHI_BACKEND=opengl,
  KWIN_COMPOSE=O2ES, KWIN_USE_OVERLAYS=1; capability discovery replaces cardN paths.
* The single-top-overlay retry patch was active but initially missing from
  source packaging. It is retained under `patches/kwin`; isolated FPS benefit
  is unproven. The checker verifies package version and the mapped libkwin hash.
* MDP5 has 7×4 KiB SMP blocks, max3perpipe. Three fullscreen RGBA planes needing
  nine blocks cannot fit. Failed atomic plane candidates must be composited;
  enabling overlays cannot make every scene fit the hardware allocation.
* `tools/kwin-vulkan-api-probe.cpp` is a build-time Vulkan-Hpp syntax
  compatibility probe, not evidence of Vulkan rendering on Adreno 305.
* Import Wayland session environment before starting the shell; a premature
  no-display startup failure is not evidence of a GPU rendering fallback.
