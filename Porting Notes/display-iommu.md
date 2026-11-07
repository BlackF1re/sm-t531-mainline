# Legacy display IOMMU / TrustZone

* MDP's legacy qcom_iommu is not the GPU ARM SMMU. Generic global IDR0 read
  atfd928020 aborted; use secure configID1, context0fd930000 and power its
  parent before context probe. Unified DRM still keeps these address spaces
  separate; sharing GEM does not remove display translation initialization.
* Patches 0062–0067/0079–0101 implement short descriptors, HLOS BFB tables,
  fault termination, halt/TLB/ASID ordering and security/shareability attributes.
* Causal device result:0097 initializes shared TrustZone tables; nine page and
  three section translations then matched RAM, and unmap produced a real fault.
  0098 avoids reserved TCR2 writes on short-descriptor contexts;0101 synchronizes
  TLB only after releasing halt. Do not substitute speculative register reads.
* 0112 handles faults when no domain is attached,0113 avoids premature ARM32
  DMA attachment,0114 gives MDP ownership of its DMA domain. Preserve NULL checks
  and lifecycle separation rather than hiding faults or disabling DMA sync.
* Protected CBAR/global reads caused SIGBUS/Oops. Use the existing guarded
  context diagnostics only; a translation query completing is not proof its
  returned physical address is correct.
