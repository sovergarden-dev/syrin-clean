# Perfection audit remediation and P0-P3 upgrade plan

Completed 2026-11-18. Base: `85475fedbeb3428d34a0f182b36e95d2de2b3686`, released `4.1.0-preview.1`. Source audit: [audit-perfection.md](../../research/audit-perfection.md).

## Goal

Eliminate all 15 `CERTAIN` defects and both `SUGGESTED` structural drift items identified in the zero-trust repository audit, while delivering the `P0` through `P3` runtime, collector, UX, multi-agent, Android and SEO upgrades without adding external dependencies or widening the mutation surface beyond the journaled Windows file lifecycle.

## 1. P0 runtime scale, journal compactness and timestamp safety

- [x] Replace per-file PowerShell `Get-Item` and repeated ancestor re-walks in `Get-SyrinFiles` with native C# 5 `[Syrin.NativeFiles]::CollectPlanFiles` in `src/runtime/modules/IO.psm1`, sorting discovered files deterministically by canonical path while preserving per-node reparse, offline, recall, ambiguous-segment and source-policy checks.
- [x] Refactor `Get-SyrinScan` in `src/runtime/modules/Audit.psm1` to call `Get-Item` once on the scan root and push `[IO.FileSystemInfo]` entries directly from `EnumerateFileSystemInfos()`, eliminating per-node PowerShell pipeline overhead and tracking `latestWriteUtc`.
- [x] Add `[Syrin.NativeFiles]::KnownFolder` (`SHGetKnownFolderPath` with `KF_FLAG_DONT_VERIFY`) and `Get-SyrinUserFolder` with automatic `$env:USERPROFILE` test-isolation detection.
- [x] Replace full `$plan` duplication in `approvals/<guid>.json` (`src/runtime/modules/Quarantine.psm1`) with compact `syrin-approval-receipt` records (`planId`, `sessionId`, `operation`, `digest`, `selected`, `selectedGroups`, `timeUtc`).
- [x] Parse serialized ISO-8601 file timestamps with `DateTimeStyles::RoundtripKind` in `IO.psm1` and `Report.psm1` so timezone conversion cannot corrupt `ToFileTimeUtc()` identity checks.
- [x] Filter out `\Microsoft\WindowsApps\python*.exe` Store alias stubs and add `py.exe -3` fallback in `src/runtime/scripts/android-audit.ps1`; enforce `adb.exe` on Windows in `src/runtime/android/adbclient.py` (`CERTAIN #1`) and emit structured JSON if `audit.py` runs under Python < 3.10.

## 2. P1 Windows storage intelligence and collector coverage

- [x] Replace hardcoded Vietnamese radar suffixes (`iPhone backup (CHI LIET KE)`, `Captures (DU LIEU CA NHAN)`) with canonical English labels in `Get-SyrinRadar` (`CERTAIN #2`).
- [x] Restore redirected `Downloads` scanning in `largeFiles` via `Get-SyrinUserFolder 'Downloads'`.
- [x] Expand `Get-SyrinRadar` with `Recycle Bin (Current User)`, `NVIDIA UpdateFramework`, `Electron App Updaters` (`*-updater`), multi-profile Chromium caches (`Chrome`, `Edge`, `Brave`, `CocCoc` across `Default` and `Profile *`), `Zalo PC (Local)` and `Zalo Data (Roaming)`, `bun cache`, `Playwright browsers`, `WSL2 Distributions`, split `Syrin Quarantine (Stored Files)` versus `Syrin Quarantine (Journals)`, and `System Hibernate and Pagefile`.
- [x] Add `Get-SyrinHotspots` (`hotspots` collector) for top 15 unclassified directories >= 500 MB with separate `rootLastWriteUtc` and `latestContentWriteUtc` timestamps so stale parent timestamps do not disguise active data.
- [x] Add `Get-SyrinDevArtifacts` (`devArtifacts` collector) for project-anchored `node_modules` (`package.json`), `target` (`Cargo.toml`) and `.venv` (`pyvenv.cfg`) with `projectLastWriteUtc` and `staleDays`, isolated to `$env:USERPROFILE` during fixture tests.
- [x] Enrich `apps` collector rows with `InstallDate`, `hasQuietUninstall` boolean, nullable `EstimatedSize` and shallow `latestActivityUtc` sampling.

## 3. P2 UX flow, design tokens and multi-agent ergonomics

- [x] Consolidate scattered typography and radius literals into `src/shared/tokens.css` (`--text-xs` through `--text-display`, `--radius-sm` through `--radius-pill`) across `src/web/page.css` and `src/report/report.css` (`SUGGESTED #1`).
- [x] Remove all 18 overwritten duplicate copy keys and en-dash punctuation in `src/report/report.mjs` (`CERTAIN #5b`, `CERTAIN #6`) and remove dead keys `downloaded` and `startupError` in `src/web/ui.{en,vi}.json` (`CERTAIN #5a`).
- [x] Add `canRequestPurge` and the `#purge-request` (`Prepare permanent delete request`) button in `src/report/report.mjs`, enabled only when every selected item is intact `quarantined` in a non-imported session.
- [x] Add deterministic directory `groups[]` (`G1..Gn`) in `New-SyrinFilePlan` and `-GroupId` execution support in `Invoke-SyrinFilePlan` and `quarantine.ps1` (`SUGGESTED #2`).
- [x] Add `-IncludeDetectedAgents` and `-AgentTargets` (`@('.claude','.agents','.codex','.cursor','.gemini\antigravity')`) to `src/install.ps1` with transactional staging and rollback.
- [x] Classify sandboxed `Verb='RunAs'` blocks (Win32 `5`, `50`, `740`) as `failureKind='elevation-unsupported'` with a copy-ready `manualCommand` in `Windows.psm1`, and clarify in `stage0-audit.md` (EN/VI) that `run-elevated.ps1` requires `approve` policy mode (`CERTAIN #8`).

## 4. P3 Android read-only depth, schemas, SEO and repository hygiene

- [x] Add opt-in read-only Android `thermal` (`dumpsys thermalservice`), `appSizes` (`dumpsys diskstats` top 25 packages) and `--frame-window-seconds 2..30` two-point `gfxinfo` deltas verified by matching PID and `Stats since` origin.
- [x] Tighten `audit.schema.json`, `plan.schema.json` and `proposals.schema.json` with `additionalProperties: false` and complete runtime properties (`CERTAIN #7`), verified by automated schema contract tests in `tests/test_build.py`.
- [x] Wire `__I18N_title__` and `__I18N_description__` (`CERTAIN #3`), pin `__SUPPORT_URL__` to `/blob/<version>/docs/feat/support.md` (`CERTAIN #4`), add Open Graph, Twitter Card and Schema.org JSON-LD (`Organization`, `WebSite`, `WebPage`, `SoftwareApplication`), generate true 1200x630 PNG `docs/images/og-preview.png`, and stage `og-preview.png`, `robots.txt` and `sitemap.xml` in `tools/publish_site.py` and `.github/workflows/pages.yml` (preserving four-file legacy manual redeployments).
- [x] Remove the four superseded `v4.0.0-preview.2` artifacts from `dist/` and `prompts/` (`CERTAIN #15`), enforce `check_output_trees` on `dist/` and `prompts/` in `tools/build.py`, normalize all `.ps1`/`.psm1` files to UTF-8 BOM + CRLF, create `CLAUDE.md`, synchronize drifted docs (`CERTAIN #9` through `#14`) and record `## [Unreleased]` in `CHANGELOG.md`.
