# Hardening implementation and validation

Status: amended 2026-10-29.

## Start time

2026-10-28, Asia/Bangkok. Baseline `a0752aa`; implementation branch `codex/hardening`. The owner approved the full hardening plan and later explicitly deferred VM qualification because no disposable VM is available.

## Purpose

Implement the 15 audit findings, consolidate runtime delivery and add recoverable file operations, honest reports, installation rollback, history and regression checks. Keep real system qualification separate from fixture tests and do not label an unqualified development build stable.

## Strategy

Use one canonical runtime/policy/report/web source set. Validate file identity and mutation on native handles, keep immutable plans and append-only events, and use fixtures at OS boundaries. Build every distribution from the same sources; inspect real browser output and compare actual downloads.

## Checklist

- [x] F01–F04: selected-file operations, owned storage, durable journal, recovery/conflict handling, cloud ancestry and reparse checks.
- [x] F05–F08: typed categories, incomplete states, system-volume identity and separate StartupApproved identities.
- [x] F09–F14: native argument quoting, schema validation, transactional install, package allowlists, no-HTML mode and accurate OS/lifecycle separation.
- [x] F15: tab semantics, state and keyboard navigation in both pages.
- [x] Shared source generation, manifests/checksums, safe standalone extraction, private-data-reduced exports and history requests.
- [x] Local regression suites and browser checks.
- [ ] Real VM, additional hardware/filesystem/provider/agent and screen-reader qualification.
- [ ] Stable release approval; no new version/tag/release has been minted.

## Results

### Local environment

Windows 10 Pro build 19045, 64-bit; Windows PowerShell 5.1.19041.6456; Python 3.12.10; Node.js 22.22.0. Runtime tests used owned fixture directories/profiles. No real cleanup, Restore Point creation or registry mutation was performed on the host.

### Automated checks

| Check | Observed result |
|---|---|
| Quarantine suite | 15 cases passed: readonly planning, digest binding, conflict/rename, selected purge, root ownership, changed sources, cloud ancestry, journal rollback, writer lock, legacy import, replacement race, real junction, real file lock, access denial, simulated disk/rollback failure and interrupted restore/replay are covered across the cases |
| Runtime suite | Startup identities, failed scans, collector-process errors, CLI no-HTML mode, report/privacy output, invalid-input preservation, baseline mismatch, real native Unicode/empty/quote/backslash argument round-trip and mocked Restore Point/registry rollback passed |
| Report model | Category totals, unknown/partial states, system/volume identity, comparison, conservative legacy handling and escaping passed |
| Package suite | Generated parity, manifest/ZIP/embedded-runtime matching, unexpected-file rejection, both install targets, preserved backups, failed-second-commit rollback, checksum rejection and traversal-safe extraction passed |
| Build | 61 generated outputs validated; deterministic source/output parity checked |
| Source/document checks | Active-source formatting, changelog shape, local documentation links and Git whitespace checked |

The directory-lock failure test initially did not create the intended failure because its metadata-only handle did not deny rename. It was corrected to a real read handle without delete sharing; the installer then failed on the second switch and restored the first target. An inherited PowerShell module-path issue also surfaced in isolated installation and was removed by using .NET SHA256 and isolated system-module paths in tests/collector processes.

### Browser checks

Both landing pages passed their layout self-check at widths 320, 390, 768, 1366, 1920 and 2560 px. The mobile introduction/actions precede the scene. Advanced options are a real disclosure; audit-only, report mode, budget, exclusions, reset and keyboard tab selection were exercised.

The final Vietnamese ZIP downloaded through the page matched `dist/syrin-clean-skill-v3.6-vi.zip` byte-for-byte. Its SHA256 was `cb883ecde12e9a26a7e7d22550a69fc18bb434c243332258f745a1b403aab317` at that check. The downloaded Vietnamese Markdown matched its generated artifact after newline normalization. Package tests independently verify both languages and embedded runtime bytes. Later changes to bundled documentation or source require a new checksum/build check; this hash is evidence of that observed download, not a permanent release identifier.

Synthetic report fixtures visibly selected D: rather than C:, separated app/user/VM/system data from cache, showed unknown reclaimable space and collector limitations, and displayed guarded before/after values. Category filtering, pause state and an exact single-item restore request worked. The sharing view omitted history and raw private fields; the legacy view remained unverified/unclassified rather than showing healthy zeros. Report views at 390 px had no horizontal overflow. No console errors were reported in the sampled browser checks.

Pause was verified through its control state and the drawing-loop implementation. The browser's readonly DOM adapter does not expose canvas pixel extraction; no pixel-stability or CPU-performance claim is made from that failed observation. Low-end hardware, real reduced-motion environment changes and screen-reader behavior remain qualification work.

## Scope and cleanup

Browser viewport overrides were reset, the temporary tab was closed and the owned loopback preview server was stopped. Test fixtures are cleaned by their suites. Preview fixtures and downloaded QA files remain outside tracked source. Automatic approval review rejected a direct cache-cleanup command with `blocked by policy`; ignored Python bytecode caches were retained rather than deleting through another route. They are not distributed or tracked.

## Decision

