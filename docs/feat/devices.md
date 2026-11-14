# Device diagnostics and execution controls

> updated 2026-11-14 · v4.0.0-preview.2

This document describes the local, unreleased `4.1.0-preview.1` candidate. The published release remains `4.0.0-preview.2`.

## Windows protection policy

`policy.ps1` reads `%LOCALAPPDATA%\SyrinClean\policy.json`. `-Set -Mode audit|approve` retains existing protected paths. Supplying `-ProtectedPath <literal-path-array>` explicitly replaces the exclusions after validating the owner and paths; merge existing entries when adding paths. The audit mode blocks file planning/execution and system adapters; it still permits diagnostics and reports. An explicit request to unlock is required before an agent changes it to approve.

Policies are capability restrictions, never consent. File plans capture policy file digests; execution reloads the default and referenced policies before starting and between atomic items. A changed/deleted bound policy requires a new reviewed plan. A newly added default policy applies to old plans. Additional policy files can restrict further but cannot relax the default. Protected paths, descendants and ancestors are blocked; similarly prefixed siblings remain distinct. Protection also applies to original locations before purge.

These are runtime controls, not an OS sandbox. The same user or a full-shell agent could edit files or bypass the runtime. Built-in identity/owner/cloud/path checks remain mandatory.

## Stop and recovery inspection

Pass a fresh `-RunId` and unique `-StopFile` to each executor run. `request-stop.ps1` writes a create-only request with that run ID. Execution checks between items, finishes the current journal/file boundary, and returns `stopped`, `stopReason` and `unprocessed`. A stale or invalid request stops safely; it never triggers another run. A new invocation needs fresh control values and reviewed remaining item IDs. Cancellation is not an instantaneous interrupt, and hard process termination still needs journal reconciliation.

`quarantine.ps1 -Verify` acquires the quarantine writer lock, replays validated journals and checks stored identity/length/mtime/link count. It reports intact, missing, changed, unexpected or reconciliation-required data plus unlisted entries. It does not read file contents, prove byte-for-byte backup integrity, repair history or delete anything. Normal planning/execution checks remain required after this snapshot. A successful inspection is not a tested restore.

## Windows performance

`audit.ps1 -Scope speed` requests 30 seconds of CPU/memory samples. Other scopes may opt in with `-PerformanceSeconds 2..60`. Sample intervals are two seconds; process identity combines PID and start time, CPU is normalized by logical processors, and inaccessible processes are counted explicitly. Process paths/command lines are not collected. The top ten measured processes per interval remain private in the local report.

Before/after CPU comparisons require the same machine, method, duration, interval, a matching nonempty `-ContextLabel`, complete measurements and increasing capture times. A shared workload label is an operator assertion, not proof that conditions matched. The display uses percentage-point CPU changes, never a causal speed-up score. Windows processor-group and broader hardware qualification remain separate.

## Android over USB

The Windows host needs Python 3.10+ and official Google SDK Platform Tools; neither is silently installed. `android-audit.ps1 -Devices -AdbPath <absolute-path>` lists local ADB devices. Discovery may start the normal local ADB server. It never kills/restarts that server or pairs a wireless device.

The PowerShell entry point selects the first Python application in PATH. ADB uses its default local host and explicit port 5037; inherited device/server-routing environment variables are cleared. Passing an explicit `-H` would prevent a cold local server from starting and is not used.

`-Check` verifies Python 3.10+, resolves an explicit ADB path or existing PATH installation, and returns a structured readiness result. `ok` describes successful execution of the check; `ready` requires an explicitly selected, authorized USB phone that has completed booting. Device absence, offline state, missing RSA approval and duplicate serials are separate outcomes. Checking readiness collects no audit and creates no report.

A diagnostic run requires an exact serial and verified USB transport. Commands pin the transport and check serial/state before each read; fingerprint and current Android user must remain consistent through the snapshot. No device fallback is allowed. USB authorization happens on the phone. Non-USB transports are rejected, including environments where USB cannot be proved.

Some Windows ADB backends return `unknown` for `get-devpath`. In that case the adapter requires `adb -d get-serialno` to identify exactly one USB phone with the selected serial, and repeats that proof before each read. Multiple USB devices in this mode are rejected rather than choosing one implicitly.

Collectors read selected build properties, current user, `/proc/meminfo`, `/proc/uptime`, `/data` filesystem totals, battery and CPU summary. Package inventory is opt-in and scoped to the current user; optional `gfxinfo` targets an exact package. At least 120 frames is only a minimum interpretation threshold, not statistical proof of smoothness. OEM denial or unknown formats remain unavailable/partial. No settings dump, accounts, messages, photos, logcat, personal file tree or full property dump is saved.

Storage retains both the queried `/data` path and an observed `/data/user/<id>` bind mount where Android reports one. Shared exports normalize that mount back to `/data` to omit the user number. CPU is the Android-reported historical window; repeated reads can contain overlapping or unchanged statistics and must not be called an independent time-series benchmark.

Optional app diagnostics accept `-Package` plus a one-line `-ContextLabel` of up to 240 characters. Frame rows retain capture timestamps, process ID and the Android counter origin. A missing or ambiguous process/origin remains partial even with enough frames. The bilingual report presents these as cumulative observations; it does not compute a task benchmark or speed-up. The task description is an operator assertion and is omitted from aggregate exports.

Every subprocess has a 15-second ceiling and a 2 MiB cap per output stream within an overall 30–300-second budget. Local output is written only after device identity is rechecked. Reports are self-contained bilingual HTML, English by default; Android reports do not contain Windows actions/history. Existing session directories are never overwritten.

Android mutations, package disable/uninstall, cache clearing, reboot, root, bootloader changes, APK installation and file transfer are not implemented. iOS/iPadOS support is not implemented. Catalog grades remain reference material; no UAD database or per-device seed list is distributed. See [the integration decision](../research/android-integration.md).

## Evidence and sharing

Every report states capture time and snapshot age. Regenerating HTML does not refresh measurements. Android aggregate exports allow only storage, memory and battery fields; Windows uses its existing aggregate allowlist. Identity, app inventory, processes, paths, arbitrary extra fields and history are excluded. Review the export before sharing; reduced data is not a guarantee of anonymity.

The first read-only Android 14 audit is recorded in [live validation](../research/android-live-validation.md). It does not qualify every OEM, physical battery health, app smoothness or recovery. Subsequent mutation work needs a disposable device, verified backup, immutable review plans, per-item durable records, exact prior state and postcondition-based recovery checks before any mutation adapter becomes available.
