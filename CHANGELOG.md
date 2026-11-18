# Changelog

All notable changes to this project. Dates are 2026.

## [4.1.0-preview.2] - 2026-11-18

### Added
- Add native C# `CollectPlanFiles` directory traversal and `SHGetKnownFolderPath` redirected-folder resolution in `IO.psm1`, cutting 2,048-file planning overhead while preserving per-node reparse, recall and policy checks.
- Add deterministic directory grouping (`groups[]` with `G1..Gn`) in `New-SyrinFilePlan` and `-GroupId` selection in `Invoke-SyrinFilePlan` and `quarantine.ps1`.
- Add Windows `hotspots` (unclassified directories >= 500 MB with `rootLastWriteUtc` versus `latestContentWriteUtc`), project-anchored `devArtifacts` (`node_modules`, `target`, `.venv`), redirected `Downloads` in `largeFiles`, and expanded multi-profile browser, GPU/Electron updater, Zalo, bun, Playwright, WSL2, Recycle Bin and hibernate/pagefile radar entries.
- Add `Prepare permanent delete request` (`#purge-request`) in offline reports when all selected history items are intact `quarantined` in a non-imported session.
- Add `-IncludeDetectedAgents` and `-AgentTargets` (`@('.claude','.agents','.codex','.cursor','.gemini\antigravity')`) in `install.ps1`, plus `failureKind='elevation-unsupported'` and `manualCommand` fallback in `Windows.psm1` when sandboxed agent terminals block `Verb='RunAs'`.
- Add optional read-only Android `thermal` (`dumpsys thermalservice`), `appSizes` (`dumpsys diskstats` top 25 packages) and two-point `--frame-window-seconds 2..30` `gfxinfo` interval deltas with PID and `Stats since` origin verification.
- Add Open Graph, Twitter Card, Schema.org JSON-LD (`Organization`, `WebSite`, `WebPage`, `SoftwareApplication`), `og-preview.png`, `robots.txt`, `sitemap.xml` and build-time SEO validation for public HTML delivery.
- Add `CLAUDE.md`, JSON Schema contract tests and the zero-trust audit and upgrade records (`docs/research/audit-perfection.md`, `docs/plan/done/perfection-upgrade.md`).

### Changed
- Store compact `syrin-approval-receipt` records in `approvals/<guid>.json` instead of duplicating the entire immutable `plan.json` payload on every execution.
- Consolidate typography and border-radius values into `src/shared/tokens.css` (`--text-xs` through `--text-display`, `--radius-sm` through `--radius-pill`) across landing and report stylesheets.
- Tighten `audit.schema.json`, `plan.schema.json` and `proposals.schema.json` with `additionalProperties: false` and complete runtime field definitions; enforce output-tree allowlists on `dist/` and `prompts/` in `tools/build.py`.
- Synchronize architecture, execution, device, command, validation and support documentation with the current runtime and `4.1.0-preview.1` baseline.

### Removed
- Remove superseded `v4.0.0-preview.2` and `v4.1.0-preview.1` ZIP and Markdown files from trunk `dist/` and `prompts/` (published release tags and assets remain intact), two unused i18n keys (`downloaded`, `startupError`) from `ui.{en,vi}.json`, and 18 duplicate overwritten keys in `src/report/report.mjs`.

### Fixed
- Filter out `\Microsoft\WindowsApps\python*.exe` Store alias stubs, add `py.exe -3` fallback and reject `-FrameWindowSeconds` without `-Package` in `android-audit.ps1`; enforce `adb.exe` on Windows in `adbclient.py`, reject `-GroupId` outside `-Execute` in `quarantine.ps1`, and emit structured JSON when `audit.py` is invoked under Python < 3.10.
- Parse serialized ISO-8601 file timestamps with `DateTimeStyles::RoundtripKind` in `IO.psm1` and `Report.psm1` so timezone conversion never rejects valid fingerprints.
- Replace hardcoded Vietnamese suffixes in `Get-SyrinRadar` labels with English canonical labels, wire `__I18N_title__` and `__I18N_description__` in `src/web/page.html`, pin support-matrix links to `/blob/<version>/docs/feat/support.md`, and remove en-dash punctuation from report copy.
- Clarify in `stage0-audit.md` (EN/VI) that `run-elevated.ps1` requires `approve` policy mode and is blocked under `audit` mode, and repair broken historical v3.6 HTML links in `docs/research/audit-safety.md`.

