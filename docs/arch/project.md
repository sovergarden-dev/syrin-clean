# Syrin clean architecture

> updated 2026-11-14 · v4.0.0-preview.2

Syrin clean is a bilingual skill/prompt toolkit with a shared PowerShell runtime, a single offline landing HTML and offline reports. The current channel remains pre-release; `project.json` owns its version. The supported mutation surface is the file lifecycle; system tuning and repair remain advisory pending validated adapters and VM qualification.

## Sources and build

| Source | Output |
|---|---|
| `src/runtime/modules` and `scripts` | Identical native runtime in both skill packages |
| `src/runtime/android` | Optional Python standard-library ADB diagnostics; no device mutation commands |
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

Pages runs from a published release tag, reuses the complete Windows validation workflow and stages `index.html`, `report-demo.html`, `version.json` and `.nojekyll` through an explicit allowlist. The Windows job uploads that allowlisted site. Linux deployment downloads it and checks the HTML against the published release asset digests instead of rebuilding platform-specific packages. An explicit dispatch can redeploy an existing published tag. It never copies the repository root or local session directories. Public report examples are synthetic; real reports stay outside the checkout.

## Runtime boundaries

- `IO.psm1`: local canonical paths, reparse/recall/protected-path checks, 128-bit file identity, checked native rename/deletion, durable atomic writes and argument quoting.
- `Quarantine.psm1`: immutable plans, explicit selections, owned roots, writer locks, append-only journal replay, conflict recovery and explicit legacy import.
- `Audit.psm1`: read-only named collectors, child-process budgets, typed categories and explicit incomplete/error states.
- `Report.psm1`: input/schema validation, baseline identity, proposal data, history and aggregate-only sharing.
- `Windows.psm1`: process elevation and Restore Point verification with registry rollback. Real system qualification is still pending.
- `Policy.psm1`: persistent audit-only/protected-path restrictions and policy-file digest snapshots; it never grants human approval.
- `Performance.psm1`: bounded CPU/memory intervals and PID/start-time identities, without process control.
- `android/adbclient.py`, `model.py`, `audit.py`: exact USB selection, bounded read-only commands, strict measurement parsing and fresh local audit output. Windows-specific missing USB devpaths require a matching unique USB selector proof.

The local `4.1.0-preview.1` candidate adds these boundaries while published preview 2 remains unchanged. Android reports carry an explicit platform and cannot attach Windows history. File execution revalidates policy between atomic items and can honor a run-scoped stop request. Recovery inspection checks stored metadata without automatic repair. See [device contracts](../feat/devices.md).

Planning has no file-transfer side effects. Execution binds to exact plan bytes and item IDs. Native file operations check identity and metadata on the handle used for the operation; purge never recurses a root. File transfers are same-volume and do not overwrite an existing destination. The journal and immutable source plan remain the recovery record.

Reports consume versioned data, not label-based guesses. Missing collectors are unknown, app/VM/user data are not caches, and comparison requires matching machine/volume identity. The browser cannot execute PowerShell; history controls prepare requests for the agent. Aggregate exports omit raw private fields and are never automatically uploaded.

## Compatibility and migration

The imported 3.6 distribution remains in Git history. The first GitHub preview uses 4.0.0-preview.1 because the reviewed-plan runtime and artifact layout replace the original command and delivery contracts. `dist/syrin-clean.html` is the unified HTML asset; packages and prompts carry the current version. Journal and audit schema versions remain independent. Legacy CSV journals are imported only by a reviewed explicit operation into separate owned storage; old records are not rewritten. Legacy audit JSON is display-only and marked unverified.

Installer staging and prior versions live under `%USERPROFILE%\.syrin-clean-installer`, outside active skill-discovery roots. The active directories are switched only after both staged copies verify; failures roll back completed switches. Backups and failed staging remain available rather than being recursively erased.

See [execution contracts](execution.md), [commands](../ref/commands.md), [support](../feat/support.md) and [validation](../ref/validation.md).

On release events, the candidate Pages workflow transfers eight validated release artifacts alongside the site, compares every published digest, then creates provenance attestations. Manual redeployment checks the two HTML assets and skips provenance staging/signing, preserving compatibility with older tags that lack the staging helper. This prepared workflow still needs live publication verification.
