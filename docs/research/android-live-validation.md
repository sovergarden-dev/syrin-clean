# Android hardware validation

Status: amended 2026-11-14; see the follow-up below for resolution of the planning timeout.

## Start time

2026-11-14, Asia/Bangkok. Local `4.1.0-preview.1` candidate on `codex/device-support`, based on `da9424d`. The user requested inspection before cleanup and explicitly approved USB debugging on the connected phone.

## Initial purpose

Exercise the packaged diagnostic entry point against an authorized physical phone, preserve an untreated baseline, and turn observed first-use failures into tested fixes. No cleanup, app changes, reboot, updates or device settings changes are part of this run.

## Strategy

Use a Google Platform Tools portable copy and the manifest-verified Vietnamese candidate package. Pin the one observed phone, preserve each audit in a new private folder, inspect only requested diagnostic metadata and generate private/advisory plus aggregate HTML. Published evidence omits device model, serial, fingerprint, package names and personal measurements.

## Checklist

- Windows observed one ADB interface. No existing ADB executable/server was found in the checked locations.
- Obtained stable Windows SDK Platform Tools 37.0.1 from Google's repository metadata. Archive size and the repository checksum matched; the locally recorded SHA256 is `45f4d63113e895ebde0c90f194099a4676b6ac653bd28d54314a9e022bbc1a99`. Source: [official Platform Tools documentation](https://developer.android.com/tools/releases/platform-tools), checked 2026-11-14. No driver, PATH or global skill installation was changed.
- Discovery returned unauthorized until the user approved the RSA prompt. The subsequent selection required the same single serial and authorized state.
- Ran the packaged PowerShell entry point with optional package inventory. Preserved the first audit with an unavailable storage collector, then collected a new audit after correcting the observed parser format.
- Generated bilingual private HTML with three advisory rows and a separate aggregate HTML. Verified embedded JSON against the original audit and rechecked original file digests.

## Result and verification

| Finding | Fix and evidence |
|---|---|
| Windows PATH resolved a regular Python install and a WindowsApps entry; PowerShell joined both paths | Select one application before invocation. The public entry-point regression failed before the fix and passed afterward |
| An explicit ADB `-H 127.0.0.1` prevented a missing local server from starting | Use ADB's default local host and fixed port, while clearing inherited routing variables. Synthetic process tests prove environment sanitization; actual cold discovery then reached the unauthorized/authorized states |
| `df -k /data` reported `/data/user/0`, so the parser correctly kept storage unavailable | Accept the observed data bind-mount form and retain `queriedPath` plus actual mount. A synthetic regression failed first. Report validation accepts it only with `/data` query provenance, and aggregate output removes the user-specific mount |
| Repeated Android CPU reads returned identical values | Keep these as historical-window observations, not an independent load benchmark or speed-up measurement |

One real Android 14 / API 34 phone on the observed Windows 10 host, Python 3.12.10, Windows PowerShell 5.1 and ADB 37.0.1 completed all six requested collectors: system, memory, storage, battery, CPU and packages. Both audit identity checks passed. The HTML payload matched the measured audit; original snapshots remained byte-identical after report generation. Shared HTML contained only memory/storage/battery collectors and omitted device identity, app inventory, proposals and history. No device mutation was requested or executed.

The Android regression suite passed 11 cases after these fixes. The Windows runtime suite passed the public Python-selection regression and the bind-mount report/share checks. Final generated-package and suite results are recorded in the closing amendment; interim test results are not a release qualification.

Raw evidence is private in the local SyrinClean development directory. It includes tool provenance, initial errors, two immutable audit snapshots, bounded follow-up observations, report verification and test logs. No raw report or package inventory is copied into public examples.

Not verified: independent comparison with the phone's Settings screen, physical battery wear, storage hardware health, thermal throttling under load, app frame/cold-start performance, live disconnect recovery, other OEMs/Android versions, uninstall/restore, iOS, VM System Restore or live release attestations. A successful collection does not establish that the phone is universally healthy or that cleanup will improve speed.