Implementation is ready for source review as an unreleased development build. The [hardening plan](../plan/hardening.md), [support matrix](../feat/support.md) and [validation guide](../ref/validation.md) define the remaining qualification gates. No passing mock/fixture check is used as evidence that the real Windows service, every device or every agent integration is qualified.

Keep unsupported system-changing suggestions advisory. Reopen stable-release qualification only when the requested disposable VM/hardware/provider environments and independent user-flow checks are available.

## Amendments

- 2026-10-28 · Automated checks: implementation commit `4680f1ecb27eeb63b4448f9629d2e0d1cef5e9df` passed both the [push workflow](https://github.com/sovergarden-dev/syrin-clean/actions/runs/40725783228) and [pull-request workflow](https://github.com/sovergarden-dev/syrin-clean/actions/runs/40725786814) on the hosted `windows-2022` runner with Python 3.12 and Node.js 24. Both ran the complete fixture suite and repository-residue check successfully. This adds a clean-checkout CI result, not real System Restore/UAC or product qualification on Windows Server.
- 2026-10-28 · Decision: the implementation is public for review in [draft PR #1](https://github.com/sovergarden-dev/syrin-clean/pull/1). The stable-release gates remain open; no merge, tag, GitHub Release or website deployment was performed.
- 2026-10-29 · Local follow-up: regenerating an existing report exposed PowerShell 5.1 converting the backup-path `$null` to an empty string for `File.Replace`. A regression failed with the same path error before the fix; `[NullString]::Value` supplies a true null string as documented by [Microsoft](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.language.nullstring). The full local suite passed after the fix, including replacement with updated proposals and preservation of the existing report when its file is locked. This follow-up is local and is not covered by the earlier CI runs.
- 2026-10-29 · Runtime composition and scale: a public `make-report.ps1` regression reproduced loss of the caller's IO command before shared-module force reloads were removed. The complete local `tests/run.ps1` then exited 0 with 16 quarantine cases, 10 runtime groups, report-model assertions, the new scale fixture and seven package tests. The scale fixture planned 2,048 files in 55,860 ms, loaded 12 sessions in 1,643 ms and produced a complete history report in 2,860 ms. These are observed fixture timings under concurrent host load, not a controlled speedup or a performance guarantee. Before scoped reference resolution, the same scale fixture exceeded its existing 120-second planning budget. The final suite also verifies a newly created junction against an existing policy, raw-byte journal corruption and BOM-aware JSON hashing.
- 2026-10-29 · Report UI: separate EN/VI synthetic reports with 37 sessions and 128 items per valid session were served only from an allowlisted loopback fixture server. Browser interactions reached session 37 and its last 28-item page; selections from the first and last page produced exactly two expected IDs. Purged entries and their restore button were disabled; a corrupt session displayed its error. Pause state, English labels and 390/1366 px layouts were checked, with no horizontal document overflow or sampled console warnings/errors. Actual reduced-motion preference changes, canvas pixel stability and CPU benchmarking remain unverified.
- 2026-10-29 · Live-operation boundary: the earlier statement that no host cleanup or registry mutation occurred describes the initial fixture-validation run. Later operator-approved file operations were exercised on one Windows 10 x64 host; a same-account elevated read-only query also succeeded. Private reports, identifiers, registry backups and journals remain outside the repository. These observations do not qualify real Restore Point creation, UAC cancellation or the disposable-VM workflow.
- 2026-10-29 · Hosted follow-up: implementation commit `f990623570f564d7396e0c003934c9e1bd652022` passed the [push workflow](https://github.com/sovergarden-dev/syrin-clean/actions/runs/40781127959) and [pull-request workflow](https://github.com/sovergarden-dev/syrin-clean/actions/runs/40781134491), including the new scale suite and clean-checkout residue check. The [runtime scale plan](../plan/done/runtime-scale.md) is complete. The preview tab was closed, its viewport override reset and the owned loopback server interrupted successfully. Automatic approval review blocked the combined preview-stop/temporary-directory-delete command with `blocked by policy`; the synthetic preview directory was retained instead of deleting it through another route.
- 2026-10-29 · Native path follow-up: a local 200-iteration synthetic JSON probe attributed 962 ms to guarded path resolution versus 39 ms for byte reads and 108 ms for parsing. Moving lexical validation, the live ancestor walk and long-name resolution into the existing native helper reduced the observed guard probe to 482 ms; these separate observations are not a controlled performance benchmark. The complete local suite then exited 0 with 16 quarantine cases, 11 runtime groups, model/scale checks and seven package tests. The 2,048-file fixture planned in 53,122 ms; 12-session history took 1,469 ms and the complete report took 3,020 ms. Missing destination tails remain read-only; network/device/stream rejection, real junctions, corruption checks and mutation identity checks passed. No mutable filesystem checks were cached or removed.
- 2026-10-29 · Installed follow-up: the updated bundle was installed with retained backups and every manifest entry was independently checked at both skill locations. Its public report entry point successfully rendered the previously approved local journal history without changing the source audit or baseline and without executing additional file operations. Raw evidence and machine-specific timings remain private; this is still one-host validation rather than the outstanding VM/platform qualification.
