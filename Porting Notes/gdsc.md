# GDSC multimedia power domains

* **SOURCE (MSM8226 MMCC):** GPU OXILI CX/GX `0xfd8c4034`/`0xfd8c4024`; MDSS `0xfd8c2304`; VFE `0xfd8c36a4`; JPEG `0xfd8c35a4`; Venus `0xfd8c1024` (core0/1 `0xfd8c1040/44`); VPU `0xfd8c1404`; VCAP `0xfd8c1804`.
* Shared `msm-gdsc.dtsi` additionally lists USB-HSIC, PCIe0/1 and USB3 domains, **disabled by default**. Such SoC capability is not evidence of populated r02 ports or enabled board peripherals.
* GDSC power gating is distinct from PM8226 LDO/BUCK rails, RPM votes and GCC/MMCC clock enables. Power domains must be ready before IOMMU/device register access; no blanket power-on or unsafe probing of otherwise gated MMIO.
* **DEVICE:** current GPU/MDP functionality and tested sleep paths are documented separately; they do not accept every listed domain. Source: [source manifest](../docs/hardware-source-manifest.json), `msm-gdsc.dtsi`. See [clocks](clocks.md) and [system sleep](power-management.md).
