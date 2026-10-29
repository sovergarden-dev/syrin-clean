# Bilingual HTML and preview validation

Status: completed and amended after deployment recovery, 2026-10-29.

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
- [x] Clean-checkout CI on the delivery revision and Windows/Ubuntu checks on the deployment repair.
- [x] Live HTTPS Pages, all eight downloaded release assets and actual live-browser package/Markdown downloads match the final artifacts and version metadata.

## Result and verification

Release review also found that legacy storage used local-path validation without the full source policy. A fixture reproduced acceptance of a legacy root inside a registered cloud directory. The fix applies source checks during import planning and stored-path validation; a second scenario registers the cloud root after preparing a restore plan and requires the stored file to remain untouched. This is a synthetic provider-boundary check, not qualification of a real cloud provider.

The public preview uses synthetic data and an explicit banner. Real reports remain outside source. The landing and sample report have no external asset imports; both language packages and the sample report are embedded in the landing. Fonts are pinned local WOFF2 files with upstream OFL texts. Release attachments are downloads; the Pages link is the hosted entry point, and page-owned sample links request a separate tab.

Browser observations covered English and Vietnamese at 320, 390, 768, 1280, 1920 and 2560 px. The viewport override affected the selected tab; actual dimensions were inspected and the landing matrix was repeated on its active tab. A report language select initially extended past the 320 px viewport and was corrected to wrap within the header. Interactive bounds now fit the checked widths; clipping was not treated as a pass.

Report checks selected items on two pages, narrowed the list with search, changed language and produced exactly the two original IDs. A purged filter had six disabled rows and no enabled restore request; a missing search term showed a recovery hint. Keyboard focus showed a 3 px outline. Native tabs responded to arrow keys. Reset preserved the language while restoring profile defaults. Sample links opened an actual new tab.

Primary computed text/background token pairs ranged from 6.01:1 to 13.15:1; the control-border pair was 3.99:1. This is a measured palette check, not complete accessibility certification. Hallmark static checks reported zero FAIL, REFLEX and WARN findings after fixes. One print-only absolute-black waiver covered eight occurrences of the same rule; one finish note documents consistent native report controls. Its render driver was not run; screenshots and layout checks were performed through CUA.

Initial English/VI ZIP downloads matched their generated artifacts. Both default Markdown downloads are compared byte-for-byte by the landing-model test; final downloaded assets must be rechecked after the last bundled-source change. Full Windows, hardware/provider, native file-opening and assistive-technology qualification remain open. System reduced-motion changes were not performed on the user's workstation.

## Decision

Action: [completed preview release plan](../plan/done/bilingual-experience.md), [visual system](../../DESIGN.md), [architecture](../arch/project.md) and [support matrix](../feat/support.md). The pre-release is published after current-head CI and live artifact checks. The 4.0 preview marks the new reviewed-plan command and delivery contracts rather than implying stable environment qualification.

## Amendments

- 2026-10-29: [PR #2](https://github.com/sovergarden-dev/syrin-clean/pull/2) merged at `da2b0c9467de388bf875c4ed0cf6423887383305`, which is the immutable `4.0.0-preview.1` tag. Its [main validation](https://github.com/sovergarden-dev/syrin-clean/actions/runs/40824349809) and [tag validation](https://github.com/sovergarden-dev/syrin-clean/actions/runs/40825577982) passed. All eight release assets were downloaded and checked against GitHub's SHA256 values; the flat checksum file covers the six payloads and the manifest.
- 2026-10-29: the original [Pages run](https://github.com/sovergarden-dev/syrin-clean/actions/runs/40825594707) failed first because the environment allowed only main, then because ZIP creator metadata differed on Linux. The exact release tag was added to the environment policy. A regression reproduced the platform default mismatch, and `ZipInfo.create_system` is now fixed to the existing Windows value. No published asset or tag was replaced.
- 2026-10-29: [PR #3](https://github.com/sovergarden-dev/syrin-clean/pull/3) merged at `24ca1cc` after both Windows and portable-artifact jobs passed. The [successful recovery](https://github.com/sovergarden-dev/syrin-clean/actions/runs/40829293196) revalidated the published tag on Windows, transferred its allowlisted site and checked both HTML files against the published release digests before deployment. The old failed run remains part of the record.
- 2026-10-29: live HTTPS returned 200 for the landing and sample. The landing SHA256 is `e12d4e7c09d94d649d0831d7e247a6af7af286251c49de61840208e9c322b707`; the sample SHA256 is `6f52615d530f67a9fc69c1c7ff0f22d4f5298f59f0206d98137cba7c4ca34c44`. `version.json` reports the published tag and revision `da2b0c9`. CUA confirmed the English-default live page, VI switching, a separate sample-report tab, successful copy feedback and no sampled console errors. Live-browser EN/VI ZIPs and VI Markdown matched the published files.
- 2026-10-29: the installed preview was verified at both agent locations and generated a complete private report from the prior approved history without new file operations or changes to the original audit/baseline. Machine-specific timing, identifiers, reports and installer backups remain private. The local QA server and its test tabs were closed; the live site is the user-facing output.
