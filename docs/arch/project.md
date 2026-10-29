# Syrin clean architecture

> updated 2026-10-28 · v3.6

Syrin clean is a bilingual skill/prompt toolkit with a shared PowerShell runtime and offline HTML reports. The hardening changes are unreleased. The supported mutation surface is the file lifecycle; system tuning and repair remain advisory pending validated adapters and VM qualification.

## Sources and build

| Source | Output |
|---|---|
| `src/runtime/modules` and `scripts` | Identical native runtime in both skill packages |
| `src/instructions/{en,vi}` | Skill policy/references and the same full prompt content |
| `src/report` | Shared report asset bundled with the runtime |
| `src/web` | One landing script/style set, localized markup and profile data |
| `src/install.ps1` | Same transactional installer in both editions |
| `src/extract-runtime.ps1` | Standalone prompt bootstrap |
| `tools/build.py` | Skill trees, ZIPs, Markdown, embedded payloads, manifests and SHA256SUMS |

The builder constructs the complete output in memory, checks source/package allowlists and JavaScript, then atomically replaces changed files. `--check` compares without writing. Generated artifacts are not hand-edited. ZIP metadata is deterministic. Checksums detect corruption and mismatches; they do not establish publisher authenticity by themselves.

## Runtime boundaries

- `IO.psm1`: local canonical paths, reparse/recall/protected-path checks, 128-bit file identity, checked native rename/deletion, durable atomic writes and argument quoting.
- `Quarantine.psm1`: immutable plans, explicit selections, owned roots, writer locks, append-only journal replay, conflict recovery and explicit legacy import.
- `Audit.psm1`: read-only named collectors, child-process budgets, typed categories and explicit incomplete/error states.
- `Report.psm1`: input/schema validation, baseline identity, proposal data, history and aggregate-only sharing.
- `Windows.psm1`: process elevation and Restore Point verification with registry rollback. Real system qualification is still pending.

Planning has no file-transfer side effects. Execution binds to exact plan bytes and item IDs. Native file operations check identity and metadata on the handle used for the operation; purge never recurses a root. File transfers are same-volume and do not overwrite an existing destination. The journal and immutable source plan remain the recovery record.

Reports consume versioned data, not label-based guesses. Missing collectors are unknown, app/VM/user data are not caches, and comparison requires matching machine/volume identity. The browser cannot execute PowerShell; history controls prepare requests for the agent. Aggregate exports omit raw private fields and are never automatically uploaded.

## Compatibility and migration

Version 3.6 filenames are retained as the imported baseline while development work accumulates under Unreleased. The new journal/audit formats have their own schema versions. Legacy CSV journals are imported only by a reviewed explicit operation into separate owned storage; old records are not rewritten. Legacy audit JSON is display-only and marked unverified.

Installer staging and prior versions live under `%USERPROFILE%\.syrin-clean-installer`, outside active skill-discovery roots. The active directories are switched only after both staged copies verify; failures roll back completed switches. Backups and failed staging remain available rather than being recursively erased.

See [execution contracts](execution.md), [commands](../ref/commands.md), [support](../feat/support.md) and [validation](../ref/validation.md).