### Security
- Reject batch/command script shims (`adb.bat`, `adb.cmd`) on Windows hosts in `AdbClient` and restrict multi-agent installer targets to a closed profile-relative allowlist with transactional staging and rollback.

## [4.1.0-preview.1] - 2026-11-14

### Added
- Add an English/Vietnamese guided report demo, a screenshot of synthetic example data and Q&A entry points for preview feedback.
- Add Android readiness checks with distinct USB states and optional app/task inputs; preserve frame capture times and counter provenance in bilingual local reports.
- Add a read-only Android USB diagnostic adapter with exact serial/transport selection, active-user checks, bounded subprocesses, optional package/frame inventory and bilingual local reports; real-device qualification remains open.
- Persist Windows audit-only mode and protected paths; bind reviewed plans to policy files and revalidate restrictions between atomic items.
- Add scoped cooperative stop requests and metadata-based quarantine recovery inspection without automatic repair or deletion.
- Collect bounded Windows CPU/memory series, exclude reused process IDs and constrain before/after comparisons to matching capture settings and workload labels.
- Add candidate beta procedures and release-asset provenance attestations after published bytes match the validated build; all eight published assets passed repository, workflow, source-commit and tag verification in the [publication record](docs/research/device-release-verification.md).

### Changed
- Add Windows/Android selection to the offline bilingual HTML and shared skill/prompt while preserving Windows profile values.
- Show capture age and snapshot limitations; minimize Android shared reports to explicit storage, memory and battery fields.
- Deliver the `4.1.0-preview.1` pre-release while preserving previous release assets.

### Fixed
- Resolve packaged support-document links against the matching release tag so extracted skills do not point at missing local documentation.
- Reduce Windows planning overhead by evaluating source policy in the native helper and reading file identity and metadata from one handle; retain per-path ancestor checks and the existing planning budget.
- Parse `/data` storage measurements reported through Android's `/data/user/<id>` bind mount, preserve the query and observed mount locally, and omit the user-specific mount from shared exports.
- Allow ADB to start its local server on first use by retaining its default localhost host selection; continue clearing inherited remote-routing environment variables and fixing the server port.
- Select one Python executable when Windows PATH contains both a regular installation and a WindowsApps entry, preventing Android discovery from invoking a joined invalid path.
- Preserve manual Pages redeployment of older tags by limiting new provenance staging and signing to release events; continue verifying the deployed HTML against published digests.

### Security
- Keep the supplied Android case data, seed lists and external package catalog outside public packages; no archive command is imported as execution authority.
- Block system-adapter entry points under audit-only policy and apply path protection to both original and stored files.

## [4.0.0-preview.2] - 2026-10-30

### Added
- Record report-generation phases, verified history counts, elapsed time and terminal status in a private progress file; retain progress under `-Quiet` and report 100% only after HTML commits.

### Changed
- Read journal events in native batches while retaining live path validation, individual JSON parsing, raw-byte digests and the existing journal format.

### Fixed
- Expose pause/resume animation controls as action buttons rather than contradictory pressed-state toggles; verify renderer cancellation across visibility and motion states.
- Skip unused private history reads when generating aggregate-only shared reports.
- Fix ZIP creator metadata for portable generation while preserving the published Windows artifact bytes.
- Deploy the site staged by the validated Windows release job, verify it against published asset digests and support explicit redeployment of an existing tag.

## [4.0.0-preview.1] - 2026-10-29

### Added
- Add one English-default EN/VI landing HTML with both embedded packages, prompt generation, fonts and a synthetic report; preserve the active profile and tab when switching languages.
- Add bilingual report controls, history search/state filters, persistent selections across filters and a print summary.
- Add a shared bounded review-lens renderer and licensed offline typography, with pause, hidden/offscreen and reduced-motion paths.
- Add an allowlisted Pages publisher gated by validation of the published release tag and deployment metadata for live verification.
- Add durable audit progress, large-tree/history regression coverage and offline history pagination with persistent item selection.
- Add reviewed file plans with explicit item selection, owned storage, append-only journals, conflict recovery, reconciliation and explicit legacy CSV import.
- Add native handle-based file identity checks for same-volume rename and selected-file purge.
- Add versioned audit/proposal schemas, session history, guarded comparisons and aggregate-only report exports.
- Add isolated Windows/Node/package regression tests and a CI workflow with pinned actions and read-only permissions.
- Add package manifests, deterministic artifact checksums and safe standalone runtime extraction.

