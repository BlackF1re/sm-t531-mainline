# Bounded OCMEM request diagnostic

SM-T531 matching-kernel diagnostic. Adds a temporary consumer to the existing
GPU OCMEM interconnect path, requesting peak 6,400,000 kB/s (the retained BSP's
400 MHz request on a 16-byte bus). It automatically releases the request after
120 seconds; unloading also releases it. It does not overclock or measure the
physical OCMEM clock and must not be interpreted as proof that the request was
delivered by firmware.

Build using the exact configured kernel tree, generated headers and symbols:

```sh
make -C "${KERNEL_SRC:-../sources/linux-mainline}" \
  O="${KERNEL_OUT:-$PWD/../build/sm-t531/out}" ARCH=arm \
  CROSS_COMPILE=arm-linux-gnueabihf- \
  M="$PWD/tools/native-memory-floor" modules
```

Load `t531_memory_floor.ko` only on the matching SM-T531 kernel as root, run a
bounded measurement, and unload it. It checks the board compatible. No GPU
registers, geometry, color formats or desktop settings are changed.

See `Porting Notes/gpu-experiments.md`: the retained rate sweep did not
change the physically measured GPU/AXI rates despite lower devfreq requests,
so it cannot establish a causal dependence on GPU frequency or OCMEM bandwidth.
