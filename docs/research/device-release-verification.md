# Device preview publication verification

Verified 2026-11-14 (Asia/Bangkok).

The [4.1.0-preview.1 pre-release](https://github.com/sovergarden-dev/syrin-clean/releases/tag/4.1.0-preview.1) was published at `2026-11-14T10:32:02Z`. [PR #6](https://github.com/sovergarden-dev/syrin-clean/pull/6) merged the Android diagnostics and Windows execution controls while preserving the demo/Q&A changes from PR #5. The annotated tag resolves to `217669768a33250fd135f2ec9e2816fef0ffefde`; its tree equals the locally tested candidate `2b389305b6eb542605157bc38af5b1b3c2f4dd9b`.

## Build and delivery evidence

| Validation | Successful run |
| --- | --- |
| Candidate push, Windows and Linux portable artifacts | [43583066305](https://github.com/sovergarden-dev/syrin-clean/actions/runs/43583066305) |
| Pull request, Windows and Linux portable artifacts | [43583546565](https://github.com/sovergarden-dev/syrin-clean/actions/runs/43583546565) |
| Merged main | [43584850164](https://github.com/sovergarden-dev/syrin-clean/actions/runs/43584850164) |
| Published tag | [43585031820](https://github.com/sovergarden-dev/syrin-clean/actions/runs/43585031820) |
| Release validation, attestations and Pages deployment | [43585731937](https://github.com/sovergarden-dev/syrin-clean/actions/runs/43585731937) |

The release workflow validated and staged on Windows, then checked published digests, attested the eight files and deployed on Linux. Its reusable portable-artifacts job is intentionally skipped; the same tag already passed that job in the tag-push run.

The final local Windows PowerShell 5.1 suite passed 83 generated-output comparisons, Node model/lifecycle checks, 21 quarantine cases, 16 runtime groups and 25 Python cases. A packaged-document regression first failed on relative links into missing ZIP paths; the build now resolves them against the matching release tag, and the regression passed. Both referenced documents were confirmed present at the published tag.

The final local scale fixture used 2,048 files, 12 sessions and a dense 4,098-event session. Planning took 111,344 ms, history 25,474 ms and report generation 22,224 ms. Planning remained within the unchanged 120-second guard. An earlier active-host run took 35,741 ms; this variability prevents a controlled performance or device speed-up claim. A quieter repeatable benchmark remains useful before strengthening performance claims.

## Published bytes and provenance

Eight explicit assets were uploaded to a draft and their GitHub SHA-256 digests compared with the frozen local release. After publication, all eight were downloaded again and their actual bytes matched. Earlier release assets and tags were not replaced. Only the exact new tag was added to the Pages environment's deployment policy; existing restrictions remain.

The live [web app](https://sovergarden-dev.github.io/syrin-clean/) and [example report](https://sovergarden-dev.github.io/syrin-clean/report-demo.html) match their release HTML assets byte-for-byte. `version.json` identifies `4.1.0-preview.1`, the tagged merge revision and both matching hashes.

All eight downloaded files passed `gh attestation verify`, including verification of the repository, signing workflow, source commit and tag. For each downloaded asset, the verification command was:

```powershell
gh attestation verify <downloaded-file> --repo sovergarden-dev/syrin-clean --signer-workflow sovergarden-dev/syrin-clean/.github/workflows/pages.yml --source-digest 217669768a33250fd135f2ec9e2816fef0ffefde --source-ref refs/tags/4.1.0-preview.1 --format json
```

This establishes published build provenance; it does not establish broad device compatibility or recovery reliability. Manual redeploys of older releases do not retroactively create attestations.

## Live browser path

The public page opened in English with the new version. Selecting Android disabled the Windows-only profile controls. A synthetic app package and task description remained intact through EN → VI → EN, and the generated opening message retained the diagnostic-only restrictions and both values.

The Vietnamese ZIP downloaded through the actual button had SHA-256 `1b015a7d0ee2a4c1efe87e817e1911582b29beaf41f249b46256da82b8e23426`, matching the published package. The sample-report link opened a new tab. Filtering its synthetic history to permanently deleted files, then switching to Vietnamese, retained the filter and showed six disabled selections with a disabled restore-request button. Both tabs reported no console warnings or errors during these checks. No real phone data was entered or uploaded.

## Boundaries and next qualification

Publication does not update globally installed skills. No phone cache was cleared, app removed or stopped, setting changed, or optimization claimed; the owner's choice to retain cache remains in effect. Raw device evidence, identifiers, reports and release-operation logs remain private.

The [active qualification plan](../plan/device-support.md) remains open for additional OEMs, real app/frame observations and controlled disconnects; disposable-VM System Restore and the Windows filesystem/provider matrix; new-user beta and real assistive-technology checks. A repeatable planning benchmark should characterize the observed timing variation. Device mutation adapters require their own design and disposable-device testing. These limits keep this release a pre-release.

This record is a post-publication documentation update on main. It does not change the deployed tag or replace published assets.
