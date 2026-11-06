# Tools and diagnostics

These tools are not a collection of production services. Host checks run only
when requested; device probes and workload generators require deliberate
invocation. Read the tool's header or adjacent README before using it.

| Group | Entry points | Scope |
|---|---|---|
| Repository checks | `check-repository.py`, `make check` | Host-only syntax, JSON, local documentation links, source hygiene and unit tests |
| Installed graphics identity | `check-graphics-stack.py`, `graphics-path.py` | Read-only tablet checks; identify the actual loaded stack |
| Safe SD graphics slots | `graphics-ab/` | Atomic slot storage; device orchestration is in `scripts/graphics/ab.sh` |
| DRM capabilities | `drm-device/`, `check-mdp5-resources.py`, `check-crtc-progress.c` | Native KMS/format/resource diagnostics |
| Graphics measurements | `sample-*.py`, `summarize-*.py`, `auto-drawer.py`, `drawer-load.py`, `frame-load.qml` | Sampling, report generation and explicit test workloads; presentation counts are not optical FPS |
| GPU microbenchmarks | `fd-*.c`, `fd2d-bench.c`, `cache-latency.c` | Isolated workloads; do not infer whole-desktop FPS from them |
| Bounded kernel diagnostics | `native-fence-owner/`, `native-gpu-counters/`, `native-memory-floor/`, `cpu-cache-state/`, `battery-diag/`, `fm-diag/`, `mxt-pm-probe/`, `wifi-irq-rearm/` | Build against the exact target kernel; several probes access hardware or change temporary state. None is autoloaded by this index |
| Historical Mesa instrumentation | `diagnostics/a3xx-stage/` | Intrusive stage-timing method; excluded from production patches and unsuitable as an FPS benchmark |
| Build compatibility | `kwin-vulkan-api-probe.cpp` | Vulkan-Hpp syntax probe, not Vulkan support on Adreno 305 |
| Battery, backlight and sleep | `check-battery-*.py`, `test-*brightness.py`, `test-backlight-range.py`, `audit-sleep-states.py`, `check-suspend-cycle.py` | Tool-specific acceptance tests; some change device state |
| Private stock-data backups | `stock-backup/`, `scripts/backup-stock` | Read-only acquisition, integrity checks and explicitly confirmed restoration; default output is Git-ignored |
| Identity and image preparation | `set-bluetooth-address.py`, `check-boot-layout.py` | Private per-device identity insertion and boot-container inspection |
| Radio / Android research | `wifi/`, `android/`, `build-wifi-trial.sh`, `fetch-phosh-runtime.py` | Specialized bring-up and reproducibility helpers |
| Bus / display register research | `measure-msm8226-bus.c`, `read-msm8226-qos.py`, `read-dsi-controller.c` | Device-specific register access; historical diagnostics, not routine health checks |

Generated objects and caches are ignored. Keep builds outside the source tree
where practical; retaining a `.ko` does not establish compatibility with the
running kernel. Store accepted conclusions in the existing documentation and
retain only the minimum method/source needed to reproduce them.
