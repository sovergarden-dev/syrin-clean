# Bilingual HTML experience and preview release

Status: in progress, 2026-10-29. The owner approved merging PR #1 and publishing GitHub Pages plus a bilingual offline HTML asset in a pre-release. PR #1 merged as `f4d1d35` after the approval-snapshot regression was fixed in `856b16a` and both CI workflows passed.

## Scope

- [x] Replace the separate landing markup with one bilingual document, English by default; preserve profile values, supported controls, download integrity and the approval boundary.
- [x] Redesign the landing and report surfaces using the existing green identity and the referenced Hallmark/Impeccable guidance. Use a bounded review-lens interaction, embedded typography, visible defaults, keyboard access and reduced-motion alternatives.
- [x] Add in-place report language switching, useful history search/state filtering and a clearly synthetic public report. Preserve unknown/partial data, selection identity, sharing restrictions and full offline history.
- [x] Produce a deterministic standalone HTML, sample report, both skill packages, prompts, checksums and an allowlisted Pages build. Do not publish machine reports.
- [x] Verify local model/package/runtime regressions, both languages, downloads, controls, desktop/mobile layouts and pause/offscreen state through the supported browser tools. System reduced-motion changes and native file-opening remain explicitly separate.
- [ ] Review and integrate the new source, pass CI, publish a preview release and Pages, then verify the live files and actual download hashes.

Files: replace `src/web/page.en.html` and `page.vi.html` with `page.html`; update `page.js`, `page.css`, locale data, `src/report/*`, `tools/build.py`, relevant tests and documentation. Add shared tokens/fonts and licensing, a synthetic demo, a Pages workflow and an allowlisted publishing helper. Generated artifacts follow the builder; obsolete generated edition HTML is retired when the unified artifact replaces it.

The release remains explicitly experimental because VM/System Restore, broader platform/provider and full assistive-technology qualification are open. Existing supported file operations keep their review and identity checks. No machine cleanup, application shutdown, process-priority or Windows Update changes belong to this work.

## References and verification boundary

- [Hallmark](https://github.com/nutlope/hallmark/tree/8f6969f8922caabde9de1784959eae11ddf68073/skills/hallmark): preserve product behavior, establish a deliberate visual system, budget one focal interaction, check the rendered result.
- [Impeccable](https://github.com/pbakaus/impeccable/tree/5e745ace7e151feb2a93d360d0281fe39448b857/.agents/skills/impeccable): distinguish the landing page's discovery task from a report's reading/operating task, validate state coverage and control motion cost.
- Reference packages were read in a temporary directory, not installed globally. Impeccable's launcher is unavailable in this project, so project context is read directly. Hallmark's static checks may run locally; all browser interaction uses the host's supported CUA API rather than its Puppeteer render driver. The review is performed in this thread, not claimed as a fresh subagent review.

The owner selected Pages plus an offline asset after the distinction between a release download and a hosted HTML page was explained. The browser decides whether a GitHub link opens a new tab; page-owned external/sample links request a new tab without automatic pop-ups.