### Changed
- Resolve trusted path-policy references per operation while continuing live ancestor and native handle checks; parse and hash journal documents from the same read.
- Run path normalization and live ancestor checks within the existing native helper to reduce PowerShell overhead in long histories.
- Include all loaded report history and cap decorative rendering at 24 frames per second with 160/280 initial points.
- Give storage scans a share of the requested audit budget and retain explicit partial coverage.
- Rename the project to Syrin clean and replace the imported 3.6 delivery with the first 4.0 preview; the file-plan runtime replaces the original command contract and environment qualification remains open.
- Generate both language packages, prompts and pages from canonical runtime, policy, report and web sources.
- Stage installation outside skill-discovery folders, serialize updates and retain previous versions for rollback.
- Limit automatic mutation to the supported file lifecycle; system tuning and repair remain advisory pending validated adapters.
- Clarify privacy, recovery and support limits; keep VM qualification explicitly unverified at the owner's request.
- Group advanced page options, prioritize the introduction on mobile and add controllable report animation.

### Fixed
- Apply the source-path policy to legacy imports and recheck it during restore, including cloud roots registered after a plan was approved.
- Bind approval validation, execution and persisted session plans to one captured document so concurrent plan replacement cannot change a reviewed restore destination.
- Preserve caller IO commands across nested runtime entry points instead of force-reloading shared modules.
- Pass a true null backup path to .NET when replacing reports/state in Windows PowerShell 5.1; cover report regeneration and locked-file preservation with regression tests.
- Prevent whole-root purge, dropped restore conflicts, unjournaled transfers, cloud-prefix mistakes and unsafe plan/root overlap.
- Preserve unknown/partial collector states, typed storage categories, system-volume identity and separate StartupApproved identities.
- Preserve native PowerShell arguments with Unicode, quotes, empty values and trailing backslashes; distinguish UAC cancellation from other failures.
- Validate report input before replacing output, honor no-HTML mode and avoid blanket Windows lifecycle claims.
- Reject unexpected package files, verify staged installation and restore previous versions after failed commits.
- Add tab roles, selection state, controls and keyboard navigation to both landing pages.

## [3.6] - 2026-10-28
### Added
- English skill (English instructions, replies in the user's language, accepts Vietnamese and English commands) and English web page and prompt.
- "Report" option in the profile builder: 3D (default), simple, none.
- Appendices B (report template) and C (`make-report.ps1`) in the .md prompts so prompt-only users also get the 3D report.
- Bilingual report template; `make-report.ps1 -Lang vi|en -Template`.
### Fixed
- Customise grid: 3x3 layout, no clipped select text or placeholders.
- Appendix extraction anchored to heading lines so blocks are never confused.

## [3.5] - 2026-10-27
### Added
- 3D report built from real audit data (`make-report.ps1`, `assets/report-template.html`).
- WebGL scene with 2D fallback and adaptive particle count; first-run guide; `?check` layout self-test.
### Fixed
- Vietnamese diacritics colliding with the next line; status label overlapping text; grid blow-out at mid widths; fluid headline fitting.

## [3.4] - 2026-10-27
### Added
- Agent Skill packaging with bundled scripts (`run-elevated`, `new-restorepoint`, `quarantine`).
- Redesigned page following anti-slop rules; scroll-driven 3D story (scan, quarantine, clean).
### Changed
- Personal files go to a quarantine with a manifest instead of the Recycle Bin.

## [3.3] - 2026-10-27
### Added
- Plain-language approval screen, sub-codes for files, 5-line explanations, 6-point confirmation, natural-language approval.

## [3.2] - 2026-10-27
### Changed
- Prompt about 30% shorter; quota rules (big scripts, small output, reuse, retry limits, generated reports); budget option; audit script with `-OutDir`/`-Quiet` and JSON output.

## [3.1] - 2026-10-27
### Changed
- Fully automated: self-elevation through UAC, progress file and `Continue`, `STOP`, per-code undo, dry run before confirmation.

## [3.0] - 2026-10-27
### Fixed
- Restore point 24-hour limit, laptop hibernate contradiction, junction-safe scanning, XMP detection, language-independent counters, Windows 11 detection, `Optimize-VHD` on Home, OneDrive deletion risk, script encoding.
### Added
- ARM64, VM, small-drive, managed-device branches; repair (R) and manual (M) groups; health card.

## [2.0]
- Initial universal draft (see `docs/history/`).
