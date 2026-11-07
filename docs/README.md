# Operator and developer guides

Technical component knowledge lives only in [Porting Notes](../Porting%20Notes/README.md).
This directory retains operator procedures and the pinned hardware-source manifest.

| Task | Guide |
|---|---|
| Build prerequisites, host paths and SD deployment | [Build & deploy](BUILD-DEPLOY.md) |
| Private capture, integrity and explicit restoration plans | [Stock backup](BACKUP-STOCK.md) |
| Bootstrap recovery and diagnostic access | [Recovery](RECOVERY.md) |
| Install/check the graphics lock | [Graphics stack](GRAPHICS-STACK.md) |
| Stage/confirm/recover SD graphics slots | [SD graphics update](UNIFIED_DRM.md) |
| Optional Phosh packages and session selection | [Phosh](PHOSH.md) |
| Patch ownership and validation boundaries | [Patch review](PATCH-REVIEW.md) |

Test reports and probe snapshots were consolidated into the component notes.
`hardware-source-manifest.json` retains source commits, include closure,
licensing and provenance; it is not a test report. Runtime version/hash locks
remain in `config/`. Raw dumps, firmware/NV and calibration stay private.
