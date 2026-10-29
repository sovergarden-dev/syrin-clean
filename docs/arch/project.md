# Syrin clean architecture

> updated 2026-10-29 · v4.0.0-preview.1

Syrin clean is a bilingual skill/prompt toolkit with a shared PowerShell runtime, a single offline landing HTML and offline reports. Version 4.0.0-preview.1 is a pre-release. The supported mutation surface is the file lifecycle; system tuning and repair remain advisory pending validated adapters and VM qualification.

## Sources and build

| Source | Output |
|---|---|
| `src/runtime/modules` and `scripts` | Identical native runtime in both skill packages |
| `src/instructions/{en,vi}` | Skill policy/references and the same full prompt content |
| `src/report` | Shared report asset bundled with the runtime |
| `src/web` | One landing template/module/style set and EN/VI locale/profile data |
| `src/shared` | Shared design tokens, licensed embedded font subsets and canvas lifecycle |
| `project.json` | Version, distribution channel, repository and Pages destinations |
| `src/install.ps1` | Same transactional installer in both editions |
| `src/extract-runtime.ps1` | Standalone prompt bootstrap |
| `tools/build.py` | Skill trees, ZIPs, Markdown, embedded payloads, manifests and SHA256SUMS |

The builder constructs the complete output in memory, checks source/package allowlists and JavaScript, then atomically replaces changed files. `--check` compares without writing. Generated artifacts are not hand-edited. ZIP metadata is deterministic. Checksums detect corruption and mismatches; they do not establish publisher authenticity by themselves.

The landing's JSON payload embeds both packages and the synthetic report. Inline modules include the shared canvas code without runtime imports. Font files and their licenses are local canonical inputs; the output contains data URLs and license text rather than external font requests. The report uses a network-denying content security policy. Language switches update labels while retaining profile values, the active tab and report selection/filter state.

Pages runs from a published release tag, reuses the complete Windows validation workflow, verifies tag/version identity and stages `index.html`, `report-demo.html`, `version.json` and `.nojekyll` through an explicit allowlist. It never copies the repository root or local session directories. Public report examples are synthetic; real reports stay outside the checkout.

## Runtime boundaries

- `IO.psm1`: local canonical paths, reparse/recall/protected-path checks, 128-bit file identity, checked native rename/deletion, durable atomic writes and argument quoting.
- `Quarantine.psm1`: immutable plans, explicit selections, owned roots, writer locks, append-only journal replay, conflict recovery and explicit legacy import.
- `Audit.psm1`: read-only named collectors, child-process budgets, typed categories and explicit incomplete/error states.
- `Report.psm1`: input/schema validation, baseline identity, proposal data, history and aggregate-only sharing.
- `Windows.psm1`: process elevation and Restore Point verification with registry rollback. Real system qualification is still pending.

Planning has no file-transfer side effects. Execution binds to exact plan bytes and item IDs. Native file operations check identity and metadata on the handle used for the operation; purge never recurses a root. File transfers are same-volume and do not overwrite an existing destination. The journal and immutable source plan remain the recovery record.

Reports consume versioned data, not label-based guesses. Missing collectors are unknown, app/VM/user data are not caches, and comparison requires matching machine/volume identity. The browser cannot execute PowerShell; history controls prepare requests for the agent. Aggregate exports omit raw private fields and are never automatically uploaded.

## Compatibility and migration

The imported 3.6 distribution remains in Git history. The first GitHub preview uses 4.0.0-preview.1 because the reviewed-plan runtime and artifact layout replace the original command and delivery contracts. `dist/syrin-clean.html` is the unified HTML asset; packages and prompts carry the current version. Journal and audit schema versions remain independent. Legacy CSV journals are imported only by a reviewed explicit operation into separate owned storage; old records are not rewritten. Legacy audit JSON is display-only and marked unverified.

Installer staging and prior versions live under `%USERPROFILE%\.syrin-clean-installer`, outside active skill-discovery roots. The active directories are switched only after both staged copies verify; failures roll back completed switches. Backups and failed staging remain available rather than being recursively erased.

See [execution contracts](execution.md), [commands](../ref/commands.md), [support](../feat/support.md) and [validation](../ref/validation.md).
