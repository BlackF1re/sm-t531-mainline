# Stock-data backup tool

Use `scripts/backup-stock`; see [the operator guide](../../docs/BACKUP-STOCK.md)
for coverage, transport limitations, confirmation and recovery requirements.

* `backup.py`: host CLI, private sessions/manifests, verification and restore plans.
* `agent.py`: root Python agent sent over verified SSH, not installed as a service.
* `hardware/partitions.json`: shared public geometry, checked before capture/write.

No new dependencies beyond Python's standard library, OpenSSH/fastboot and
remote util-linux. Default output is ignored `backup_stock/`; never commit it.
Run host fault tests through `make check`. Device writes require a separate
explicit invocation; tests use synthetic files or mocked transports.
