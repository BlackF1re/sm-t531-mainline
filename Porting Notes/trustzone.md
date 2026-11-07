# TrustZone / SCM and QSEECom

* **SOURCE (SoC):** secure monitor calls use Qualcomm SCM (`qcom,scm-msm8226` in upstream). Downstream QSEECom has a `secapp-region` resource at `0x0cb00000` of size 0x600000; this is a memory *region*, not a normal device register base.
* TrustZone owns or protects parts of boot/authentication, secure video memory, crypto usage and legacy display IOMMU context setup. Calls succeeding under one firmware policy do not prove raw register access is permitted.
* **DEVICE:** display-IOMMU guarded operations required secure setup; protected global MMIO reads previously caused aborts. Current board security policies, keys, fuse state and secure-memory contents are not published or inferred.
* Porting must preserve bootloader/SCM ABI, memory ownership and factory secrets; no secure-state changes are required. Source: [source manifest](../docs/hardware-source-manifest.json), `msm8226.dtsi`, `msm8226-iommu-domains.dtsi`. See [display IOMMU](display-iommu.md), [eFuses](efuses.md).
