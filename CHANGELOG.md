# Changelog

All notable changes to this project. Dates are 2026.

## [Unreleased]

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
- Include all loaded report history and cap decorative rendering at 24 frames per second with 250/500 points.
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
