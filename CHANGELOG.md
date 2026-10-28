# Changelog

All notable changes to this project. Dates are 2026.

## [Unreleased]
### Changed
- Rename the project to Syrin clean and the skill identifier to `syrin-clean`; keep the imported 3.6 version.
- Rename both language editions, installers, downloadable artifacts, report branding and default working folders; rebuild embedded downloads from the renamed sources.
- Add GitHub download links and document the source-to-artifact build flow.

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
