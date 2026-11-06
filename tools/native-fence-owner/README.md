# Bounded fence ownership diagnostic

Read-only SM-T531 diagnostic for the exact running MSM kernel: maps GPU submit
IDs to the context/sequence of their retained user and hardware fences at
retirement. No GPU registers, clocks, fences or scheduling decisions are changed.

Build against the matching configured kernel tree, generated symbols and
release. Supply an existing build directory explicitly; no historical `.work`
output is required:

```sh
make -C "$KERNEL_BUILD" ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
  M="$PWD/tools/native-fence-owner" modules
```

On SM-T531, load as root, record existing DRM/MSM/dma_fence tracepoints during
the workload, wait 30 seconds, then read
`/sys/kernel/debug/t531_fence_owner/records`. It returns `EBUSY` before probes
stop. Reject captures with `overflow=1`. Unload `t531_fence_owner` after copying
the records. Early unload also unregisters and synchronizes the callback.

The module callback relies on this exact kernel's private `msm_gem_submit`
layout and submit-retired tracepoint signature. It refuses other board
compatibles. Its fixed array stores at most 16384 rows; it stops recording after
30 seconds even if userspace disappears. Debugfs access is root-only.

A fence ownership match proves the producer of that fence. It does not prove
which framebuffer or commit owns a late presentation, and explicit fence-wait
tracepoints do not include userspace poll waits or every scheduler dependency.
