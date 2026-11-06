# Active source preservation audit, 2026-11-06

This is a bounded source/runtime identity audit, not a new stability or FPS test.
No graphics service was restarted, no modules were loaded, and no boot files
or internal storage were modified. Runtime checks were read-only; an expected
manifest was staged under `/var/tmp` without replacing installed configuration.

## Recovered omission

The tablet runs `kwin-common`, `kwin-wayland` and `libkwin6` version
`4:6.7.4-2+t531overlay1`. Its single-top-overlay patch existed only under
`.work/kwin-overlay-build/`, including Debian packaging. It was absent from
main's patch tree and the earlier graphics-stack inventory.

The installed libkwin and the library extracted from the retained custom DEB
have identical SHA256:
`86ef2aa59b13487320108bc804d246e90fabac88d2b849d789f61577baf3e18b`.
The installed binary contains the patch's distinct fallback diagnostic string.
Package verification found no modified libkwin/kwin-wayland package files.

The patch is now preserved as
[`patches/kwin/0001-compositor-retry-single-top-overlay.patch`](../patches/kwin/0001-compositor-retry-single-top-overlay.patch).
Its hunks match the custom Debian patch, and apply to the retained KWin 6.7.4
source in a dry run without fuzz. Obsolete “not built or deployed” metadata was
corrected. This proves active source preservation, not an isolated performance
benefit or a solution for stable 60 FPS.

The original build log additionally pins `libvulkan-dev=1.4.363.0-1` and performs
a Vulkan-Hpp return-type syntax probe before building. The probe is preserved in
[`tools/kwin-vulkan-api-probe.cpp`](../tools/kwin-vulkan-api-probe.cpp);
compile it with `g++ -std=c++23 -fno-exceptions -DVULKAN_HPP_NO_EXCEPTIONS=1
-fsyntax-only tools/kwin-vulkan-api-probe.cpp` in that build environment.
It is a build compatibility check; Vulkan rendering on A305 is not claimed.

The graphics lock and read-only checker now cover the custom KWin package
version and the actually mapped libkwin library, which the old checker omitted.
The checker accepts `--lock PATH` so an expected manifest can be audited before
installation. No KWin rebuild or replacement was needed for this audit.

## Previously preserved working changes

* Mesa main patches 0001/0002/0009/0010/0011/0012 and installed manifest checks.
* The active Qt 6.11.2 depth/stencil discard patch in `patches/qt`.
* The restored drawer cache source in `patches/plasma-mobile`; its prior loss
  was already fixed in commit `9036656`, with original/cache/original evidence.
* Unified DRM and accepted sleep/input/radio/charging kernel changes in the
  main Linux series. Module identity and required callbacks match the lock.
* All six frozen bootstrap source patches are byte-identical to their main
  `patches/linux` counterparts. Bootstrap binaries are recovery/build artifacts.

Private diagnostic census, forced precision, scissor and rejected sleep
variants are not promoted by this audit. They have no accepted replacement
for the current production stack. Historical candidates remain recoverable
from commit `43648a2`. The pre-existing unrelated stash was left untouched.
Build outputs and raw traces remaining under `.work` are not themselves
missing production source patches.

## Runtime result and limitation

The initial existing stack check passed. The extended check passed identities,
manifest hashes, unified DRM, Qt/cache, sleep callbacks and PowerDevil checks,
but its later current-boot journal check found a GPU lockup and recovery at
approximately 109 seconds after boot. KWin and plasmashell were running when
rechecked. No cause is assigned by this preservation audit, and current-boot
stability must not be described as qualified. The checker was not weakened to
hide that failure. No long-running or physical acceptance test was performed.

## Cleanup completion

Missing diagnostic source is retained under `tools/native-gpu-counters` and
`tools/diagnostics/a3xx-stage`, separate from production patches. The latter
stores the small instrumentation diff and original parser, not duplicate
Mesa trees or raw traces already summarized in the reports. Its patch passes
a zero-fuzz dry run against the retained Mesa 25.0.7 source.

The working release was retained once outside Git in
`../artifacts/mainline-20261103/` and every destination file was hash-checked.
The main Linux tree was relocated to `../sources/linux-mainline/`; its 139
recorded patches matched before relocation. The frozen bootstrap configuration
is in `config/bootstrap-frozen.config`; its base and six patches already exist
in the source history. Only the unique installed BOOT and per-device Bluetooth
identity were copied into private storage. No address is present in public Git.
Build defaults now use `../build/sm-t531/` instead of recreating `.work`.
The ignored `.work` workspace and generated diagnostic objects were removed
once preservation and host checks completed. No tablet runtime was changed.
