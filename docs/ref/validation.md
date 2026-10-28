# Validation

Use Python 3.10+ and Node.js 22+ for packaging; Windows PowerShell 5.1 is required for native runtime tests. There are no npm or Python package dependencies.

```powershell
python -B -X utf8 tools/build.py
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/run.ps1
```

The suite checks generated parity, hashes and embedded archives, report data semantics, isolated file lifecycles, failure recovery, native quoting, mocked Restore Point behavior, installation/rollback and safe runtime extraction. Temporary profiles and file fixtures are created by the tests and cleaned afterward. System calls with machine-wide effects are mocked; no cleanup is run on personal data.

`tests/scale.ps1` constructs an owned 2,048-file nested tree, plans it within the runtime's existing budget, and verifies that a report retains every item across 12 sessions. It prints planning/history/report durations as observations, not universal performance guarantees. The runtime tests also exercise caller module composition, BOM-aware JSON digests, changed plan/journal bytes and report replacement failures.

`python tools/build.py --check` validates without writing files. Build rejects unexpected package-source files and credential-like content. A separate final source review is still required; a pattern scan is not proof that arbitrary secrets cannot exist.

The GitHub workflow mirrors the local suite on a Windows runner with read-only repository permissions and pinned action revisions. It does not publish, deploy, create a release or run privileged system qualification.

For browser QA, serve only the generated public HTML files and synthetic reports on loopback. Use `?check` for landing-page layout, then exercise profile options, reset, keyboard tabs and actual downloads. Check reports with complete, partial, empty and legacy data; compare raw and aggregate exports; verify pause/reduced-motion/offscreen behavior and history requests. Browser fixture data is not a runtime fallback and must never be shipped as a real audit.

VM, hardware, real provider and screen-reader qualification are separate gates listed in [support](../feat/support.md). Their status must not be inferred from a passing fixture suite.
