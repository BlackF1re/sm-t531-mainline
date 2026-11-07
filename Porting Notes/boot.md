# lk2nd, bootstrap and kexec

* Frozen internal BOOT p14 is10MiB: protected lk2nd prefix512KiB plus ext2
  bootstrap payload. RECOVERY p15. Android-v0 lk2nd image itself309264bytes
  fits the preserved prefix. Full BOOT is distinct from lk2nd's virtual `boot`
  payload9,961,472bytes. Never flash a full physical BOOT via virtual `boot`.
* Bootstrap approximately3-s countdown / volume-key recovery, then kexec SD
  kernel. Its exact source base`5fce161649b4`+first6Linux patches and scripts
  at Git`7a4374c` are reconstructable; exact config`config/bootstrap-frozen.config`.
  Reconstruction is not a claim of byte-identical rebuilding. Ordinary main
  updates must not rebuild/replace the frozen chain.
* Installed SD file named `zImage` is an Android-v0 container carrying appended
  DT, not host raw Linux zImage. `CONFIG_ARM_ATAG_DTB_COMPAT` is off. Firmware
  framebuffer is at`0x03200000`; keep decompression/DT/initramfs placement clear.
  Excluding unrelated Exynos/Tegra/MDP4/DPU/DP/HDMI built-ins avoids fixed-space
  overflow. Memory banks passed by packaging:0…0x40000000 and0x40000000…0x60000000.
* Main image SHA`d476c3fb1032590d31285e49c468301f1ff8619abf75af1dc9af47e65d6cfe85`,
  slot`mainline-d476c3fb1032`; `/graphics-current` selects actual slot. Read-only
  debugfs `cat` does not follow ext2 fast symlinks: resolve them before hashing.
  A stale production.slot marker is not proof of selected boot content.
* Retained working artifacts:`../artifacts/mainline-20261103` (balanced boot +
  matching production modules; all811module hashes matched); main source
  `../sources/linux-mainline`,139recorded patches, no extra source modifications.
  Generated builds now use`../build/sm-t531`, not removed`.work`.

## Preservation and recovery boundaries

Full current internal BOOT hash`f2e67d637182e79193912952f45341ceac4e621aeb7cefab4a8e55a6663192fc`;
older private Android BOOT hash`b04a99b4fb519a65a3135786d996fa580c9d7022694ebb8a00ed7a06c60c89cd`.
Do not relabel one as the other or treat ten old critical dumps as full eMMC.
Ramoops controlled-restart retention was observed; power-loss retention was not.
Never infer crash absence solely from missing pstore after an early failure.

* **DEVICE, 2026-11-07:** original Android full BOOT booted through Samsung's
  loader; afterward the fresh pre-test Linux/lk2nd BOOT was restored to p14.
  Full partition readback matched the `f2e67d…` hash above. The SD boot selection
  and mainline image were not changed during this audit.

[Android boot audit](../docs/android-hardware-observation-20261107.json).

Primary data: [SD checks](../docs/sd-cd-sleep-results-20261101.json),
[package](../docs/sd-cd-fix-package-20261101.json),
[graphics audit](../docs/graphics-stack-audit-20261103.json), private provenance.

Startup: native graphics waits up to45s for SSH listener. Unit uses
Wants/Before display-manager rather than nested synchronous systemctl from
ExecStartPost; reduced boot-delay mechanism was not independently established.

Bootstrap recovery commands: `mount-sd` mounts read-only without ext4 journal
replay; `umount-sd` before changing to `mount-sd rw`. `boot-sd` attempts SD boot;
`save-logs` performs its own writable mount/unmount and stores rescue evidence.
Automatic kexec preserves previous pstore first. Use one USB ACM reader at a time.
Do not reboot, rewrite boot files or unload DRM during an unrelated investigation.

An inherited first-stage loop logged sysrq-triggered crash; the corrected
command line removed console=ttyMSM0,115200 and added sysctl.kernel.sysrq=0.
This was not evidence of a new SMP/cpufreq defect. Native serial BREAK/SysRq is
disabled in config/kernel.fragment; no wired UART console is established.
