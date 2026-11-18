# Zero-trust audit and perfection upgrade record

## Start time

2026-11-18, Asia/Bangkok.

## Initial purpose

Perform a zero-trust audit of `sovergarden-dev/syrin-clean` against commit `85475fedbeb3428d34a0f182b36e95d2de2b3686` (`4.1.0-preview.1` pre-release, 189 tracked files), identify every machine-decidable defect (`CERTAIN`), structural candidate (`SUGGESTED`), and architectural/UX gap discovered during real-world Windows storage cleanup and sandboxed agent execution, and then execute the complete `P0` through `P3` remediation and upgrade roadmap without adding external package dependencies or expanding automated mutation beyond the journaled Windows file lifecycle.

## Strategy

1. Lock repository scope (`189` tracked files at `85475fed`) and run mechanical sweeps across PowerShell 5.1 modules/scripts, Python 3.10+ Android adapters and packaging tools, Node.js 22+ ES modules, CSS token layers, bilingual JSON copy, JSON Schemas, GitHub Actions workflows and Markdown documentation.
2. Separate `CERTAIN` defects (exact file:line evidence) from `SUGGESTED` structural candidates and prioritized capability upgrades (`P0` runtime scale and safety, `P1` Windows collector coverage, `P2` UX and multi-agent ergonomics, `P3` Android read-only depth, schemas and SEO).
3. Implement changes strictly in canonical sources (`src/`, `tools/`, `.github/workflows/`, `docs/`), regenerate all `83` derived artifacts via `tools/build.py`, normalize all `.ps1`/`.psm1` files to UTF-8 with BOM and CRLF, and verify every changed contract through isolated automated suites (`tests/run.ps1`) and mechanical format/plan/release/suite linters.

## Checklist

- [x] Lock baseline `85475fedbeb3428d34a0f182b36e95d2de2b3686` and classify all 15 `CERTAIN` findings and 2 `SUGGESTED` candidates across code, UI, schemas, packaging and docs.
- [x] Implement `P0` native C# 5 `CollectPlanFiles` and `KnownFolder` (`SHGetKnownFolderPath`) in `IO.psm1`, single-root `Get-Item` scan in `Audit.psm1`, compact `syrin-approval-receipt` files in `Quarantine.psm1`, `DateTimeStyles::RoundtripKind` UTC timestamp parsing, and Windows Store `WindowsApps\python*.exe` alias filtering plus `adb.exe` enforcement.
- [x] Implement `P1` canonical English radar labels, redirected `Downloads` scanning in `largeFiles`, expanded multi-profile browser/updater/Zalo/bun/Playwright/WSL2/Recycle Bin/pagefile radar entries, unclassified `hotspots`, project-anchored `devArtifacts` and enriched `apps` metadata.
- [x] Implement `P2` semantic `--text-*` and `--radius-*` CSS tokens, `#purge-request` (`Prepare permanent delete request`) gated by `canRequestPurge`, deterministic directory `groups[]` (`G1..Gn`) and `-GroupId` execution, multi-agent `install.ps1` targets, and `elevation-unsupported` (`manualCommand`) handling in `Windows.psm1`.
- [x] Implement `P3` opt-in read-only Android `thermal`, `appSizes` (`diskstats`) and `--frame-window-seconds 2..30` two-point `gfxinfo` deltas, tightened `additionalProperties: false` JSON Schemas, prerendered Open Graph/Twitter Card/JSON-LD metadata, `docs/images/og-preview.png` (`1200x630` PNG), `robots.txt` and `sitemap.xml` Pages staging, output-tree allowlists, `CLAUDE.md` and synchronized docs.
- [x] Run `tools/build.py`, full `tests/run.ps1` regression and scale suite, and mechanical format/plan/release/suite linters.

## Result

All 15 `CERTAIN` findings and both `SUGGESTED` candidates from baseline `85475fed` were resolved alongside the `P0` through `P3` upgrades:

