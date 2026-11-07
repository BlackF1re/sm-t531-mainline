# Camera, video and audio IOMMU contexts

* **SOURCE (SoC, vendor `qcom,msm-smmu-v1`):** VFE `0xfda44000`, JPEG `0xfda64000`, Venus `0xfdc84000`, LPASS QDSP `0xfe054000`, LPASS core `0xfe064000`. The shared tree also defines COPSS `0xf9bc4000`, VPU `0xfdee4000` and VCAP `0xfdfb6000`; their mere presence is not r02 endpoint acceptance.
* `msm8226-iommu.dtsi` explicitly enables VFE/JPEG/Venus vendor IOMMUs and supplies them from matching GDSCs. Venus has distinct nonsecure, content-protected and firmware context banks; secure banks cannot be treated as ordinary user buffers.
* **Native:** camera streaming, standalone JPEG and Venus encode/decode are unaccepted. Complete DMA address mapping, clocks, domains, context ownership and faults must be tested per engine. Working Adreno/MDP address translation does **not** validate these IOMMUs.
* Source: [source manifest](../docs/hardware-source-manifest.json), `msm-iommu-v1.dtsi`, `msm8226-iommu.dtsi`, `msm8226-iommu-domains.dtsi`. See [GPU](gpu-smmu.md) and [MDP](display-iommu.md) IOMMUs.
