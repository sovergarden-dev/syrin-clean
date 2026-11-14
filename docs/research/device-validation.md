# Device candidate validation

Status: amended 2026-11-14.

## Start time

2026-11-14, Asia/Bangkok. Unreleased `4.1.0-preview.1` on `codex/device-support`, based on `da9424d`.

## Initial purpose

Verify Windows protection/stop/recovery behavior and Android diagnostic/report contracts without modifying user files, apps, Windows Update, priorities or phone settings.

## Strategy

Use isolated Windows fixtures and synthetic ADB responses for control paths, real bounded subprocesses for timeout/output limits, generated-package checks and browser interaction with public/synthetic data. Keep hardware qualification separate.

## Checklist

- Windows policy, cooperative stop and stored metadata checks exercised with owned files.
- Android selection, reused transport, disconnection/user change, missing data, input validation and output bounds exercised with synthetic responses.
- Report platform separation, aggregate privacy, capture age and constrained CPU comparison exercised.
- Final regeneration, affected test groups, browser interaction and host sampling completed; evidence details below.

## Result and verification

An intermediate run passed 21 quarantine cases, 15 runtime groups and the scale exercises. Its final package-parity check correctly failed because source fixes were made while that run was still active. That run is not final candidate evidence; freeze, regenerate and run the complete suite again.

No real Android device, System Restore VM, full accessibility session or release attestation has been verified by this development pass. No supplied Android mutator was run and no real cleanup was performed. External source claims and design decisions are recorded in [Android integration](android-integration.md).

### Verified local results

- A frozen full-suite run exited 0: 83 generated outputs, Node page/report/renderer checks, 21 quarantine cases, 15 runtime groups, scale fixtures with 2,048 files / 12 sessions / 4,098 dense events, and 18 Python tests at that stage.
- The final USB devpath and failed-reselection regressions were observed failing before their fixes. All 20 Python tests then passed, including 10 Android cases and 10 package/installation cases.
- After refining policy updates to preserve exclusions when only the mode changes, both Windows suites, all 10 package tests, Node page/report checks and `git diff --check` passed again. Android collector and scale code were unchanged by that refinement.
- A real 30-second PowerShell 5.1.19041.6456 host probe produced 13 CPU/memory intervals on four logical processors. This verifies collection only, not improved performance. Process names and raw measurements stay private; apps and priorities were not changed. Direct imports under the default PowerShell 7 host were correctly rejected; the successful probe used explicit `powershell.exe -NoProfile -File`.
- Actual browser interaction verified English default, Android EN/VI routing, disabled Windows-only fields, retained Windows role when switching back, missing Android temperature, partial frame counters and a share request with `upload=false`. The Android report had no overflowing controls/headings at a 320 px viewport and no console errors. This is synthetic report evidence, not a phone measurement.
- The English ZIP downloaded through the final HTML matched the current built artifact: SHA256 `c64398b702124b6428aedfeabb2b2d423e67e776520a8a0da5efa968f1acf48f`.
- The four versioned preview-2 ZIP/Markdown files were restored to their original `da9424d` bytes after detecting an early pre-bump build had regenerated them. No remote release asset was changed. Remote main remained `da9424d`; the latest release remained the non-draft preview 2 prerelease.

Private logs, screenshots and the host probe are under the local SyrinClean development evidence directory, outside the checkout. QA tabs were closed and the loopback preview server stopped. No global skill installation, push, tag, public release or device mutation was performed.

## Decision

Action: complete the [candidate plan](../plan/device-support.md) only for implemented and verified local behavior. Hardware/beta/publication gates remain open under the [qualification protocol](../ref/beta.md).

## Amendments

- 2026-11-14: After the user connected a phone and approved its USB debugging prompt, one read-only Android 14 audit completed the system, memory, storage, battery, CPU and package collectors. The earlier absence of live phone evidence above is historical. [Live validation](android-live-validation.md) records first-use failures, regression fixes, report checks and the remaining qualification limits; raw device data stays outside this repository.

- 2026-11-14: The next Android qualification pass found no ADB executable on PATH, in common SDK locations, in the bounded Desktop/Downloads/C:\dev file search, or as a running ADB process. The connected-device query showed no named Android/ADB/MTP phone. This is an environment observation, not proof that no phone can be attached or that no SDK exists elsewhere. The user was asked where the test phone is connected; no phone command or dependency installation was performed.
- 2026-11-14: Review found that requiring the new release staging helper during manual redeployment would break older tags that lack that helper. Provenance staging, artifact transfer and signing are now gated to release events; manual redeploy retains the existing HTML digest checks. An isolated execution of the actual workflow verifier passed with no provenance directory in manual mode, rejected a changed HTML, required the eight subjects in release mode and rejected a changed release asset. GitHub Actions execution remains unverified until an authorized push/release.
