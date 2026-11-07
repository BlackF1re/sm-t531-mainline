# Patch review and source boundaries

* Linux base/ordered series: `scripts/build.sh`, `patches/linux`; preserve
  exact base commit, third-party authorship, licensing and Message-IDs.
* Accepted graphics changes: `patches/mesa`, `patches/qt`, `patches/kwin`,
  `patches/plasma-mobile`; the loaded identities are in
  `config/graphics-stack.lock.json`. Phosh/PowerDevil patches are separate.
* Rejected candidates are retained in Git history (`43648a2`), not selected by
  production scripts. A candidate number in an old dataset is not an active
  patch; consult the [component notes](../Porting%20Notes/README.md).
* Apply/source consistency, checkpatch, DT schemas and builds are host evidence,
  not physical acceptance. Use a minimal justified change, preserve the checked
  SD baseline, then record real endpoint tests before changing feature status.
* `make check` covers syntax, JSON, links, generated-file hygiene and unit tests.
  Kernel/Mesa builds, schema checks and device acceptance remain distinct.
* No zeroing/cache synchronization/fence/validation removal as a performance
  workaround. No diagnostic register probe or temporary runtime override should
  silently become production policy.

Machine-readable historical task states and dependencies:
[`status/hardware.yaml`](../status/hardware.yaml). Current technical conclusions
belong only in `Porting Notes/`; procedure changes belong in the operator guide.
