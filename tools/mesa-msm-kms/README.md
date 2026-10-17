# Native split MSM KMS loader entry

Mesa 25.0.7 has no `msm-kms_dri.so` entry for Linux's existing
`msm.separate_gpu_kms=1` display-only DRM device. This small MIT shim exports
both spellings of its extension entry and delegates to the installed generic
platform entry. It does not render or copy frames itself.

In the pinned Mesa source, `DEFINE_LOADER_DRM_ENTRYPOINT(mediatek)` returns
the same `__driDriverExtensions` as other DRM entry points:
[dril_target.c, mesa-25.0.7](https://gitlab.freedesktop.org/mesa/mesa/-/blob/mesa-25.0.7/src/gallium/targets/dril/dril_target.c).
The Gallium DRM loader selects the KMSRO adapter for a display-only device;
the adapter imports scanout DMA-BUFs into the Adreno render device. See
[pipe_loader_drm.c](https://gitlab.freedesktop.org/mesa/mesa/-/blob/mesa-25.0.7/src/gallium/auxiliary/pipe-loader/pipe_loader_drm.c)
and [kmsro_drm_winsys.c](https://gitlab.freedesktop.org/mesa/mesa/-/blob/mesa-25.0.7/src/gallium/winsys/kmsro/drm/kmsro_drm_winsys.c).
Sources inspected locally on 2026-10-14. `mediatek` here is a generic Mesa
entry, not an Android driver or a MediaTek hardware dependency.

Build with `scripts/build-mesa-msm-kms.sh`, install the resulting armhf deb
with `dpkg -i`, then run `scripts/configure-native-plasma.sh activate` with
SDDM and KWin stopped. The package owns only the new entry and its license;
Debian's existing Mesa files remain package-managed. Ordinary applications
continue selecting Freedreno on the `msm` render node.

Do not set `MESA_LOADER_DRIVER_OVERRIDE=mediatek` globally or in KWin's
service. KWin passes it to its keyboard process and also hosts Qt Quick
contexts. On this tablet the override caused dumb-buffer EPERM errors and
crashes. The new entry initializes EGL 1.5 with a linear XR24 modifier,
and KWin reports FD305 with native MDP5 imported DMA-BUF scanout. A warmed
full-desktop animation measures 42.86 FPS; this packaging fix alone does
not claim a throughput improvement.

This is a board packaging workaround, not a substitute for adding the
missing entry to maintained Mesa. Revalidate delegation when upgrading Mesa.
