# Preview 2 publication verification

Start time: 2026-10-30 (Asia/Bangkok).

Initial purpose: deliver the validated history/progress and HTML interaction changes as the next public pre-release, preserving previous release bytes and the open qualification boundaries.

## Strategy and checklist

- [x] Review and merge [PR #4](https://github.com/sovergarden-dev/syrin-clean/pull/4) only after Windows and Ubuntu validation passed.
- [x] Verify the merged tree equals the locally tested release tree and tag exactly `3e3dcf18bb210f1669e21ba613e16715eae94a1a` as `4.0.0-preview.2`.
- [x] Upload eight explicitly selected assets to a draft, download them again and compare bytes and GitHub SHA-256 digests before publishing.
- [x] Allow only the specific new deployment tag while retaining existing environment restrictions.
- [x] Verify anonymous access, live Pages hashes, browser behavior and the installed runtime.

## Result

The [pre-release](https://github.com/sovergarden-dev/syrin-clean/releases/tag/4.0.0-preview.2) was published at `2026-10-30T02:54:49Z`. Both public HTML pages match the corresponding release assets byte-for-byte; `version.json` identifies `4.0.0-preview.2` and the tagged merge commit. All eight new assets match the expected names, sizes and digests. The previous release's asset IDs, names, sizes and digests remain unchanged.

| Validation | Verified run |
| --- | --- |
| Branch Windows and portable artifacts | [40993258767](https://github.com/sovergarden-dev/syrin-clean/actions/runs/40993258767) |
| Pull request Windows and portable artifacts | [40993264513](https://github.com/sovergarden-dev/syrin-clean/actions/runs/40993264513) |
| Merged main | [40993675613](https://github.com/sovergarden-dev/syrin-clean/actions/runs/40993675613) |
| Published tag | [40994032228](https://github.com/sovergarden-dev/syrin-clean/actions/runs/40994032228) |
| Pages validation and deployment | [40994400227](https://github.com/sovergarden-dev/syrin-clean/actions/runs/40994400227) |

All listed runs succeeded. The local release suite also passed generated parity, Node model/lifecycle checks, 18 quarantine cases, 12 runtime groups, a dense 4,098-event fixture and 9 packaging/installation tests.

The live page opened in English with the new version visible. Its embedded English ZIP downloaded through the actual UI and matched the release checksum. Switching to Vietnamese updated the sample link, which opened the Vietnamese sample in a new tab. Filtering that sample to permanently deleted records showed six disabled selections and a disabled restore-request action. Browser warning/error inspection was empty on the landing page. The delivered tab was returned to English with decorative motion paused.

Both existing Vietnamese skill installations were updated through the verified published installer. Each installed manifest has 20 verified files, and the previous installations were retained as backups. A fresh Windows PowerShell 5.1 process used the installed runtime to regenerate a private English-initialized bilingual report in 35,270 ms: 37 sessions, 4,710 purged items, 18,840 verified events and zero history errors. Original audit/proposal hashes were unchanged. This uses an existing audit, not a fresh health scan. Private reports, paths, raw logs and backup identifiers remain outside the repository.

## Decision

Action: close the [preview refresh](../plan/done/preview-refresh.md). Keep the public tag and release assets immutable; later publication records on main do not redefine the deployed revision. The first preview's changelog point-budget text was corrected against its tagged renderer source (160/280 initial points); its published files were not changed.

VM/System Restore, broader Windows/ARM64/cloud/provider coverage, real browser zoom/system preference transitions, weak-device CPU measurements and complete screen-reader qualification remain open. The release is still a pre-release. See [support](../feat/support.md), [journal validation](journal-validation.md) and [HTML interaction validation](html-interaction-validation.md).
