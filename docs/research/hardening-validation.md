# Hardening implementation and validation

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
