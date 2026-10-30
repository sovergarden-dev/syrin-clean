# Validation

Path normalization tests exercise missing destination tails without creating directories and reject network, device and alternate-stream forms through the public path API. The native ancestor walk is also exercised by the existing real-junction, access, lock and mutation-identity cases.

Use Python 3.10+ and Node.js 22+ for packaging; Windows PowerShell 5.1 is required for native runtime tests. There are no npm or Python package dependencies.

```powershell
python -B -X utf8 tools/build.py
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/run.ps1
```

The suite checks generated parity, hashes and embedded archives, both language prompt downloads, profile data, history filtering, report data semantics, isolated file lifecycles, failure recovery, native quoting, mocked Restore Point behavior, installation/rollback, safe runtime extraction and the public Pages allowlist. Temporary profiles and file fixtures are created by the tests and cleaned afterward. System calls with machine-wide effects are mocked; no cleanup is run on personal data.

`tests/scale.ps1` constructs an owned 2,048-file nested tree and 12 sessions, including a synthetic 4,098-event journal with alternating UTF-8/UTF-16 BOMs and Unicode text. It verifies complete replay/report contents, intermediate batch progress, hash-chain damage beyond a batch boundary, malformed individual documents, callback/I/O failures and live ancestor rejection after a junction swap. It prints planning/history/report durations as observations, not universal performance guarantees. The runtime tests also exercise caller module composition, approval snapshots, report progress before/after atomic commit, failed/disabled output, quiet CLI invocation and aggregate sharing without history access.

`python tools/build.py --check` validates without writing files. Build rejects unexpected package-source files and credential-like content. A separate final source review is still required; a pattern scan is not proof that arbitrary secrets cannot exist.

The Validate workflow mirrors the local suite on a Windows runner with read-only repository permissions and pinned action revisions. It does not run privileged system qualification. The separate Pages workflow starts on a published release, validates its exact tag through the reusable Windows workflow and verifies tag/version identity before staging on Windows. The deployment job checks the transferred HTML against the published release digests before publishing. Direct push/PR validation also checks portable artifact generation on Ubuntu. Its deployment job has only the additional Pages and OIDC permissions needed to publish the staged public files. Release assets are uploaded explicitly after verification.

For browser QA, serve only the generated public HTML files and synthetic reports on loopback. Verify actual viewport dimensions when inspecting each tab, then exercise both languages, profile persistence, reset, keyboard tabs and actual downloads. Check bounds at 320, 390, 768, 1280, 1920 and 2560 px; global overflow clipping is not evidence that controls fit. Check reports with complete, partial, empty and legacy data; compare raw and aggregate exports; verify pause/offscreen behavior and selection across language, filters and pages. The legacy `?check` hook is replaced by explicit browser checks. Browser fixtures must remain labeled as examples.

Hallmark's static checker was used as a reference check; its Puppeteer render driver is not used by this host. Rendered checks use the supported CUA browser API. Source inspection establishes the reduced-motion and hidden-tab cancellation paths; actual system preference changes, native downloaded-file opening and full screen-reader conformance remain separate qualifications.

VM, hardware, real provider and screen-reader qualification are separate gates listed in [support](../feat/support.md). Their status must not be inferred from a passing fixture suite.
