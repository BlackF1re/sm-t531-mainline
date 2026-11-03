# A3xx scissor-aware command execution, 2026-11-01

This opt-in driver prototype preserves pixel coverage and shader precision.
It is separate from the discarded coverage-reduction diagnostic that corrupted
the desktop. No effect, animation or framebuffer resolution is disabled.

A3xx normally executes a batch's draw command stream for each GMEM tile. Even
when visibility/scissoring prevents fragment work, the command processor still
processes state for draws that cannot affect that tile. The prototype splits
small-scissor draws into self-contained subpasses, emitting complete state so
that a visible draw cannot inherit state from an omitted predecessor. At tile
emission, it omits a subpass only if its inclusive scissor cannot intersect the
tile. VSC binning is disabled for affected batches because skipped draw packets
would desynchronize its visibility stream. Fullscreen-only and small framebuffer
batches retain the ordinary path. Unexpected appended commands make a subpass
uncullable; query/streamout cases are excluded from culling.

Candidate: `patches/candidates/mesa/0007-a3xx-scissor-command-culling.patch`.
Default is off; private testing uses `FD3_SCISSOR_IB=true`.
`FD3_SCISSOR_LOG=true` adds CPU-only per-batch emitted/skipped-IB counts.
Private builds, test scripts, exact snapshots and captures are in
`.work/scissor-ib-build/`. Production libraries have not been overwritten.

## Offscreen evidence

The 1280x800 synthetic workload draws five fullscreen layers followed by 91
small-scissor draws, switching programs, uniforms and textures. Same-binary
ABBA, with no overlapping foreign GPU submissions in measured windows:

* Ordinary sparse case: 31.731 / 26.697 / 26.745 / 31.995 ms (approximately).
* Partial-clear/stencil case: 32.488 / 26.896 / 26.882 / 32.741 ms.
* Fullscreen-only case remains approximately 237 ms.

These are glFinish wall times, including CPU/driver work, not exact GPU clocks.
The numbers are synthetic and do not establish a GUI FPS gain.

Full RGBA comparisons across 1280x800 and 257x131, program/texture changes,
blending, partial clears, stencil writes and query cases compared 50,768,016
components without a differing byte. See
`graphics-scissor-ib-offscreen-20261101.json` for exact timings and query
regression in the intermediate prototype. A subsequent activation guard keeps
query-active draws on the ordinary path; that revision also passes all eight complete-image comparisons, with query
results true. See `graphics-scissor-ib-v4-offscreen-20261101.json`.
Additional queued texture updates and shared-source/linear-target readbacks
passed; counts are in `graphics-scissor-textures-20261101.json`.

## Separate query-buffer defect

An initial original-path GL_ANY_SAMPLES_PASSED test aborted in OUT_RELOC because
a per-tile query address exceeded its BO. `fd_resource_resize()` set resource
width0, then called image slice setup, while its layout retained the initial
zero buffer width. The fix updates the buffer layout and allocates the requested
byte size, matching PIPE_BUFFER creation. Both phases of subsequent comparisons
contain that separate fix. Query results are true and images match in all tested
cases. Candidate 0008 contains the isolated change. It is a correctness fix;
there is no evidence that active queries cause the drawer's FPS deficit.

## Initial GUI result

The bounded same-binary A/B/A drawer trial gave 50.575 / 49.830 / 49.967
presentation events/s. Driver metadata confirms culling was active: 157
batches activated it and 563,787 IB executions were skipped across startup,
warmup and measurement combined (these totals are not per measured frame).
Thus the first prototype is not a GUI improvement and is not promoted.
Original Mesa mapping and the independent return timer were restored/stopped.
See `graphics-scissor-ib-gui-20261101.json`.

A follow-up groups consecutive draws sharing the same scissor, requiring one
complete entry state per group rather than one per draw. The grouped revision passes 63,460,020 component comparisons without a differing byte, including an explicit empty-query result of zero. Sparse synthetic time improves from approximately 31–32 to 24–27 ms. However, GUI A/B/A is 50.763 / 49.687 / 50.329 presentation events/s, with p95 approximately 33.3 ms. This revision is also not promoted. See `graphics-scissor-group-offscreen-20261101.json` and `graphics-scissor-group-gui-20261101.json`. Stable 60 FPS remains pending.
