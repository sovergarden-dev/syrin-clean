# Security policy

## Scope

Report paths that can move/delete unapproved files, overwrite recovery data, bypass ownership or containment checks, misrepresent missing data, expose private output or execute untrusted content.

The supported file engine uses reviewed plan bytes and explicit item IDs, canonical local paths, file identity, owned storage, writer locks and durable journals. Permanent removal targets a selected regular file through its verified handle, not a directory tree. Recovery remains conditional on intact data and access. Purge is irreversible.

## Limits

This is a development build. It is not an OS sandbox, a backup product or authentication of the human behind an unrestricted agent. A full-shell agent or local administrator can bypass package controls. The elevation bridge can launch a supplied local script; the skill policy does not authorize using it to invent unsupported mutation procedures.

Device-management policy and unsupported system operations require separate review. Unknown cloud providers, untested filesystems/hardware and out-of-band changes are not certified safe. See the [support matrix](docs/feat/support.md).

The runtime does not upload results. Raw reports/plans may contain private paths, app names and metadata; an agent/provider may process terminal output externally. Aggregate exports omit raw private fields but are not guaranteed anonymous. Checksums detect corruption, not publisher authenticity.

## Reporting

Use the repository's private vulnerability reporting feature rather than publishing a destructive repro in an issue. Include the source revision, Windows/PowerShell versions, the smallest synthetic fixture and observed versus expected behavior. Do not attach credentials, real personal documents, raw audit reports or private paths.

Do not test deletion, registry changes, System Restore or other destructive behavior on production/user data. Use disposable fixtures or VM snapshots.
