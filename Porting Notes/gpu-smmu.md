# GPU ARM SMMU

* Adreno305B uses ARM SMMU; native CONFIG_ARM_SMMU and ARMV7S page tables are
  required. It differs from the legacy secure display qcom_iommu.
* 0007 adds the GPU SMMU node;0008 detaches the inherited ARM DMA mapping;
 0009/0010 describe MSM8226 and correct context offsets;0017 disables AFE.
* GPU platform drvdata holds SMMU state, not DRM private data. Preserve component
  ownership when GPU/KMS bind to one MSM DRM device. The A305 global GPU-VM
  mapping must survive another client's imported-handle close (0126–0129).
* Unified rendering/scanout and short mapping tests passed. Repeated faults,
  recovery, sleep isolation and unused camera/video contexts are not accepted
  merely because this GPU path works.