## Decision

Action: retain diagnostic-only Android support, incorporate the first-use fixes, update the [support matrix](../feat/support.md), and keep hardware expansion and mutation qualification separate in the [plan](../plan/device-support.md). User recommendations belong in the private report and conversation; this public record documents software behavior only.

## Closing qualification amendment

The final frozen run passed generated-output parity for 83 files, the Node report/page checks, 21 quarantine cases and all 16 runtime groups. It then stopped in the Windows scale fixture: scanning 2,048 synthetic files exceeded the existing 120-second planning budget before producing an executable plan. A separate unchanged scale run also timed out. No budget, integrity guard or acceptance criterion was relaxed. The earlier scale pass in the development record is historical evidence, not a pass for this final run; the cause of the current timeout has not been established.

Android collection and report integrity are verified on the one observed phone. Overall candidate qualification remains incomplete until the Windows scale timeout is investigated and the affected check passes. No release, push or installation of the candidate into the global skill directory was performed. The task-owned local ADB server was stopped after collection; phone settings were left unchanged.

After the scale failure, the Python suites were run separately: all 22 cases passed (11 Android and 11 packaging, including the Windows installation and manual redeploy regressions). Generated-output parity and diff whitespace checks also passed. These results do not convert the failed full-suite invocation into a pass.

## Follow-up: planning and readiness

The subsequent profiling run used the same 2,048-file synthetic tree in fresh Windows PowerShell 5.1 processes. Before the change, the scan took 116,386 ms wall time and 52,219 ms process CPU time. After moving string-only source-policy checks into the native helper and obtaining fingerprint metadata from the same handle as identity, it took 36,300 ms and 26,313 ms respectively. Live ancestor checks still occur per path; no scan limit, protected path, cloud exclusion or mutation guard was removed. These sequential observations were on an active workstation and are not a controlled machine-speed benchmark.

The first frozen full suite after this change passed: 83 generated files, Node checks, 21 quarantine cases, 16 runtime groups, 24 Python cases and the scale fixture. The scale fixture planned 2,048 files in 76,033 ms and verified 12 sessions with 4,098 events in the dense session. Its 120-second planning guard was unchanged. The earlier failed runs remain recorded above.

The packaged Android readiness check also passed on the same explicitly selected phone. It separates successful check execution from device readiness and preserves exact selection. The HTML now accepts a named app and task description. Frame records retain capture times and a single observed process/counter origin; unknown or multiple origins remain partial. Review added a regression for an output header naming another app: the original parser failed this case and was corrected to reject it.

Browser verification used synthetic data only. English default report display, EN/VI switching, preserved Android task fields through Windows/Android changes, invalid-package feedback, keyboard focus and 320 px layouts were observed. Both pages had no horizontal overflow or browser error logs. The Vietnamese ZIP downloaded through the page matched the final built package byte-for-byte. Native file opening, real zoom/system reduced motion, a screen reader, first-time external user testing, additional phones and physical disconnect recovery remain unverified.

No phone mutation was performed. The owner explicitly chose to retain the reviewed cache and did not identify a priority app/task. No automatic Android cleanup adapter was added, and no release, remote upload or global installation was performed.

After the app-header regression fix, a new frozen full suite passed all checks, including 24 Python cases. The final scale run planned 2,048 files in 35,741 ms, read 12 sessions with 4,098 dense-session events in 24,111 ms and produced the complete report in 26,574 ms. Both generated language manifests verified 29 files each. The current Vietnamese UI download SHA256 is `59cf6e21725825295f437d41c140bfba39b7f791ad8b1ee54e6e74c1f7deb2e2`; it matched the built ZIP. A targeted private-marker scan covered repository text and decompressed current packages without finding device identifiers. These checks certify the local candidate state only; remote publication and remaining hardware/accessibility gates are not implied.
