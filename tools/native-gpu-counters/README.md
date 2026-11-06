# Historical A305B counter diagnostic

Recovered byte-for-byte from `.work/gpu-counter-build/` on 2026-11-06.
Research tooling only: not a production driver or an automatically loaded module.
The module selects VBIF counters and optionally PC/RB/SP/TP/UCHE counters;
it requires SM-T531 / Adreno 305.18, takes a runtime PM reference, checks
selector ownership and restores its selectors after 30 seconds or on unload.
HLSQ is not accessed. The reader requires the module and a powered GPU.

Build against the exact target kernel with its configuration and Module.symvers:
`make -C "$KERNEL_BUILD" M="$PWD/tools/native-gpu-counters" modules`.
Do not reuse retained `.ko` files across kernel builds. Do not run alongside
another counter owner. Counter intervals overlap: their sum is not frame time.
Preserving these sources is not a new safety or hardware qualification.
No module was loaded during the preservation audit.
