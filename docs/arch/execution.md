# Execution and data contracts

> updated 2026-10-29 · v3.6

The shared native path helper performs lexical validation, mapped-drive rejection, live ancestor-attribute checks and long-name resolution in one call. It does not cache mutable filesystem state. Missing destination suffixes are resolved without creating directories; mutation still verifies the final handle and file identity.

The hardening work is unreleased. Runtime sources live in `src/runtime/`; language packages and downloadable files are generated. Commands support Windows PowerShell 5.1. Tests operate on owned fixtures only.

## File operations

Quarantine is a metadata-first, same-volume file move. Directories are expanded to an explicit list of regular files; directory skeletons are retained. Cross-volume transfers are rejected instead of falling back to copy-and-delete. Quarantine does not free disk space. Purge is a separate plan and only deletes selected stored files, never the root or an unlisted file.

Planning records a session ID, item IDs, canonical paths, file identity and metadata. Executing requires the plan digest and an explicit item selection. The digest binds approval to a particular plan; it is not authentication against an agent with unrestricted shell access. Files are checked again immediately before an operation. Native rename/deletion validates the 128-bit identity, metadata and final path on the handle used for the operation; the source handle and destination directory are retained through rename. Protected paths, cloud ancestry, reparse points, recall/offline files and non-local paths fail closed. Unknown cloud providers remain an explicit limitation.

Each planning/execution operation resolves its protected reference paths and cloud roots once. This policy snapshot is not persisted or accepted from a plan document. Source attributes, ancestor flags and file identities are not cached: native attribute reads check the live path, and mutation still validates the opened handles. Shared module imports do not force-reload another caller's IO commands; use a fresh PowerShell process after updating an installed runtime.

An owned root has a versioned marker and an exclusive process lock. Install staging and backups are kept outside active agent skill-discovery directories and protected by a separate profile-level update lock. Sessions retain an immutable plan and append-only, atomically written event records. Replay derives each item's state. Events never replace the plan's trusted paths. Interrupted operations reconcile against file identity; ambiguity becomes a conflict, not a guessed success. Restore never overwrites an existing file and supports a separate renamed destination. Purge retains metadata for history.

Journal and plan JSON are parsed and hashed from the same byte read, including the original BOM. History replay retains ownership, digest, sequence and containment checks.

Legacy CSV journals are never automatically migrated. An explicit import command validates containment and previews the items, then creates a new journal without moving files. This includes still-stored items in old `manifest-restored-*` files. Unknown files remain untouched.

## Audit and report

Audit schema 1 identifies the session, machine, system volume, generation time and report mode. Each collector has complete/partial/unavailable/failed status, data and errors. Missing values remain null. Radar entries have explicit categories and logical measured bytes; reclaimable bytes are separately estimated and are not inferred from a folder name. Windows family is independent of lifecycle support status.

Reports validate JSON and schema before replacing an existing output. Baselines require matching machine identity and schema. Legacy audit input is read through an explicit conservative adapter and is marked unverified; it is not silently upgraded on disk. Shared reports contain only an allowlist of aggregates and omit paths, commands, machine identity and raw collector records.

Audit writes `audit-progress.json` before each collector and on completion; a timestamped progress record is not proof that its process is still running. Storage collectors receive a share of the requested total budget, and all partial results remain explicit. Reports include the complete loaded history, let the reader select a session and paginate its items, and retain selections across item pages. Only the current page is rendered. Decorative animation is capped at 24 frames per second and 250/500 points on narrow/wide viewports, with no automatic loop when paused, hidden, offscreen or reduced motion is enabled.

## Boundaries

These controls address accidental overreach, interrupted writes and inconsistent data. They do not isolate an unrestricted agent from the user's OS permissions or prove safety against a malicious local administrator. Automated tests use owned fixtures. Operator-assisted live runs require explicit scope approval and do not qualify unrelated system-changing helpers or other Windows/architecture/provider combinations.

Native API references: [SetFileInformationByHandle](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-setfileinformationbyhandle), [FILE_RENAME_INFO](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_rename_info), [FILE_DISPOSITION_INFO](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_disposition_info) and [FILE_ID_INFO](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_id_info).
