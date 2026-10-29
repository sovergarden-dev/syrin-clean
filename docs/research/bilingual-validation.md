# Bilingual HTML and preview validation

Status: local verification complete; hosted validation and publication pending, 2026-10-29.

## Start time

2026-10-29, Asia/Bangkok. The owner approved merge review of PR #1, a bilingual English-default HTML and upgraded reports, then explicitly selected GitHub Pages plus an offline HTML in a pre-release.

## Initial purpose

Make the same artifact useful from a public link or offline, preserve the established runtime approval boundary and improve report navigation without hiding uncertainty. Real reports must never enter Pages or release assets.

## Strategy

Read the pinned [Hallmark](https://github.com/nutlope/hallmark/tree/8f6969f8922caabde9de1784959eae11ddf68073/skills/hallmark) and [Impeccable](https://github.com/pbakaus/impeccable/tree/5e745ace7e151feb2a93d360d0281fe39448b857/.agents/skills/impeccable) guidance. Keep the green identity and embedded Bricolage Grotesque/Be Vietnam Pro typography, distinguish landing and report tasks, and use one shared bounded canvas. The unavailable Impeccable launcher was replaced by direct project-context reads. Browser work uses CUA; no Puppeteer or fresh-subagent review is claimed.

## Checklist

- [x] Merge review found a mutable-plan reread; reproduce it with a fixture and bind execution/session creation to the approved snapshot. PR #1 merged as `f4d1d35` after both workflows passed, and the main validation also passed.
- [x] One bilingual landing document, English-default public sample and embedded assets; language changes preserve profile values and active tabs.
- [x] Report language/search/state controls preserve selections and exact item IDs across pages. Purged rows remain disabled; empty filters explain how to recover.
- [x] Actual desktop/mobile browser checks, download comparisons, keyboard focus and pause/offscreen state checks.
- [x] Final full local regression suite: 18 quarantine cases, 11 runtime groups, report and landing model checks, the scale fixture and eight packaging/delivery tests passed. The 65 generated outputs match their sources, including flat release checksums and legacy source-policy checks.
- [ ] Clean-checkout CI on the delivery revision.
- [ ] Live Pages and release downloads match the final artifacts and version metadata.

## Result and verification

Release review also found that legacy storage used local-path validation without the full source policy. A fixture reproduced acceptance of a legacy root inside a registered cloud directory. The fix applies source checks during import planning and stored-path validation; a second scenario registers the cloud root after preparing a restore plan and requires the stored file to remain untouched. This is a synthetic provider-boundary check, not qualification of a real cloud provider.

The public preview uses synthetic data and an explicit banner. Real reports remain outside source. The landing and sample report have no external asset imports; both language packages and the sample report are embedded in the landing. Fonts are pinned local WOFF2 files with upstream OFL texts. Release attachments are downloads; the Pages link is the hosted entry point, and page-owned sample links request a separate tab.

Browser observations covered English and Vietnamese at 320, 390, 768, 1280, 1920 and 2560 px. The viewport override affected the selected tab; actual dimensions were inspected and the landing matrix was repeated on its active tab. A report language select initially extended past the 320 px viewport and was corrected to wrap within the header. Interactive bounds now fit the checked widths; clipping was not treated as a pass.

Report checks selected items on two pages, narrowed the list with search, changed language and produced exactly the two original IDs. A purged filter had six disabled rows and no enabled restore request; a missing search term showed a recovery hint. Keyboard focus showed a 3 px outline. Native tabs responded to arrow keys. Reset preserved the language while restoring profile defaults. Sample links opened an actual new tab.

Primary computed text/background token pairs ranged from 6.01:1 to 13.15:1; the control-border pair was 3.99:1. This is a measured palette check, not complete accessibility certification. Hallmark static checks reported zero FAIL, REFLEX and WARN findings after fixes. One print-only absolute-black waiver covered eight occurrences of the same rule; one finish note documents consistent native report controls. Its render driver was not run; screenshots and layout checks were performed through CUA.

Initial English/VI ZIP downloads matched their generated artifacts. Both default Markdown downloads are compared byte-for-byte by the landing-model test; final downloaded assets must be rechecked after the last bundled-source change. Full Windows, hardware/provider, native file-opening and assistive-technology qualification remain open. System reduced-motion changes were not performed on the user's workstation.

## Decision

Action: [preview release plan](../plan/bilingual-experience.md), [visual system](../../DESIGN.md), [architecture](../arch/project.md) and [support matrix](../feat/support.md). Publish only a pre-release after current-head CI and live artifact checks. The 4.0 preview marks the new reviewed-plan command and delivery contracts rather than implying stable environment qualification.
