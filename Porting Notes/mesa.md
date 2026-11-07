# Mesa / Freedreno A3xx resource handling

* Supported user libraries: Mesa25.0.7 with six main patches for Plasma,
  `FD_MESA_DEBUG=inorder,ttile`; KWin retains packaged25.0.7-2+deb13u1 with
  `inorder`. Both render through one unified MSM device. Exact hashes are in
  `config/graphics-stack.lock.json`; arbitrary library mixtures are unsupported.
* 0001 fixes4×4 tile row pitch;0002 preserves tiled-target channel swap.
  0009 keeps shared/scanout images linear because A3xx modifiers are ambiguous.
  These guards prevent corrupted navbar/text/icons; they are not optional
  speed flags. Preserve zeroing, synchronization and full image correctness.
* 0010 rejects buffer textures as render targets.0012 sizes query resources as
  buffers; the observed query bug has no demonstrated link to GUI deadlines.
* 0011 changes only private single-level/layer,non-MSAA2D tiled color height:
  retain4-row alignment without power-of-two rounding. Arrays/cubes/mips,
  depth/MSAA and shared images retain previous safeguards.
* Device measurements:16targets1280×800 allocated85,568→69,184KiB (−19.15%);
  render~14.9ms unchanged. Actual BO buckets/cache affect allocation; do not
  derive savings from width×height alone or claim a60FPS fix.
* **DEVICE:** retained correctness campaign checked98readback
  cases/62,655,530pixels, including full-frame comparisons. Bounded true/empty
  occlusion queries passed after0012; correctness is not60FPS acceptance.
* Build accepted series with `scripts/build-mesa.sh`, supplying
  `MESA_SOURCE_ARCHIVE` (pinned25.0.7tar), `MESA_CROSS_FILE` and optional JOBS.
  Source archive/patch/source checksums prevent mixed candidate builds.
* Shell-only library paths use LD_LIBRARY_PATH, GBM_BACKENDS_PATH and EGL vendor
  JSON from `config/t531-mesa-shell.conf`; do not force a global private Mesa
  into every client. The old split-loader shim is unnecessary.

Evidence: `patches/mesa`,
`tools/fd-texture-memory.c`, `scripts/build-mesa.sh`.
