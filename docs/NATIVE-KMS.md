# SM-T531 native display bring-up

> [!NOTE]
> **Historical bring-up log.** The opening summary below describes the patch0101-era Plasma profile. For the installed `#8` / MSM0116 / Phosh profile, use [Graphics stability](GRAPHICS-STABILITY.md#acceptance-status) and [Recovery & safety](RECOVERY.md#graphics-fallback). Native KMS and ICC are now the default build; the later fixes removed the measured blanking IRQ storm and the reproduced mode-enable underrun in the tested scenarios. [Memory bus measurements](MEMORY-BUS.md) include active DDR clock verification. Full lifecycle, physical repeat acceptance and all power states remain incomplete.

## Earlier patch0101 summary

State: PARTIAL. The owner has physically confirmed a native colour pattern
without live register reconciliation on patch0101, then normal accelerated
Plasma desktop, tray, touch, colours and brightness with native ICC enabled.
The corrected automatic cold-boot activation still needs a repeat test.
Patch0097 fixes the measured MDP translation mismatch by initializing
shared TrustZone tables, as the exact BSP does. Nine page translations
and three section offsets now match Linux; removing the section gives a
hardware fault. The next measured blocker was a lost DSI byte mux selector:
CCF retained the indirect parent but hardware selected direct VCO, doubling
the implied byte clock. Replaying the cached parent restored the test image.
Patch0100 replays the mux selector in prepare, and patch0101 moves TLBSYNC
after releasing the context halt. FIFO errors persist after fresh activation.
GPU/KMS separation avoids observed combined-device GPU lockups. KWin now
uses the proper packaged msm-kms Mesa entry rather than an environment
override; native scanout imports DMA-BUFs and does no sysfb RGB888 conversion.
The complete warmed desktop gives42.86FPS with GPU98.93%; the owner's
repeated notification-shade gestures give approximately23.28FPS. A60Hz
vblank counter is not full interface performance. See GRAPHICS.md for scope.
Verified fallback remains physically accepted Plasma at about42FPS;
whole-tree rollback was retested successfully. Detailed machine-readable
experiments are in native-kms-results.json. Native ICC votes and AXI
clock have been observed on-device; DDR frequency and power policy remain
unverified.

First device test: MDP5 v1.1 and DSI bound, KMS failed with ENODEV because
there was no display IOMMU in DT. Reboot then panicked in
`ww_mutex_lock -> drm_modeset_lock_all_ctx -> drm_atomic_helper_shutdown`.
VERIFIED_DEVICE: ramoops recovered this trace from the physical tablet.
Code review found a dangling `priv->dev` after the init failure; patch0054
clears it. The next full early-native attempt produced a blue display and
no SSH/USB shell, with no new ramoops record recovered. Its cause is UNKNOWN.
Both experiments were recovered via lk2nd `fastboot boot` of the verified
RAM-only bootstrap rescue, restoring the SHA256-checked SD fallback.
No internal storage was written.

VERIFIED_DEVICE: late loading isolated an external abort reading global
IDR0 at `fd928020` with the generic arm-smmu driver. Vendor source identifies
the display IOMMU as TrustZone-managed (secure configuration ID1), unlike
the GPU IOMMU. Patches0062–0064 switch display to qcom_iommu, context0 at
`fd930000`, and power its parent before context probe. This removes that
abort and allows native DRM registration. It does not establish scanout.

The first automatic modesets then showed pclk0/byte0 RCG update timeouts,
TC358764 DSI command failures, FIFO interrupt storms and MDP underruns.
A later controlled probe with `drm_kms_helper.fbdev_emulation=N` produced
card0-LVDS-1 and renderD128 with the CRTC inactive and without that storm.
The legacy `msm.fbdev=0` parameter does not suppress the current generic
DRM client setup. Do not use it to isolate probe from modesetting.

VERIFIED_DEVICE: reading the complete `clk_summary` while the DSI PHY is
runtime-suspended aborts in `dsi_pll_28nm_clk_is_enabled`, reading PLL status
at physical `fd922ac0`. This diagnostic-triggered Oops is distinct from
the blue-screen modeset failure. Avoid clock-summary reads while PHY power
is off; the clock provider's unpowered access remains to be fixed.
An unexplained reboot near 2026-10-13 19:31 UTC has no established cause;
the owner could not confirm a manual reset, and the previous journal ends
with DSI FIFO errors rather than a recorded shutdown or panic.

The diagnostic kernel now builds DRM MSM and ARM SMMU as modules and
blacklists their automatic loading. This allows explicit activation after
SSH/USB and log capture are established. Ramoops was already built-in;
early failure before backend registration is a hypothesis for missing logs.
The regular board DT remains the tested simpledrm recovery profile.

## Hardware evidence

VERIFIED_VENDOR_SOURCE: Samsung/LineageOS MSM8226 BSP commit
`3fa1853ed5d6c3a8ef5a2fda9822705243bbc256`, GPL-2.0, files
`arch/arm/boot/dts/msm8226/dsi_panel_tc358764_wxga_video-r01.dtsi`,
`msm8226-sec-matisse3g-r02.dtsi`,
`drivers/video/msm/mdss/mdss_tc358764_dsi2lvds.c`,
`drivers/video/msm/mdss/msm_mdss_io_8974.c`, and `msm8226-bus.dtsi`.
Source: https://github.com/LineageOS/android_kernel_samsung_msm8226/tree/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256

VERIFIED_DEVICE (2026-10-14): read-only I2C adapter on TLMM SDA2/SCL3,
address 0x0f, ID 0x6500. Address bytes are big endian on I2C and returned
register data is little endian. Adapter removed after reading; GPIOs returned
to unclaimed input-high state. No bridge register writes or power cycling.

| Register | Value | Meaning |
| --- | --- | --- |
| PPI_LPTXTIMECNT | 4 | LP transmit period |
| PPI_TX_RX_TA | 0x50006 | BTA timings |
| PPI_D0..D3S_CLRSIPOCOUNT | 4 | Four lane receive timers |
| PPI_LANEENABLE, DSI_LANEENABLE | 0x1f | Four data lanes + clock |
| VP_CTRL | 0x03f00120 | VS delay63, RGB888, event mode, internal timing generator off |
| VP_HTIM1/2 | 0x00300002 / 0x00300320 | Vendor stored timings |
| VP_VTIM1/2 | 0x00400002 / 0x00200500 | Vendor stored timings |
| LV_MX0003..2427 | 03020100 08050704 0f0e0a09 100d0c0b 12111716 1b151413 061a1918 | Identical to upstream mux |
| LV_CFG | 1 | LVDS enabled; both clock polarity bits clear |
| LV_PHY0 | 0x48006 | Verified running PHY value |

The swapped 800/1280 active values in the bridge's stored timing registers
match the actual vendor command sequence. HYPOTHESIS: they are unused while
VTGEN is clear and timing follows the DSI stream. Preserve the observed
sequence for initial bring-up rather than guessing a different one.

VERIFIED_DEVICE: bounded PROT_READ /dev/mem mmap of configuration registers:
DSI HW revision `0x10000002`, version `0x03000104` (6G v1.0.2).
MDP INTF1 HSYNC `0x05620002`, VSYNC period `0x0012e1c4`, H active
`0x05310032`: 1280x800, HFP/HBP/HS 48/48/2 and VFP/VBP/VS 32/64/2,
totals 1378x898. These confirm the vendor mode on the physical device.
PLL reference doubler1, SDM DC10/seed0xed4f, postdiv3=5: calculated VCO
458000390.625 Hz, pixel clock76333398.44 Hz, refresh61.6847 Hz.
This is a register-derived calculation, not an optical frequency measurement.
The diagnostic mode requests 74246640 Hz for exactly 60 Hz with those totals.

VERIFIED_VENDOR_SOURCE: TLMM51 active-low bridge reset; PM8226 GPIO2 LCD
power enable, physically output-high. Do not confuse it with TLMM GPIO2 SDA.
UNKNOWN: individual bridge supply net mapping and LCD module part number.
The board assembly compatible deliberately makes no claim about the module.
VESA-24 mapping is based on the identical known upstream mux and upstream
SPWG panel configuration; needs an on-device color/gradient acceptance test.

## Isolated diagnostic build and recovery

`NATIVE_KMS=1 scripts/build.sh` builds the separate `*-native.dts`, disables
simpledrm, enables MDSS, connects MDP5 -> DSI0 -> TC358764 -> panel-lvds,
and sets `msm.separate_gpu_kms=0` on the SD second-stage command line.
It starts multi-user.target so SSH and USB console can be checked before KWin.
Generic fbdev emulation is disabled to keep probe and first modeset separate.
The appended DT bootargs are authoritative on this bootstrap path; changing
only the separate kexec.cmdline file did not change the observed bootargs.

TEMPORARY DIAGNOSTIC ONLY: `tc358764.firmware_power=1` preserves the
bootloader's bridge power. This explicitly bypasses regulator management
only for the Samsung profile. It must be replaced with verified power wiring;
suspend, panel power cycling and production readiness are not established.
Missing bridge supply phandles in the diagnostic DT are a known schema
limitation, not evidence that supplies are absent electrically.

Verified recovery snapshots on the device:

- `/var/lib/t531/graphics-rollback`: original pre-graphics-experiment boot.
- `/var/lib/t531/native-kms-rollback`: improved, physically accepted fallback,
  modules and graphics configuration, all SHA256 verified before native work.

`sudo /usr/local/sbin/t531-graphics-rollback native` restores the latter SD
kernel and KWin device-selection configuration; then `sudo systemctl reboot`.
The helper checks model, SD label and partition size and writes only
`mmcblk1p1` (T531_BOOT). eMMC, internal bootstrap and recovery are unchanged.
USB serial root console provides recovery when SSH is unavailable.
The ARM decompression/FDT placement guard still applies to native builds.

All configurations currently share the release string `7.2.9-dirty`.
Overlay extraction left obsolete modules after options became built-in and
caused duplicate-symbol load failures. `install-graphics-modules.sh` checks
the build's complete file manifest and replaces the whole release directory,
retaining the preceding tree. Both rollback helpers likewise replace whole
trees. An archive overlay is insufficient even when depmod succeeds.

## Interconnect work

VERIFIED_VENDOR_SOURCE: CPU -> BIMC -> EBI; GPU/MDP -> MMSS NoC -> BIMC ->
EBI. MMSS uses the HLOS MMSS AXI root; BIMC uses RPM MEM clock resource0.
GPU also has an OCMEM path, RPM MEM clock resource2. The existing temporary
GPU AXI callback must be disabled when ICC paths are supplied, so GPU and MDP
cannot independently overwrite a shared root clock rate.

Native display and ICC must be measured independently. A successful build,
DRM probe or timer-derived FPS is not physical acceptance or proof of tear-free
60 Hz. Record real vblank/page-flip events, GPU/CPU load, clocks, faults,
underflows and physical color/touch/backlight observations after deployment.

`NATIVE_KMS=1 NATIVE_ICC=1 scripts/build.sh` selects a separate ICC DT and
fragment. Initial CPU/GPU/MDP paths, OPP bandwidth and OCMEM allocator votes
are implemented but pending device validation. MMSS/OCMEM rate conversion
uses the downstream slave clock domain, 16 bytes; CPU/BIMC/DDR uses8 bytes.
Firmware QoS is retained; other SoC fabrics are not modeled yet. MDP still
holds a conservative lifetime bandwidth vote (4.256 GB/s on MSM8226), so
idle power optimization and dynamic scanout votes are unfinished.

## DSI parent-clock experiment

Patch0065 is a project adaptation of the established CCF
`CLK_OPS_PARENT_ENABLE` mechanism, limited to MSM8226 pixel0/byte0 roots.
Reference: upstream commit acf7a91d0b0e; analogous SDM660 v2 report by
Fabricio Akio, 2026-10-02, https://lkml.iu.edu/2610.0/04606.html
(review discussion https://lkml.iu.edu/2610.0/07791.html). This does not
import that SDM660 patch or assume identical PHY hardware.
VERIFIED_DEVICE: build, SD deployment and boot-layout check passed. First
controlled modeset no longer emits the pixel/byte RCG warnings. Active PLL
readback shows locked VCO445439648 Hz, byte55679956 Hz, pixel74239942 Hz.
Bridge read still fails with EIO; FIFO IRQ storm and one MDP underrun remain.
The kernel is untainted in this modeset test. This is a partial clock fix,
not working display or measured FPS.

The PLL clock-summary Oops leaves a CCF lock held: subsequent clock and
SD I/O operations can block. Do not continue hardware experiments in this
boot. The trace was captured on the host before reset; recovery requires
a reboot, with the verified RAM-only rescue available if SD boot fails.

VERIFIED_DEVICE: while native scanout is active, context0 at fd930000
reads zero for SCTLR, TTBR0, TCR, MAIR and fault status. The registered
software IOMMU domain therefore has no active hardware translation at that
point. HYPOTHESIS: MSM8226 SCM restore/power cycling erases context state
that qcom_iommu programmed at attach. Next isolated experiment holds the
IOMMU runtime-active before loading DRM and compares context readback;
this is a temporary diagnostic power hold, not an acceptable permanent fix.

VERIFIED_DEVICE: holding IOMMU runtime-active before DRM load preserves
SCTLR0x10e7, TTBR0 and TCR0x80802020. A 20-second modetest page-flip test
then reports sustained59.98–59.99 Hz after the first60.92 Hz sample, with
no MDP underruns in that test. The bridge's first DSI command still times
out, and the FIFO IRQ storm remains. This is a real DRM page-flip frequency,
not proof of LCD output or GUI FPS.

Patch0066 selectively imports Dmitry Baryshkov's v1 context-cache helper,
Message-ID `20260809-msm8974-iommu-upstream-v1-3-87f5cd492560@oss.qualcomm.com`,
with original authorship, Assisted-by and Signed-off-by preserved. Checked
2026-10-14: pinned kernel lacks it; no newer revision was found in the
upstream-thread searches. Recheck before upstreaming/releasing. Patch0067
adapts context replay to this board's TZ-managed IOMMU, leaving secure
register ownership intact and avoiding a permanent runtime-power hold.

VERIFIED_DEVICE: patch0067 was tested independently with power/control=auto,
without the temporary runtime hold. After modeset the context retains
SCTLR0x10e7 and its TTBR/TCR/MAIR. The 15-second native page-flip test again
reports59.98–59.99 Hz after the initial sample. No IOMMU fault was seen;
one MDP underrun appeared at modeset startup, with no recurring underruns
during steady page flips. DSI commands and the LCD are still broken.

Patch0068 adds error-only DSI timeout/read-header evidence. Patch0069 models
the factory DSI command-fetch clock setting (DSI_CLK_CTRL0x23f, including
FORCE_ON_DYN_AHBM_HCLKbit9) as an MSM8226 host quirk. It is a hypothesis for
the remaining command DMA failure, pending its own device experiment.

Patch0069 test: command receive completes but returns response type0 and
zero bytes; bridge initialization fails with EIO. Page flips remain near60Hz,
with an initial MDP underrun and persistent DSI FIFO interrupts. This does
not prove that bit9 fixes the intermittent DMA timeout. Read-only I2C probe
after modeset now receives ENXIO at the previously verified0x0f address.
TLMM51 is physically output-high (reset deasserted), TLMM25 output-high,
PM8226GPIO2 output-high; the I2C pins return to unclaimed input-high.
Power/reset/strap/clock sequencing of the bridge remains under investigation.

Bridge isolation on the current native kernel: before DRM load, read-only
I2C returns ID0x6500 and the factory configuration. After DRM probe alone
(no modeset/reset sequence) it no longer ACKs. Its external enable GPIOs
remain high. This does not by itself prove a lost supply: I2C accessibility
may depend on the bridge clock, which is removed when MDSS powers down.

VERIFIED_DEVICE: active PHY regulator controls read [07 09 03 00 20 00 01],
whereas the exact factory panel/host source specifies [07 08 07 00 20 07 01].
PHY BIST controls already retain [00 00 b1 ff 00 00]; do not change them
speculatively. Patch0070 applies the three differing internal DCDC control
values under the existing MSM8226 quirk. External PMIC voltages and wiring
are not altered. Its device result is pending.

VERIFIED_DEVICE: patch0070 readback matches factory regulator controls,
but the bridge still returns zero DSI response and no I2C ACK after native
modeset. It is not a demonstrated fix for output. Patch0071 tests the exact
Samsung write-first PPI/DSI configuration sequence, avoiding the blocking
pre-configuration BTA read for Matisse only; all write errors remain fatal.
This experiment needs register readback and physical acceptance.

Patch0071 test stops at the first configuration write with EIO. Code
inspection found a separate host API mismatch: MSM returns the padded DMA
packet length12 for payload6, which the bridge's exact-length check rejects.
Patch0072 retains internal DMA-size checks and returns tx_len to callers.
The initial read failure and this write-length mismatch are distinct faults.

Patch0072 test: no bridge initialization error and all configuration writes
report successful payload counts. Real flips stay near60Hz. FIFO IRQ storm
and an initial underrun remain; I2C still returns ENXIO after modeset.
VERIFIED_DEVICE (owner observation, 2026-10-14): screen black, backlight on,
no test pattern. Native LCD output has NOT passed acceptance.

Patch0073 is an opt-in diagnostic (`msm.matisse_lp11_reset=1`), restricted
to the Matisse TC358764 compatible. The exact factory `mdss_dsi_on()` holds
LANE_CTRL bits20:16 while the bridge reset toggles, then requests HS clock.
This experiment delays the HS clock request until the first bridge command,
after reset. It remains disabled by default and is not a production
link-power API. Patch0074 adds rate-limited raw error-register evidence;
IRQ masks and acknowledgements are unchanged.

Earlier register snapshots after modetest exit have a significant limit:
the CRTC remains active but its plane framebuffer has already been freed.
FIFO errors in that state cannot alone establish an underrun during the
page-flip test. Subsequent snapshots must be collected while modetest
still owns and flips its framebuffer.

Toshiba product brief Rev1.33 (2018-04-04), retrieved via web2026-10-14:
https://toshiba.semicon-storage.com/info/docget.jsp?did=36679&prodName=TC358764XBG
confirms DSI generic-long-write/I2C configuration and DSI-derived or external
LVDS clock. This brief is not a complete register or reset-sequence manual.

VERIFIED_DEVICE: patch0073 enabled with patch0074 logging, first bridge
write now times out with DMA address0x1000/12bytes, FIFO0x33333000,
STATUS0x3. During a held, actively flipping framebuffer, FIFO remains
0x33333000 and STATUS0x0b. The owner confirmed black screen/backlight ON
while modetest was alive (PID1181). Flips remain approximately60Hz. The
LP11 reset diagnostic has NOT fixed the link. No later screen observation
should be used as active-buffer evidence without confirming test lifetime.

VERIFIED_VENDOR_SOURCE: per-data-lane PHY_CFG4 values in the exact Matisse
DTS are [00,05,0a,0f]; active native readback is [00,00,00,00]. The other
8bytes per lane match. Patch0075 applies the three differing values to
MSM8226 only. Their electrical function is not inferred from the register
name. This is a justified isolated comparison, not yet a demonstrated fix.
Next test disables the LP11 diagnostic to isolate the PHY change.

VERIFIED_DEVICE: the LP11 reset test restores I2C ACK while the native
mode is active. ID is0x6500, and bridge register values are reset defaults
(PPI lane enable3, DSI lane enable2, LV_CFG0xa00). Thus software command
completion from the earlier test was NOT verified bridge configuration.
A bounded diagnostic I2C writer, guarded by board compatible and ID,
then writes the27 exact factory commands with all transfers ACKed and
critical registers read back correctly. GPIO adapter is removed afterward.
The active DSI FIFO still reads0x33333000. Physical output remains pending
this specific I2C experiment; no KWin FPS is claimed.
Owner observation while the held test was alive: the I2C factory-profile
configuration still leaves the LCD black, with backlight working. This
experiment has failed physical output acceptance.

VERIFIED_DEVICE: patch0075 with the LP11 diagnostic OFF reads per-lane
CFG4 [00,05,0a,0f] as intended, but owner confirms black LCD during the
held test. Active FIFO alternates0x11111000 (empty) and0x88881000 (four
HS lane underflows); error work repeats roughly80k/sec. ACK/timeout error
registers are zero, PLL remains locked. MMSS_MISC clamp0x14 and PHY power
collapse0x108 both read zero, so no stale external clamp was observed.
Native display acceptance still fails; the per-lane change alone is not
an output fix. Test does not validate actual MDP pixel fetch.

Patch0076 adds an opt-in Matisse-only video-order diagnostic
(`msm.matisse_defer_video=1`): host power/clocks and command access remain
available in pre_enable; video starts in the host bridge's enable callback,
after downstream pre_enable. This tests whether video arbitration blocks
configuration before any video frame is supplied. It is OFF by default.
No undocumented PHY or secure-IOMMU register writes are introduced.

VERIFIED_DEVICE: patch0076 with LP11/deferred video enabled still times
out on the first write (FIFO0x11111000 at timeout). The bridge ACKs I2C,
but reads reset defaults. Factory I2C writes again succeed and read back.
Active DSI shows CMD_DMA_BUSY retained and FIFO0x55551000 (HS lane overflow
flags). Thus delaying the video engine does not fix command transfer.
No physical improvement is established by this test.

Patch0077 exposes `matisse_dsi_link` under DRM debugfs only when explicitly
requested with `msm.matisse_link_diag=1` on Matisse. Write2 resets the
controller through its existing driver helper, preserving CLK_CTRL;
write1 enables the existing DSI test pattern; write0 disables it. Operations
are serialized with modesets/commands and hold runtime power while the IRQ
is disabled and error work drained. A disabled/powered-off host is rejected.
This is temporary diagnosis, not a production interface.

REGRESSION: the first patch0077 diagnostic used disable_irq() on the live
DSI virtual IRQ. Its reset operation stopped SSH and USB console response;
a physical Power reset was required. Pstore was empty after that reset,
and the saved previous journal contains no panic trace. Code inspection
found MDSS irq_mask only changes enabled_mask in software; it does not
mask the asserted DSI peripheral source. This is the evidenced suspected
cause of the diagnostic hang, not a recovered panic diagnosis.

Patch0077 corrected implementation masks the DSI peripheral source first,
synchronizes the handler and drains error work, without disabling the
virtual IRQ. The host interrupt helper prevents error work from unmasking
the source while the diagnostic runs. Source masks are restored afterward.
The previous implementation is rejected. Hardware re-test is pending.

VERIFIED_DEVICE: current SD kernel container SHA matches the new build
exactly; only the unloaded MSM module changed. The corrected module tree
can therefore be installed without another reboot or changing boot files.

VERIFIED_DEVICE: corrected patch0077 rejects invalid command3 with EINVAL
and reset of the powered-off host with EBUSY. Active-controller reset2
and test-pattern enable1/disable0 each return successfully; SSH stays up.
Reset clears CMD_DMA_BUSY (STATUS0 becomes0x8). The bridge factory profile
was verified over I2C beforehand. DSI IRQ underflows still recur.

VERIFIED_DEVICE (owner): after native DSI test-pattern enable, thin vertical
stripes become visible at the left of the LCD. After disabling the internal
generator, more stripes appear beyond the left edge while modetest remains
active. This is the first physical evidence of native output pixels, not
a complete or correctly rendered image. Native LCD acceptance stays false.
Patch0078 adds fixed blue/green/red/white choices3..6 using VID_FIXED,
to separate general-pattern geometry from link or pixel corruption.

Patch0078 fixed-white test reads TPG_CTRL0x21, INIT_VAL0xffffff and
VIDEO_CONFIG5, but the owner reports a fully black LCD with working
backlight. A successful register write does not establish generator
function or correct link. The internal generator's independence from MDP
qualifiers on this DSI revision has not been established; this negative
test alone cannot rule out MDP/IOMMU.

VERIFIED_VENDOR_SOURCE: `lineage_matisse3g_defconfig` at the pinned BSP
uses MSM_IOMMU_V1, and `msm_iommu-v1.c::__program_context()` programs short
ARMv7 descriptors (TTBCR0, TTBR0, PRRR/NMRR). The separately device-verified
GPU contexts also use short descriptors and require AFE clear (patch0017).
The newly added MDP qcom_iommu path instead always allocated ARM32_LPAE_S1.
HYPOTHESIS: the format mismatch contributes to command/pixel DMA failure.
Patch0079 selects the maintained ARM_V7S backend for MSM8226 only, including
NS descriptors, CONTEXTIDR and full AP permissions; other SoCs keep LPAE.
No secure global-register access is added.

VERIFIED_DEVICE: patch0079 reads SCTLR0x10e3, TTBR00x06eec002,
TCR0, PRRR0x800b8204 and NMRR0x40004000. The native link still produces
DSI FIFO underruns and the owner reports black. An architectural MDP
translation request times out after100ms; vblank timeouts appear afterwards.
The first failed module load was not captured live, so its PAR result is
unknown. No claim of successful hardware translation is made.

VERIFIED_VENDOR_SOURCE: Samsung `msm8226-iommu.dtsi` provides an18-entry
MDP BFB table. `msm_iommu_sec.c` explicitly programs it from HLOS following
TrustZone configuration. VERIFIED_DEVICE: the allowlisted implementation
registers at fd92a000 are accessible without reading protected global IDR0.
Readback at offsets514/540/20c/394/414 is zero, and15c is0x00e8743a;
the respective factory values are4/0x10/0x17/0x13/0x23 and0x13.

Patch0080 adapts the BFB helper/table infrastructure from Dmitry Baryshkov's
MSM8974 series v1 patch10, Message-ID
`20260809-msm8974-iommu-upstream-v1-10-87f5cd492560@oss.qualcomm.com`.
Revision search on2026-10-14 found no newer revision. It maps a named
implementation-only resource, preserves the MSM8916 local-register path,
and replays BFB after both SCM call sites. Patch0081 selects the exact
MSM8226 MDP table and exposes only its HLOS implementation window in DT.
This is a measured initialization mismatch; its contribution to the black
LCD remains HYPOTHESIS until the new device test.


VERIFIED_DEVICE: patch0081 restores every allowlisted factory BFB entry;
MICRO_MMU_CTRL reads8 (idle). Probe TLBSYNC and first-command DMA timeout
are absent in the captured test, but bridge I2C ID reads0 and configuration
remains reset defaults. Modetest reports59.98..60.00Hz before a hardware
translation query. Query IOVA1000 returns PAR0x0000000280000003,
ATSR1, FSR0 and ETIMEDOUT after100ms, followed by vblank timeouts.
Owner sees a possible image briefly, then black. LCD acceptance remains false.
SCM IO read of protected global IDR0 returns-4; no direct global read was
attempted. This firmware service did not provide register contents.

VERIFIED_DEVICE: complete-module-tree fallback restore succeeds and the
owner confirms the saved Plasma system works perfectly. A bounded register
reader successfully captures the running firmware display configuration.
The first reader included MMSS_MISC@fd828014, which raised user SIGBUS
because that separate resource was inaccessible in this profile; buffered
output was lost. Removing that resource and flushing each line gives a
complete DSI/MDP/PLL/PHY snapshot, exit0. Do not repeat the inaccessible read.
Working PHY internal regulator controls are[07 09 03 00 20 00 01], despite
the vendor panel DT's[07 08 07 00 20 07 01]. Hardware takes precedence.
Working PLL SDM_CFG1/2/3 are0x0a/0x4f/0xed (about458MHz), whereas native
uses0x4a/0x99/0x99 (about445.44MHz). Firmware PHY timing bytes exactly match
the vendor panel:[74 1c 1c 00 36 36 1d 1d 20 03 04 00]. Native uses computed
timings. DSI video and MDP timing registers already match the working values.
These differences motivate separate controlled link tests; they do not
establish which difference causes the missing native image.


Patch0082 backports per-instance terminate fault policy from Dmitry
Baryshkov's v1 patch09, preserving authorship/Assisted-by and Message-ID
`20260809-msm8974-iommu-upstream-v1-9-87f5cd492560@oss.qualcomm.com`.
Patch0083 selects it for MSM8226 MDP only. The exact BSP context reset and
program sequence does not enable CFCFG; upstream previously enabled stall.
Fault reporting remains enabled. Device comparison is pending.

Firmware pixel/byte RCG CFG registers both read0x100, with no fractional
mode enabled. PLL postdiv3=5 means458MHz/6=76.33MHz, so the firmware's
actual refresh is plausibly about61.68Hz for1378x898 totals. This is an
inference from registers, not a measured refresh; simpledrm's reported60Hz
cannot verify the hardware timing. Do not call the factory link458MHz
an overclock.


VERIFIED_DEVICE: patch0083 context SCTLR reads0x1063. ATOS polling completes
for IOVA1000/2000/100000, but all PAR values are0x0000000280000003.
The exact BSP header decodes F=1, TF=1, ATOT=1 and PLVL=2; there is still
an actual translation failure, not a usable mapping. ATOS hardware error
must be distinguished from the earlier software polling timeout. The first
DSI command again times out in this boot; disappearing timeout in the
patch0081 test was not repeatably established as a fix.
Patch0087 adds the missing BSP ACTLR cache-routing bits28..30 while the
context is disabled, preserving other instances. Its result is pending.

Patch0084 documents the implementation-only resource; patch0085 fixes the
unit address without hardware changes. Patch0086 exposes an off-by-default,
Matisse-only PHY comparison parameter: bit0 firmware timing, bit1 captured
working regulator controls. It permits isolated comparisons. It is present in patch0087 builds but
is still off and has not been tested. This is not an accepted production profile.


VERIFIED_DEVICE: patch0087 ACTLR reads0x70000000. CPU reads of the table
at TTBR0 show valid coarse descriptors and mapped L2 entries matching the
software translations. ATOS completes but PAR remains0xa290 for all three
IOVAs, so hardware translation still does not match. Repeating with the
BSP's full memory barrier and10us settling gives the same mismatch.
Probe TLBSYNC and first DSI DMA timeout recur. No LCD fix is claimed.

VERIFIED_VENDOR_SOURCE: clock-8226.c maps fd928000 IOMMU iface to MDSS AHB
and core to MDSS AXI, matching our DT. The BSP has CONFIG_IOMMU_PGTABLES_L2
unset: assuming coherent table walks would not match its configuration.
BSP attach halts MICRO_MMU_CTRL, resets the context including TLBIALL,
programs it, then resumes. Patch0088 adapts Dmitry Baryshkov v1 patch08
with a100ms bounded handshake and fail-safe error propagation; patch0089
selects it for MSM8226. Patch0090 restores context-local TLBIALL at0x618
while halted/disabled. Secure global registers remain untouched.

Sam Day's2026-09-28 v1 fix provides independent upstream evidence that
qcom_iommu reprogramming TTBRs without invalidation can keep stale entries
across kexec, causing blue MDP5 output/underrun storms on MSM8916. It is
not device evidence for MSM8226. Message-ID:
`20260928-qcom-iommu-clean-contexts-v1-1-c88fe2b4ff48@samcday.com`.
Our reset operation follows the exact MSM8226 BSP; test is pending.


VERIFIED_DEVICE: patch0090 probes without a recorded halt/TLBSYNC timeout.
Held modetest remains about60Hz, but hardware translations still differ:
IOVA1000/2000/100000 return PAR03e01290/03e02290/03f00290, corresponding
to physical03e00000+IOVA, while software points at303f7000/304e8000/306fa000.
This resembles retained firmware mappings; their origin is HYPOTHESIS.
A fixed one-register userspace CBAR0 read atfd929000 raises SIGBUS, with
Linux/SSH still running. No driver/global-register write was attempted;
do not repeat protected GR1 reads.

VERIFIED_VENDOR_SOURCE: BSP msm_iommu_assign_ASID() allocates namespace IDs
starting at1, separately from CB0. Patch0091 separates page-table ASID1
from DT/context index0 for MSM8226 and keeps TLB maintenance consistent.
Patch0092 adapts Sam Day's context-ASID invalidation and bounded synchronization
before initialization, preserving authorship and metadata and propagating
failure. This completes further missing context-reset steps; test is pending.


VERIFIED_DEVICE: patch0092 CONTEXTIDR reads1 and probe synchronization
completes, but all ATOS operations return0x0000000280000003, including
hardware timeout at page level2. CPU reads valid coarse L1 entries ending409
and009 and correct mapped L2 descriptors. Native acceptance remains false.

VERIFIED_VENDOR_SOURCE: exact msm_iommu_pagetable.c::make_second_level()
installs only the aligned physical table address and FL_TYPE_TABLE=1;
it does not set coarse descriptor NS bit3. Upstream MSM8974 v1 patch04
also leaves ARM_NS unset. Patch0079's MDP adaptation added that quirk
without checking the display BSP descriptors. The current arm-smmu GPU
code does not itself set ARM_NS either; the previous rationale was unsupported.
Patch0093 removes it for the TZ-managed MDP, so coarse entries should end401
and001. This isolates a real descriptor mismatch; device result is pending.
The working GPU driver/table setup is unchanged.

Latest upstream review of Sam Day v1 recommends context-local TLBIALL at
probe; no v2 was found in the2026-10-14 revision search. Preserve the v1
metadata when evaluating this temporary adaptation. The exact MSM8226
BSP reset already uses context-local TLBIALL; patch0090 follows that fact.


VERIFIED_DEVICE: patch0093 L1 coarse descriptors now end801/401 (NS bit3
clear), as the BSP encodes them. Hardware nevertheless returns the same
level2 ATOT result. This corrects an unsupported flag assumption but is
not a demonstrated output fix. All other prior PHY/clocks remain unchanged.

VERIFIED_VENDOR_SOURCE: BSP attach applies its MDP->EBI bus vote before
clocks/context setup. It also allocates4KB L2 table pages, whereas the
maintained ARM_V7S backend uses1KB slab objects (our captured table bases
include offsets400/800 within a page). The significance of this allocation
difference is UNKNOWN, not a declared hardware erratum. Research did not
find authoritative evidence of an MSM8226 MDP1KB alignment limitation.
A separate native ICC profile test is being prepared to evaluate the missing
memory-fabric votes before adding any table-allocation quirk.


VERIFIED_DEVICE: first native ICC profile boots with working USB/SSH.
CPU peak4264000kBps and MDP peak4256000kBps appear in interconnect_summary;
MMSS AXI and MDSS AXI read266666666Hz while the native mode holds PHY active.
RPM bandwidth resources master55/slave16 return ENXIO and are ignored by the
board-limited policy, as prepared. Clock/bandwidth votes are not measurements
of actual DDR PLL frequency; that frequency remains UNKNOWN. Hardware ATOS
still fails at level2 for nine IOVAs through7MB, including L2 tables aligned
at0,400,800,c00 within4KB. Alignment alone is not supported as the cause;
no4KB allocation quirk is added.

Patch0094 exposes the BSP's legacy utility-service3/command0xc context
diagnostic through SCM, not direct reads of protected globals. It uses a
coherent bounded32-bit-addressable buffer, rejects other SCM conventions,
and has no automatic IOMMU-driver caller. The board-limited temporary tool
requests instance1/CB0 only and validates returned length/pair alignment.
This is a firmware diagnostic experiment; its result is pending.


VERIFIED_DEVICE: patch0094 firmware context-dump request returns -95
(EOPNOTSUPP), zero bytes. SCM convention is legacy according to the boot
log, so this is the firmware transport result, not the ABI guard. No
register snapshot was obtained. Do not bypass protected global access
restrictions or force an alternative calling convention from this result.

VERIFIED_DEVICE (owner observation): blue appears after kexec into the SD
kernel, apparently during boot logging, then the screen becomes black with
backlight. The owner clarifies this describes all prior native trials;
there is no accepted visible improvement. Neither blue nor black proves
a kernel panic; the latest trial retains USB/SSH access.

VERIFIED_VENDOR_SOURCE: shipped lineage_matisse3g_defconfig disables
CONFIG_IOMMU_PGTABLES_L2; __program_context() only sets TTBR0 attributes
when pt.redirect is true. For the shipped noncoherent path all TTBR0
attribute bits, including shareability, are clear. Patch0095 clears the
extra TTBR0.S supplied by ARM_V7S for this display instance only. DMA
page-table cache maintenance remains enabled. This tests one remaining
BSP difference; hardware result is pending.

VERIFIED_DEVICE: patch0095 TTBR0 reads0x0b09c000, without S or cache
attribute bits, matching the shipped BSP path. All nine mapped ATOS
queries still return0x0000000280000003. This mismatch alone does not
explain the failure. DSI HS FIFO underflow remains.

Patch0096 exposes the BSP-supported64KB/1MB mapping sizes for the short
descriptor instance. The temporary t531_mdp_section module maps its own
aligned1MB RAM allocation at a checked unused high IOVA through the
normal IOMMU API, verifies an actual L1 section descriptor, queries ATOS
and unmaps/frees it before returning. No page-table edits, protected
global reads, framebuffer changes or context-register reprogramming are
used. Run only with Plasma stopped and the held diagnostic modeset.
This will distinguish single-level section translation from the failing
L2-table walks; result pending.


VERIFIED_DEVICE: patch0096 section map at IOVA 0xf0000000 has an actual
L1 section descriptor 0x0b931c02, mapping RAM at 0x0b900000. ATOS returns
0x03e00290, 0x03e01290, 0x03eff290 for offsets 0, 4KB, 1020KB. After
normal iommu_unmap() and TLB synchronization it still returns 0x03e00290
without a fault. The result does not track the Linux mapping or its
removal. This rules out explaining all observed behavior solely by L2
table alignment. An inherited mapping or an ineffective diagnostic query
remains a HYPOTHESIS; this does not identify the origin of 0x03e00000.

The concurrent I2C snapshot returned chip ID 0 instead of the verified
0x6500. Its subsequent apparent configuration values are not accepted
as register evidence: a successful I2C transaction does not establish
a valid snapshot. The read-only reader now stops on an invalid ID, as
the writer already does. This test changed no bridge settings.

VERIFIED_VENDOR_SOURCE: msm_iommu_sec_init() calls shared secure-table
initialization at subsys_initcall for any enabled secure-ID IOMMU,
independently of secure context usage. Our DT has only non-secure CB0,
so qcom_iommu_has_secure_context() skipped the existing shared TZ helper.
Patch0097 requests that once-only helper for MSM8226 match data even
without a secure child. Firmware errors stay fatal; production/fallback
DT does not enable this instance. Hardware result pending.

The BSP additionally adjusts the secure CP pool for MP feature versions
>=1.1.1 before asking for the shared-table size. That feature version has
not been measured on this firmware; patch0097 currently uses the existing
maintained Linux size/init helper and does not invent a pool-size vote.


VERIFIED_DEVICE: patch0097 firmware asks for 90112 bytes of shared TZ
tables. Nine existing mapped IOVAs now translate to their exact Linux
physical pages. A1MB section maps RAM0x0b200000: offsets0/4KB/1020KB
translate correctly; after unmap PAR0x000000018b2ff283 has its fault bit
set. The section diagnostic returns success. Unlike patch0096, hardware
now tracks both creation and removal of the Linux mapping. This is a
measured fix to the MDP address-translation blocker, not physical output
acceptance. Owner confirms black screen with backlight in the held test.

VERIFIED_DEVICE: I2C chip ID0x6500 and all stored factory configuration
values (timers, lane masks, video timings, LVDS mux/config/PHY) now match
the working firmware snapshot after native DSI initialization. Command
completion plus correct readback establishes configuration delivery.
Native video still reports HS FIFO underflow; panel output remains false.

After shared TZ initialization the reserved CB0 register at offset0x10
returns userspace SIGBUS on read. The unbuffered diagnostic locates the
failure there; preceding SCTLR/ACTLR are readable. This is not a kernel
panic. TCR2 is absent from the short-descriptor BSP path and the upstream
format proposal programs it only for LPAE. The ignored local reader now
skips0x10. The kernel's unconditional TCR2 write needs to be restricted
to its LPAE path.


Patch0098 restricts the unsupported TCR2 write to LPAE contexts. The
native ICC build boots with empty pstore and working USB/SSH. Shared TZ
table size again90112 bytes. Saved the page-translation-accepted0097
kernel/initramfs/cmdline/hash and its whole module archive separately at
/var/lib/t531/native-iommu-0097; the physically accepted Plasma rollback
remains unchanged at /var/lib/t531/native-kms-rollback.

VERIFIED_DEVICE: simply setting the writable PHY profile parameter and
terminating legacy modetest did NOT apply the profile. Its active CRTC
persisted and the PHY remained powered. Readback detects this, so that
trial is not a profile result. Fresh0098 boot with profile3 before the
first modeset logs the profile and reads exact working timing/DCDC bytes.
HS FIFO underflow persists.

VERIFIED_UPSTREAM: libdrm2.4.124 modetest set_property() queues -w
properties into an atomic request when -a is used; the final commit
runs even without -s. Source (MIT license):
https://gitlab.freedesktop.org/mesa/drm/-/blob/libdrm-2.4.124/tests/modetest/modetest.c
VERIFIED_DEVICE: after stopping the held test,
modetest -M msm -a -w55:ACTIVE:0 sets CRTC active=0 and the PHY runtime
state becomes suspended. Do not read PLL/clock-summary registers there.
This permits real power-cycle comparisons without a kernel reboot.

VERIFIED_DEVICE: profile3 plus custom native mode
1280,1328,1330,1378,800,832,834,898-61.6847@XR24 requests76331kHz
(libdrm's parsing/rounding), yielding about61.67..61.68Hz flips. PLL
SDM1=0x4a, seed0xed0e (working firmware0x0a/0xed4f); DSI HS FIFO
underflow remains. Physical response for this exact mode is pending.

VERIFIED_VENDOR_SOURCE: clock-mdss-8974.c::vco_set_rate() shared by
dsi_vco_clk_8226 programs CAL_CFG4=0x66, VCOLPF_CFG=0x71, and builds
SDM_CFG1 from its DC offset without retaining DITHER_EN. Mainline
currently uses0x06/0x31 and preserves the reset dither bit. Our accepted
firmware snapshot also has dither clear. Source commit3fa1853, GPL2:
https://github.com/LineageOS/android_kernel_samsung_msm8226/blob/3fa1853ed5d6c3a8ef5a2fda9822705243bbc256/arch/arm/mach-msm/clock-mdss-8974.c
Patch0099 adds a separate off-by-default Matisse diagnostic PLL bit4
(combine to profile7). It changes those controls, not requested rate or
dividers; hardware result pending. No DDR clock is programmed by it.

VERIFIED_DEVICE (patch0099, profile7): factory PLL controls read back0x0a
(SDM1),0x66(CAL4),0x71(VCOLPF). Nine hardware IOMMU translations still
match Linux, but display is incomplete and HS FIFO underflow persists.
The powered PLL VREG_CFG reads0, while CCF caches indirect VCO/DIV1/2
as dsi0byte_mux parent. DIV1=1 and final /4 imply a physical byte clock
about114.49MHz rather than CCF's57.244775MHz. This frequency follows
register topology; it is not an independent frequency measurement.

VERIFIED_VENDOR_SOURCE: set_byte_mux_sel() writes bit1, and mux_prepare()
replays the cached parent's selector after display registers are wiped.
VERIFIED_DEVICE: the temporary tools/native-clock-diag module uses CCF
to select direct then the cached indirect parent. VREG_CFG changes0→2,
while the final CCF byte rate remains57244775Hz. The owner immediately
confirms the native modetest colour test pattern. This is the first
physical native pattern acceptance; native Plasma/FPS remain pending.
The held test's already-running DSI still reports FIFO flags; a5-second
sample after reconciliation measures61.779 MDP IRQ/s,1099.426 DSI IRQ/s,
and1.208% aggregate CPU busy. Before reconciliation, rate-limited error
logs report about400000 suppressed callbacks per5seconds. These are
unequal measurements, not a precise IRQ before/after benchmark.

Patch0100 restores the selected CCF parent in the MSM8226 mux prepare
callback, after its VCO parent prepares. It does not force a particular
parent, change rates/voltages, or program DDR. Build and checkpatch pass;
a fresh native activation is pending. Saved0099 boot files (verified
kernel hashes) and its whole module archive at
/var/lib/t531/native-visible-0099; this snapshot still requires the live
mux diagnostic to show an image. The physically accepted0046 rollback
remains separate and unchanged.

Patch0100 is built and deployed with its exact MSM module SHA verified on
the tablet. First activation at23seconds fails before modesetting:
ARM32 arch_setup_dma_ops() attaches its DMA domain while firmware output
is inherited, and TLBSYNC times out twice. The later MDP domain also
fails ETIMEDOUT despite the driver's timing-engine stop. Thus the new
mux prepare callback has not yet received physical repeat acceptance.

A single module-unload/reprobe attempt triggers an external abort at
PHY PLL status while CCF reparents clocks during provider removal. It
leaves CCF/storage operations blocked; avoid reloading MSM after this
failure. Owner entered lk2nd fastboot; the SHA-verified rescue image was
loaded only into RAM and recovery remains available. Raw Oops logs are
kept privately, without committing hardware identifiers. This is an
additional lifecycle defect, not a regression claim about mux replay.

The planned iommu.passthrough command-line trial was not written: after
that Oops, storage blocked before the command reached the SD update.
Rescue readback confirms the unchanged command line. Moreover ARM32
arch_setup_dma_ops() unconditionally creates its own DMA mapping for
IOMMU clients; changing only the generic default domain would not
necessarily avoid this early attachment. Do not report that trial as run.

VERIFIED_VENDOR_SOURCE: MSM8226 __program_context() invalidates/programs
under micro-MMU halt, then the caller resumes it. __sync_tlb() runs in
separate unhalted flush paths. Our patch0092 combined a pre-init sync
with a halted programming helper. Patch0101 retains invalidation and
bounded completion but waits after unhalt; on failure it disables the
context before the new page tables can be freed. Non-halted instances
retain their previous ordering. This candidate is being built; root
cause of the startup timeouts is still HYPOTHESIS until the device test.

VERIFIED_DEVICE: patch0101 fresh native activation at uptime572.3s
registers DRM without TLBSYNC timeouts. Initial firmware-framebuffer
IOVAs0320xxxx fault until the MDP driver stops the inherited scanout;
that handoff still needs cleanup. First native test automatically reads
VREG_CFG=2 and flips61.67..61.68Hz. Owner confirms full colour pattern
without the live clock diagnostic. Plasma then uses native card0 with
DMA0 scanout; owner confirms normal image, but touch is not responding.

The touchscreen remains enumerated and its IRQ count grows; this does
not alone prove processed touch events. Plasma logs repeated Adreno
hangcheck/recovery and GL_CONTEXT_LOST, with devfreq mostly19MHz.
The first graphics profile was INVALID because root-only750 staging
directories prevented the user workload from reading QML; its apparent
2.23FPS is not accepted as a workload measurement. The corrected staged
workload's second recording has insufficient frames during GPU recovery;
no native FPS result is accepted yet. Preserve GPU coredump privately.
A reversible450MHz minimum-frequency trial and fresh graphical session
are now being tested; DDR frequencies are untouched.

VERIFIED_DEVICE: evdev records908 touchscreen events during owner
finger movement, with multitouch coordinates, pressure and release.
The frozen desktop is therefore not evidence of a dead touchscreen
controller. Fixed GPU minimum450MHz and a fresh graphical session do
not prevent repeat Adreno ringbuffer hangs. Holding GPU runtime power
on also does not restore stable operation in that already-faulted boot.
Neither trial supplies valid FPS. Next isolation keeps native KMS fixes
but removes the optional native ICC DT/profile; the fallback AXI OPP
callback has been physically tested with accelerated Plasma previously.

VERIFIED_DEVICE: native KMS without ICC, fixed450MHz GPU and power/control=on
before Plasma, also hangs during the corrected moving-square workload.
Owner sees the square briefly, then a frozen/black display. GPU IRQ count
stays10; repeated ringbuffer timeouts follow. No independent GPU SMMU
context fault appears. The profiler correctly rejects this recording.
Removing ICC is not a fix; retaining its measurements as UNKNOWN for
performance is necessary. Next reversible diagnostic separates native KMS
and GPU DRM ownership, preserving native MDP5 scanout. This is not a
return to simpledrm; shared-buffer import should be measured explicitly.

VERIFIED_DEVICE: separate_gpu_kms=1 at module load creates GPU card0/renderD128
and native msm-kms card1. This keeps MDP5/DSI scanout, not simpledrm. Mesa25
lacks the msm-kms loader entry; the existing generic platform DRI entry
selected by MESA_LOADER_DRIVER_OVERRIDE=mediatek initializes EGL1.5 and
Freedreno FD305. KWin confirms hardware EGL/FD305, native atomic60Hz output.
The colour buffer on native card1 is linear AB24, pitch5120, imported=yes,
hwpipeDMA0. This is a shared-buffer native scanout path, with no sysfb
RGB888 conversion. First corrected19second workload gives59.3625FPS,
p50=16.668ms,p95=16.681ms,p99=16.694ms, aggregateCPU29.892%, GPUbusy69.632%,
450MHz core and266.667MHz AXI. GPU submitted2268 measured jobs without
hangcheck in the recording. Owner physically confirms a smooth square,
but the desktop goes black after test exit. See native-first-frame-results.json.

The global override causes applications on the render node to attempt a
KMS dumb-buffer ioctl and fail EPERM; plasmashell crashes. Configuration
is now scoped to plasma-kwin_wayland.service only. Live environment check:
KWin has the override, plasmashell does not. Clients use ordinary Freedreno.
The later native scanout is linear AR24 imported=yes. A repeat workload
and physical touch/desktop acceptance are pending. Combined GPU/KMS
ownership failure remains unidentified; separated ownership is an existing
upstream feature, not a software-rendering workaround.

VERIFIED_DEVICE: KWin-only loader leaves native desktop, top tray and
touch working, physically confirmed. Ordinary clients and complete
Plasma give46.024FPS at fixed450MHz, GPU98.581%, CPU13.721%, p50=16.672ms,
p95=33.343ms. The earlier59.36 result used the global temporary loader
and an incomplete/crashing desktop, so it cannot be claimed as final
accelerated interface performance. Default GPU frequency range (min=0,
readback19MHz floor) remains stable:43.057FPS, GPU99.997%,
CPU9.237%. Runtime power auto also survives:42.981FPS,p95=33.345ms.
These are proper rejected-on-GPU-hang workloads; no hang during either.
Current production acceptance still excludes suspend/bridge power wiring.

A complete native-working0101-split snapshot with boot/kernel/module hashes
and three configuration files is saved at/var/lib/t531/native-working-0101-split.
It documents a proven profile, but its old boot container still requests
combined KMS until activation explicitly overrides the module parameter.
package-sd.sh now requests separate_gpu_kms=1 in both DT/boot command line.
A native-only boot activation service loads drivers after the SSH service,
waits for native display/render nodes, then starts SDDM. It does not force
GPU clocks/power and is skipped by the simpledrm fallback command line.
Cold automatic activation is pending with the restored ICC comparison.

## Native desktop and notification drawer follow-up, 2026-10-14

VERIFIED_DEVICE: the proper t531-mesa-msm-kms armhf package initializes EGL1.5
without MESA_LOADER_DRIVER_OVERRIDE. KWin/Plasma/Maliit environments contain
only the existing FD_MESA_DEBUG=inorder graphics workaround, not the temporary
mediatek override. MDP5 scans imported AB24 DMA-BUFs. The warmed full-desktop
workload is42.86FPS, p50=16.674ms, p95=33.345ms, GPU98.93%, CPU12.18% over four
cores. Removing the inherited loader problem is a correctness fix, not an FPS
improvement. Current native activation checks the installed entry first.

VERIFIED_DEVICE: owner-requested15second real drawer gestures give23.28FPS in
presentation bursts, p50=49.998ms,p95=50.015ms,GPU97.50%. The CPU sampler began
after that recording and supplies no valid simultaneous CPU figure. A second
manual recording with only background contrast temporarily unloaded gives
29.07FPS,p50=33.339ms,p95=50.013ms,GPU98.91%,CPU19.52%. Contrast is restored;
manual gesture differences preclude attributing the entire increase to it.
Animations remain enabled.

An exact-current-build upstream uinput module was compiled temporarily and
loaded from/tmp for repeatable direct-touch gestures. The touchscreen and KWin
paths remain ordinary libinput input. First-cycle-discarded identical gestures
give opening26.30FPS and closing23.48FPS. No permanent input-injection service
is installed. The initial D-Bus drawer test does not cause a visible transition
and is INVALID as an animation workload. The rejected KDE fake-input attempt
had no authorized protocol; its temporary desktop entry was removed.

REGRESSION / VERIFIED_DEVICE: the Plasmashell-only texture tiling trial
FD_MESA_DEBUG=inorder,ttile damages the image, as physically reported by the
owner. Its apparent30.47FPS is not an accepted improvement. The drop-in was
removed immediately, scripted gestures stopped, and Plasma restarted with the
original inorder environment. KWin also retains inorder. Physical restoration
was confirmed by the owner after restarting Plasma. Do not enable ttile as a production optimization.
An earlier attempted tiling trial had not applied the flag because user systemd
configuration directories were root-owned; that recording is INVALID for
comparing tiling. Directory ownership was corrected narrowly before the real
trial. No kernel/DT/boot artifact or hardware frequency changed in these tests.

## Frame-path observation attempt

VERIFIED_DEVICE: owner confirms the image completely recovered after rejecting
ttile. The subsequent frame-path inspection records KWin using native card1
and renderD128, with imported AB24 scanout, and Plasma using renderD128.
These file descriptors do not establish the absence of earlier GPU copies.

The installed KWin6.3.6 binaries use Thumb-2 instructions. Linux v7.2.9 ARM
uprobes explicitly does not support Thumb in arch/arm/probes/uprobes/core.c.
A proposed colour/fence uprobe recording was therefore unsafe and is rejected.
The registration script had accepted aligned offsets, but alignment alone does
not establish the instruction set. During the subsequent recording attempt both
SSH and USB console stopped responding. Causality and whether perf enabled the
probes remain UNKNOWN until persistent evidence is recovered. No new kernel,
DT, boot artifact, frequency override or persistent tracing service was installed.
Owner was asked for a normal forced restart; boot clears the temporary events.
Do not repeat these probes or use their recording as performance evidence.
Use userspace API tracing for this Thumb binary instead, first verifying it on
a bounded client workload and preserving an automatic userspace rollback.

## Read-only frame path inspection, 2026-10-15

Correction: these diagnostics ran after the recovery timer had restored the
simpledrm kernel. The active DRM path was not checked at the start. They are
INVALID as native-KMS performance evidence. Only the KWin-side state below is
established; simpledrm's kernel RGB888 CPU conversion was still active.

VERIFIED_DEVICE (simpledrm): 150 read-only snapshots during virtual-touch drawer
movements show EglGbmLayerSurface importMode=None, bufferTarget=Normal,
needsShadowBuffer=false, and no shadow, CPU-import or EGL-import swapchains.
These snapshots show no additional KWin import copy or final colour shadow pass
in that fallback configuration, not the absence of kernel framebuffer copies.
The normal warmed full-screen workload independently has the same state in20
snapshots, yet directScanoutBuffer remains absent. This recording does not
establish the native MDP5 path.

The exact installed libkwin6.3.6 and QtCore6.8.2 layouts were derived from
Debian debug info, checked against Thumb-2 disassembly, then read with
O_RDONLY /proc/PID/mem. tools/read-kwin-frame-path.py guards the board, binary
SHA256 values, pointer/count ranges and sampling bounds, performs no ptrace,
injected call, instruction patch or process stop, and prints only path state.
Its15sample ordinary-session smoke test passes. These offsets must not be used
for different binaries. Raw process addresses/debug info remain ignored/private.

API tracing limitations: the installed EGL apitrace wrapper lacks GLX lookup
symbols expected by libepoxy. Initial KWin tracing aborts in userspace; its
separate timed restore removes the preload and resumes normal KWin. Adding the
real GL dependency resolves glXGetCurrentContext. A further diagnostic lookup
shim routes GLX functions to traced EGL entry points; both lookup spellings pass
a bounded standalone LD_PRELOAD check. However the captured KWin trace stops at
glEGLImageTargetTexture2DOES before useful drawer rendering. These captures are
INVALID as full frame-path timing/colour-shader evidence. Do not infer absent
GPU work from absent calls in them. Ordinary Qt's bounded standalone trace has
no glFinish/readback calls, but does not cover compositor output. The separate
C++ uniform interposer did not collect calls and is also invalid. All temporary
preloads were removed by timed restores; ordinary KWin and Plasma are running.

VERIFIED_DEVICE (simpledrm, not native): the square measures41.85FPS while independent
stacking inspection finds top22px and bottom36px non-fullscreen Plasma docks
above the fullscreen client. KWin6.3.6 scanoutCandidates rejects such visible
windows, so they are one direct-scanout blocker. Activating the workload gives
panelState=hidden but42.21FPS and no direct scanout. A temporary opacity0
comparison (automatically restored to original1) gives44.92FPS,p95=22.985ms,
GPU99.35%, still no direct scanout. Thus hiding these panels is neither a60FPS
fix nor an accepted permanent change. Cursor hide counter1 is observed after
touch; Cursor::isOnOutput checks it in the pinned source, so do not claim a
hidden-cursor-layer bug without evidence. Remaining candidate/import blockers
are being inspected. These diagnostic profiles include read-only/script overhead
and cannot be compared with the earlier warmed native43FPS benchmark.

VERIFIED_UPSTREAM / current-source inspection: current KWin implements generic
output-layer assignment and uses DRM overlay planes on single-output systems.
Pinned KWin6.3.6 hardcodes planeCount=1 and does not offer this offload path.
Two native MDP5 overlay planes remain unused. This is a concrete architectural
limit for a transparent drawer over desktop: existing buffers must be composited
on GPU instead of testing MDP hardware blending. Newer offload is not validated
on this MSM8226 driver; do not just set a nonexistent6.3 option or claim an
upgrade has happened. Research sources include current src/compositor.cpp and
src/backends/drm/drm_gpu.cpp, retrieved2026-10-15, and KDE's official6.5 overlay
announcement. No userspace packages or kernel artifacts were replaced by this
inspection. Stable60FPS for the full interface remains unmet.

## Native-only working kernel, 2026-10-15

VERIFIED_DEVICE: the SD kernel was rebuilt with CONFIG_DRM_SIMPLEDRM disabled.
Its installed /proc/config.gz confirms the setting; no simpledrm symbols appear
in the host System.map and no framebuffer DRM node registers. The native
activation service and SDDM start automatically. KWin opens native card1 and
Adreno renderD128; supportInformation reports freedreno FD305/OpenGL/EGL.
MDP5 scans imported linear AB24 DMA-BUFs with pitch5120. Ten exact-build
read-only snapshots on this verified native path show importMode=None,
bufferTarget=Normal and no CPU/EGL import or shadow swapchains. There is no
simpledrm CPU RGB888 conversion; MDP5/DSI handles the physical output.
Physical acceptance of this configuration-only reboot is pending; earlier
native desktop/touch/colour/brightness acceptance remains recorded separately.

The same bounded workload measures41.33FPS before and42.05FPS after removing
the dormant driver, with p95=33.346/33.347ms and GPU busy98.58/98.23%.
The aggregate CPU samples are40.62/16.91%; background startup activity differs,
so these values do not establish a CPU saving from removing an unused driver.
The remaining rendering limit is not fixed by compilation alone. GPU busy
includes memory/fence stalls and does not identify a specific shader or prove
the DDR policy correct. Actual DDR frequency remains UNKNOWN.

The native SD container SHA256 is
c8e5f454c85b7ad53af4f84806135b28376e75d75a43946f2e126f0b133eba38;
the genuine zImage SHA256 is
7b0ce2a2a30ac4af19dc074ac1c2563e43058cd2e07318011ac1c3cce2a72d13.
Boot-layout and staged/final SD checksums pass. The whole module tree was
replaced with its matching verified build. Internal lk2nd/BOOT was untouched.
An ordinary make build repeat passes and reproduces both kernel hashes above;
shell syntax, Python compilation, JSON parsing and git diff --check also pass.
The fresh mobile-rootfs build changes are inspected and syntax-checked, but a
complete fresh rootfs image has not been rebuilt or tested on the tablet.

The former automatic recovery timer is stopped, disabled and masked. Its
definition is archived under /var/lib/t531/manual-recovery. The simpledrm Mesa
entry package was removed using dpkg; the native msm-kms entry remains. Saved
rescue kernels, manual rollback and the immutable bootstrap/USB recovery are
retained. An absent native display must leave diagnostics available, not
silently switch the working system back to framebuffer output.

The main build and mobile rootfs now default to native KMS/ICC; historical
framebuffer builds require explicit NATIVE_KMS=0 NATIVE_ICC=0. Bootstrap is
separate and keeps its recovery console. The configuration validator now
respects the last setting for each symbol, matching merge_config.sh overrides.
Both profilers record actual compositor KMS/render descriptors and driver names
before and after recording. Requested labels cannot override detected devices.
The negative check requesting simpledrm on native KMS fails as intended.
The exact-build process-memory reader defaults to requiring native KMS too.

## Controlled animation profiles and boot console, 2026-10-15

VERIFIED_DEVICE: identical uinput notification-drawer swipes with the actual
native path checked before/after give27.22FPS, p50=33.338ms, p95=50.013ms,
aggregate CPU9.77%. GPU utilization84.84% covers idle gaps as well as animation.
The owner confirms the visible gestures, correct image/text and normal touch.
Temporarily unloading only contrast gives26.73FPS on the same sequence and is
not an improvement. Contrast is restored. A verified GLES3.0 KWin repeat gives
26.32FPS, p95=66.675ms; the original desktop OpenGL backend is restored.
The first attempted GLES recording still had the old compositor and is INVALID.
The restart helper now waits for the previous compositor to exit.

KWin's built-in performance CSV reports about3ms median CPU render span, with
larger render-journal predictions from startup/history. Mesa25.0.7 does not
advertise GPU timestamp queries on A3xx, so those spans are not GPU execution
times. Traced submit-to-retire medians around29-33ms include software queueing
and other contexts. A12000us safety-margin test gives26.30FPS, p95=66.680ms,
with worse target misses; it is rejected and its temporary drop-in is removed.
No animation duration or texture tiling changes are accepted.

SSH and USB console stopped responding after these tests. No new panic/Oops
was found in the live or archived pstore; old dmesg records date from2026-10-13.
The previous kernel journal contains sustained DSI error work and a WLAN scan
failure. The exact full-system hang cause remains UNKNOWN. The owner performed
a forced restart; diagnostic configuration was then removed and native KMS
restored. Do not attribute the freeze to a shader, clock setting or GPU without
a matching failure record.

At the owner's request, patch0102 enables only the verified simplefb boot
console while keeping CONFIG_DRM_SIMPLEDRM=n. The framebuffer uses the existing
1280x800 RGB888/stride3840 firmware buffer and clock/power references. Upstream
msm_drm_kms_init already calls aperture_remove_all_conflicting_devices before
native initialization. On-device simplefb registers at1.19s, native msm-kms at
16.86s; afterwards /sys/class/graphics contains only fbcon and KWin opens native
card1/renderD128. Owner physically confirms that boot text now works.

The first handoff test has a black physical display despite active native DRM.
An earlier GPU hang at77s identifies xwaylandvideobridge as its offending task;
this happened before the later GPU-counter diagnostic. Restarting the graphical
session restores its processes/FD305 contexts but does not restore the physical
image. L5 loses the old framebuffer's vote at aperture removal and has no native
consumer; a temporary regulator-framework diagnostic re-enables the same1.2V
vote. Bridge readback still fails ENXIO. Patch0103 retains L5 from boot in the
explicit firmware-powered native profile as a controlled supply-handoff test.
This does not identify a bridge supply pin or validate suspend; the black-screen
cause and physical acceptance of0103 remain pending.

Follow-up VERIFIED_DEVICE: after0103, L5 keeps its1.2V vote through removal of
simplefb. The read-only bridge probe now returns the correct ID0x6500 and its
configured registers, whereas after0102 and a late re-enable it returned ENXIO.
The owner confirms boot text followed by working Plasma. This validates retaining
the firmware supply during handoff; its eventual native bridge pin assignment
and suspend sequencing remain UNKNOWN. No startup GPU hang is seen in this
0103 boot's first three minutes with ordinary GPU runtime PM. The controlled
drawer baseline after this accepted boot is26.89FPS,p95=50.021ms.

Initial A3xx performance-counter readouts are INVALID: all shader counters are
zero even during a workload. Selector readback and counter-enable bit pass,
but these are not evidence that shaders or texture/memory work are absent.
Diagnostics are bounded, board/chip guarded, and not installed as services.
The43.03FPS DRM square recording with0102 lacks physical image acceptance and
cannot be claimed as a restored or faster complete interface.

## Reliability update, 2026-10-17

Patches0112–0114 protect a reproduced NULL-domain IOMMU fault and defer
ARM32 legacy DMA attachment until the owning display driver has stopped
firmware scanout. Three successive native boots, including a persistent
installation, record zero context faults. Patch0115 addresses HS FIFO
interrupts measured only in vertical blanking; the bounded comparison drops
DSI IRQs from1219/s to0 while ordinary Phoc/Phosh still update the display.
A subsequent MDP power-cycle reproducer still exposed INTF1 underruns on
0115. The standalone upstream v4 patch0116 moves INTF flush ahead of timing
engine enable: its trial boots cleanly and completes five power cycles
without a logged underrun. A separate white-window episode is traced to
xwaylandvideobridge; Phosh-only autostart exclusion is installed.
Full details, artifact hashes, limits and the explicit SD/module rollback
are in [GRAPHICS-STABILITY.md](GRAPHICS-STABILITY.md). Graphics remains
PARTIAL: firmware bridge power and unverified suspend/recovery paths remain.
