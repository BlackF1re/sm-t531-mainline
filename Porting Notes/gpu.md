# Adreno 305B and unified DRM

## Architecture and required fixes

* **DEVICE:** A305B ID `0x03000512`; Freedreno FD305 GLES hardware rendering.
  GPU and MDP5 share **one** MSM DRM device, `separate_gpu_kms=0`; separate GPU
  and display IOMMU address spaces remain. Discover capabilities/sysfs identity,
  not `card0/card1` numbering. Desktop simpledrm and the msm-kms loader shim are
  obsolete; early framebuffer/recovery remain deliberate.
* Patches 0126–0129: correct component teardown/DRM ownership and self-import
  registration, factor IOVA teardown and retain shared global GPU-VM mappings.
  Platform GPU drvdata is SMMU state, not DRM private data. Closing one imported
  handle must not unmap another client's live A305 global-VM object.
  Two-client reproducer: live IOVA stays `0x1009000`; filler gets `0x100a000`.
  Upstream backports retain authorship and [series Message-IDs](https://lore.kernel.org/r/20260822-msm-fix-export-v1-1-917b3cbedd43@oss.qualcomm.com).
* **DEVICE, 2026-10-29:** expensive split PRIME median ~6.2 ms → unified
  card/render 0.017/0.014 ms, maximum 0.081 ms; allocations 615,243/20 s →
  275/22 s. 2,113 successful PRIME calls remain: cheap shared-object lookup,
  not elimination of the API. Exact old allocation/import ownership was not
  proven; the measured allocation collapse is real.
* A305B requires three VBIF clients (0027). Drain VBIF on suspend (0024), reset
  ring pointers before recovery (0105), omit unsafe HLSQ crash reads (0106).
  If `needs_hw_init`, synchronize software ring cur/next with validated hardware
  WPTR before suspend (0131); otherwise second sleep may compare RPTR 0 with
  stale WPTR 528 and return `-EBUSY`. Fences/drain checks remain enabled.

## Current Mesa/Qt path

Canonical identities/hashes: [graphics lock](../config/graphics-stack.lock.json).
Installation/verification commands: [graphics operations](../docs/GRAPHICS-STACK.md).
Kernel baseline is `7.2.9-t531-mainline-dirty`; no code changed in consolidation.

* KWin: packaged Mesa `25.0.7-2+deb13u1`, GLES, `FD_MESA_DEBUG=inorder`.
  Plasma: six main Mesa patches, `inorder,ttile`; Qt 6.11.2 transient
  depth/stencil discard. One fixed stack, not arbitrary per-app candidates.
* Mesa 0001 fixes 4×4 tile row pitch; 0002 preserves tiled target channel swap.
  0009 keeps externally shared images linear (A3xx modifier ambiguity); 0010
  rejects buffer textures as render targets. Those fixes prevent corrupted
  navbar/text/icons and invalid surface capabilities.
* Mesa 0011 compacts only private single-level/layer/non-MSAA 2D tiled color
  images: retain 4-row alignment, remove power-of-two height rounding.
  Arrays/cubes/mips/depth/MSAA/shared scanout retain safeguards. Sixteen 1280×800
  targets: allocation 85,568→69,184 KiB (−19.15%); rendering ~14.9 ms unchanged.
* Mesa 0012 sizes query resources as buffers; occlusion-query correctness is
  separate from frame pacing. Maintain all zeroing/cache synchronization.
* Qt must invalidate temporary depth/stencil before swapping; tests may use
  real LESS depth comparisons, so disabling depth is not equivalent.
  Historical scene: preserve D/S 23.5–24.2 ms, discard 19.4–19.6, no depth 17.2.
* KWin `4:6.7.4-2+t531overlay1` includes the recovered single-top-overlay retry
  patch under `patches/kwin`; it was active but formerly missing from source.
  Isolated FPS benefit is unproven. Vulkan-Hpp build dependency/probe:
  `libvulkan-dev=1.4.363.0-1`, `tools/kwin-vulkan-api-probe.cpp`, C++23/no exceptions.
* Plasma Mobile's retained quick-settings cache patch is shell-specific, unlike
  the DRM/Mesa/Qt corrections. Original/cache/original 35.026/51.432/34.735 DRM
  events/s; canonical 51.251 after boot, 50.732 after s2idle/RPM. p95 ≈33.4 ms;
  stable 60 FPS and optical distinct-frame rate are not established.
* **DEVICE, 2026-11-06:** a current-boot GPU lockup/recovery at ~109 s was found
  despite correct loaded identities. Live session restarts/settings previously
  hung/crashed compositors. Recovery/endurance remain open; forced runtime PM
  `on` and replacing KWin Mesa with the shell build are not accepted fixes.

Toolkit/session pitfalls: Phosh t5311 SIGTRAP read GNOME49 brightness shortcuts
unconditionally on GNOME48; `patches/phosh/0001*` adds schema/key fallback,
not a GPU workaround. Record live process libraries and actual gestures;
profiling lockscreen/no-op D-Bus transitions does not measure the drawer.
Premature shell starts without imported Wayland session environment can fail
independently of DRM; fix the environment/order, not a renderer fallback.

Measurements/methods: [gpu-experiments](gpu-experiments.md),
[release validation](../docs/graphics-release-validation-20261103.json),
[stack audit](../docs/graphics-stack-audit-20261103.json),
`tools/drm-device`, `tools/check-graphics-stack.py`, `tools/sample-gpu-busy.py`.