1. **Android host resolution (`CERTAIN #1`)**: `src/runtime/scripts/android-audit.ps1` now skips `\Microsoft\WindowsApps\python*.exe` Store alias stubs and falls back to `py.exe -3`; `src/runtime/android/adbclient.py` enforces `adb.exe` on Windows (`os.name == "nt"`), rejecting `.bat`/`.cmd` shims; `src/runtime/android/audit.py` checks `sys.version_info >= (3, 10)` before importing later modules.
2. **Bilingual radar/UI/SEO hygiene (`CERTAIN #2` through `#6`)**: `Get-SyrinRadar` uses canonical English labels; `src/web/page.html` binds `__I18N_title__`, `__I18N_description__` and version-pinned `__SUPPORT_URL__` (`/blob/<version>/docs/feat/support.md`); dead keys (`downloaded`, `startupError`) in `ui.{en,vi}.json`, 18 duplicate overwritten keys in `src/report/report.mjs`, and en-dash punctuation in report copy were removed.
3. **Schema and instruction alignment (`CERTAIN #7`, `#8`)**: `audit.schema.json`, `plan.schema.json` and `proposals.schema.json` now enforce `additionalProperties: false` and match every runtime field; `stage0-audit.md` (EN/VI) documents that `run-elevated.ps1` requires `approve` policy mode and is blocked under `audit` mode.
4. **Documentation drift and trunk artifact hygiene (`CERTAIN #9` through `#15`, `SUGGESTED #1`, `#2`)**: `docs/index.md` links every reference file; `docs/arch/project.md`, `docs/arch/execution.md`, `PRODUCT.md`, `DESIGN.md`, `docs/feat/devices.md`, `docs/feat/support.md`, `docs/ref/commands.md`, `docs/ref/validation.md`, `README.md`, `README.vi.md` and `docs/research/audit-safety.md` match current code and carry updated `v4.1.0-preview.1` anchor stamps; typography/radius literals are consolidated in `src/shared/tokens.css`; directory `groups[]` (`G1..Gn`) and compact approval receipts are active; the four superseded `v4.0.0-preview.2` files were removed from trunk `dist/` and `prompts/` with `check_output_trees` preventing future drift.

### Verification

- **Build and SEO/JS parity**: `python -B -X utf8 tools/build.py --check` exited `0` (`Build check OK: 83 files match canonical sources`), validating `dist/`, `prompts/` and `skill/` allowlists, JSON-LD `Organization` (`alternateName`, `sameAs`), `<= 60` char titles, `<= 155` char descriptions and `node --check` on all inline scripts.
- **Scale planning and journal benchmark (`tests/scale.ps1`)**: 2,048-file planning dropped from the prior `111,344 ms` baseline (`docs/plan/device-support.md:39`) to **`3,391 ms`** (`32.8x` faster) while retaining per-node policy/attribute/identity checks; 12-session / 4,098-event journal replay completed in `5,232 ms` and full HTML report generation in `6,623 ms`.
- **Full automated suite (`tests/run.ps1`)**: Exited `0` across PowerShell 5.1 AST parsing (`22` `.ps1`/`.psm1` files), `node tests/report.mjs`, `node tests/page.mjs`, `tests/quarantine.ps1` (`22 passed`), `tests/runtime.ps1` (`18` PASS blocks) and `python -m unittest` (`Ran 29 tests in 17.562s - OK`).
- **Remaining unverified runtime boundaries (`coding.B3` honesty floor)**: Real System Restore point creation/rollback on a disposable Windows VM, ReFS/ARM64/custom cloud-provider placeholders, live screen-reader conformance, and live Android 14+ verification of the new opt-in `thermal`, `diskstats` and `--frame-window-seconds` collectors on physical OEM phones remain unverified by synthetic host tests.

### Corroborating links

- [Prior safety audit (`a0752aa`)](audit-safety.md) and [Android live validation (`4.1.0-preview.1`)](android-live-validation.md).
- [Device release verification (`4.1.0-preview.1`)](device-release-verification.md) and [active hardware/VM qualification plan](../plan/device-support.md).
- Microsoft Win32 API contracts: [SHGetKnownFolderPath](https://learn.microsoft.com/en-us/windows/win32/api/shlobj_core/nf-shlobj_core-shgetknownfolderpath) and [GetFileInformationByHandle](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getfileinformationbyhandle).

## Decision

- **Action**: Completed in [perfection-upgrade.md](../plan/done/perfection-upgrade.md) and released as pre-release `4.1.0-preview.2` in [CHANGELOG.md](../../CHANGELOG.md) and [project.json](../../project.json).
- **Cross-references**: [Architecture](../arch/project.md), [execution contracts](../arch/execution.md), [device diagnostics](../feat/devices.md), [support matrix](../feat/support.md), [commands](../ref/commands.md), [validation](../ref/validation.md) and [CLAUDE.md](../../CLAUDE.md).
