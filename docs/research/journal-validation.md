# Journal replay and progress validation

Start time: 2026-10-30 (Asia/Bangkok).

Initial purpose: reduce large-history latency after the reboot-safe handoff at `7f7e0b5`, preserve existing journal/approval semantics and expose report-generation progress. This is an unreleased implementation on `codex/journal-progress`, not a new public release.

## Strategy and checklist

- [x] Keep the existing per-document PowerShell parser and immutable approval-plan reader; batch native path/read/decode/hash work only.
- [x] Compare identical real journals in fresh Windows PowerShell 5.1 processes, with all user applications retained and no cleanup or system-setting changes.
- [x] Exercise dense synthetic journals, failure paths, live ancestor checks and report progress through public runtime functions.
- [x] Build both language packages, run the complete local suite and generate a private real report with the packaged runtime.

## Result

### Replay timing and equivalence

The read-only workload contains 37 sessions, 4,710 items and 18,840 event files. Windows PowerShell version: 5.1.19041.6456. Each measurement starts a fresh process, times `Get-SyrinHistory`, sorts sessions and compares SHA-256 of the complete serialized history. All six runs produced the same digest and zero failed sessions.

| Sequential comparison | Baseline | Candidate |
| --- | ---: | ---: |
| Second pass | 53,504 ms | 35,012 ms |
| Third pass | 62,433 ms | 33,447 ms |

Mean elapsed time across these two comparisons decreased by 40.95%. The first baseline took 465,905 ms and overlapped fixture work; its paired candidate took 35,375 ms. That first pair is excluded from the improvement calculation. Filesystem caches and the user's application load were not controlled, so these observations are not universal performance guarantees. No persisted index, cached filesystem attributes, new JSON parser or journal migration was introduced.

### Regression evidence

`python -B -X utf8 tools/build.py` reported 65 validated outputs. `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/run.ps1` exited 0: generated parity, both Node model checks, 18 quarantine cases, 12 runtime groups, the scale fixture and 9 Python packaging/installation tests passed. No cases were skipped. No owned test directories remained afterward.

The scale fixture retains all 2,048 planned items across 12 sessions, including a 4,098-event synthetic session with mixed UTF-8/UTF-16 BOMs. It verifies intermediate progress, final states and Unicode, corruption after a batch boundary, malformed individual documents, observer/I/O failure propagation and rejection of an ancestor changed to a real junction between batches. Observed durations in the full run: planning 33,782 ms, history 7,750 ms, complete report 10,920 ms.

The report tests inspect the progress record at the HTML write boundary, preserve prior HTML after a locked-output failure, reject stale success after invalid input, keep `-Quiet` progress durable and skip history access for shared reports. A completion-record failure remains explicit even when HTML has already committed. The new progress regression failed against the baseline because `report-progress.json` did not exist, then passed against the candidate.

### Private real report

The generated English package rebuilt a bilingual 3D report from an existing audit in 42,556 ms. The report contains all 37 sessions and 4,710 purged items; progress records 18,840 verified events, zero failed sessions and completion after the HTML commit. Original audit/proposal hashes remained unchanged. This regenerates an earlier audit; it is not a fresh machine-health scan. Raw journals, reports, paths, IDs and benchmark logs stay outside the public repository.

## Local commit gate

| Step | Result and evidence |
| --- | --- |
| S0 | PASS: the starting tree was clean; all changed sources, tests, docs and generated files belong to this work. |
| S1 | PASS: `project.json` remains `4.0.0-preview.1`; its existing tag is present and changes are recorded under `Unreleased`. |
| S2 | PASS: scoped source review, `git diff --check` and scythe on changed canonical text. Six warnings in generated prompt profile labels are unchanged from `HEAD` and describe intentional separate fields, so they are excluded from this change. No new parser or mutable path cache. |
| S3 | PASS: the schema detector finds only the new progress snapshot and moved existing validation lines. No existing persisted shape is migrated; real journal replay and source audit hashes are preserved. |
| S4 | PASS: changelog entries match implemented behavior; `release_lint.py --latest .` exits 0. |
| S5 | PASS: architecture, commands, validation, EN/VI instructions, handoff and the completed plan describe the current implementation. |
| S6 | PASS: the full Windows suite exits 0 and generated artifacts match source. Hosted CI and the Ubuntu job are not run for this local-only change. |
| S7 | PASS for this scope: the packaged runtime reads the real journal and writes the complete private HTML. VM, System Restore and other platform/provider qualifications remain unverified. |
| S8 | N/A: no new version, tag, push, deployment or release is part of this local checkpoint. |

The easiest checks to miss were a junction introduced after the first batch and progress publication failing during replay; both run in the scale fixture. A future failure on another platform remains outside this machine's qualification. The only new persisted artifact is an advisory progress snapshot, never an execution authority. Real-data verification exercised journal replay and report generation, not a deployed version string or an OS mutation.

## Decision

Action: keep the measured batch reader and report progress in the [completed implementation plan](../plan/done/journal-progress.md). Preserve the old journal format and the general approval reader. A parser replacement or persistent index is unnecessary at this workload; reconsider only if comparable measurements show replay is still a material bottleneck.

Corroborating sources: [runtime contracts](../arch/execution.md), [commands](../ref/commands.md), [validation commands](../ref/validation.md), [runtime regressions](../../tests/runtime.ps1) and [scale regressions](../../tests/scale.ps1). The published preview and its immutable assets are not replaced by this local work.
