# Unified MSM DRM / GEM

* Native topology: one MSM DRM device contains Adreno305B and MDP5;
  `separate_gpu_kms=0`. GPU/display IOMMU address spaces remain distinct.
  Discover render/KMS capabilities and stable sysfs identity, not card numbers.
* Native KMS handles atomic modesets/page flips; firmware/simplefb is only
  early console/recovery. Desktop simpledrm and the split msm-kms loader shim
  are obsolete. No memory zeroing/cache/fence validation was disabled.
* Patches 0126–0129: correct component teardown/DRM ownership and self-import
  registration, factor IOVA teardown and retain shared global GPU-VM mappings.
  Platform GPU drvdata is SMMU state, not DRM private data. Closing one imported
  handle must not unmap another client's live A305 global-VM object.
  Two-client reproducer: live IOVA stays `0x1009000`; filler gets `0x100a000`.
  Patches 0128/0129 retain upstream authorship.
* **DEVICE:** expensive split PRIME median ~6.2 ms → unified
  card/render 0.017/0.014 ms, maximum 0.081 ms; allocations 615,243/20 s →
  275/22 s. 2,113 successful PRIME calls remain: cheap shared-object lookup,
  not elimination of the API. Exact old allocation/import ownership was not
  proven; the measured allocation collapse is real.

Configuration: `config/msm.conf`; activation: `scripts/start-native-graphics.sh`.
Run `tools/drm-device` probes to validate the actual common device. Hardware
OpenGL, valid planes and short trace success are not endurance acceptance.
