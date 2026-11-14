# Android integration decision

Status: amended 2026-11-14.

## Start time

2026-11-14, Asia/Bangkok. Base source: `da9424d`, released preview 2. User-approved work includes Windows execution controls and Android integration using a supplied experience archive.

## Initial purpose

Make maintenance decisions safer and more useful across Windows and Android. The goal chain is: reliable device evidence → narrowly reviewed action → a usable device with intact data. Maximizing deleted packages, free RAM or animations is not the goal.

## Strategy

Read every Markdown reference and both Python scripts in the supplied `android-usb-optimizer.zip`, then trace Syrin clean's plan/journal/report/package boundaries and compare disputed claims with primary sources. The archive SHA256 is `06d5a4c5bb45eaf1453421228c1aff9db5abd7ce441001a22a48d306a585df13`. Its case history and device identifiers stay outside this repository. No archive script was executed or installed.

## Checklist

- Reviewed selection, command execution, return codes, plan approval, rollback persistence and reporting in the reference scripts.
- Checked official ADB, dumpsys, ZRAM and ART documentation on 2026-11-14.
- Separated useful workflow lessons from unsupported guarantees and device-specific examples.
- Chose a bounded implementation and explicit follow-up qualification instead of importing an execution recipe.

## Result

| Reference finding | Integration decision |
|---|---|
| Snapshot and rollback-first workflow; preserve user-needed apps and original disabled state | Retain these requirements for future adapters; this preview exposes read-only diagnostics only |
| Device discovery reports the first authorized row while command selection is optional; generated rollback omits selected serial/user | Require exact serial, USB transport ID and current user; recheck serial on each read, including reused transport IDs |
| Return codes can be lost; restore accepts an empty response or text containing “installed” | Keep structured return status; no mutation or restore API is exposed until postconditions can be verified |
| Apply can change animation settings along with package changes; state is written after the batch | Do not import this execution path. Future adapters need separate immutable plans and a durable per-item journal |
| `pm uninstall -k` described as inevitably deleting user-app data | Official ADB documentation says `-k` retains data/cache directories. This still does not guarantee APK availability, complete recovery or safe removal ([ADB](https://developer.android.com/tools/adb)) |
| ZRAM use described as proof of paging to flash and strong proof of lag | ZRAM stores compressed pages in memory; optional writeback needs separate evidence. Swap quantity alone is not causal proof ([Linux ZRAM](https://docs.kernel.org/admin-guide/blockdev/zram.html)) |
| Presence in `pm list packages -u` called rollback verification | A listing is evidence of a package-manager record, not a successful reinstall or restored functionality |
| UAD “Recommended” treated as system-safe | Treat catalog grades as review material. Device/OEM versions, user roles, dependencies and actual recovery must be verified. Do not bundle the external catalog or private seed lists ([UAD project](https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation)) |
| Reboot RAM/jank improvement used as before/after evidence | Record uptime; mark sparse frame data partial; no percentage speed-up without a comparable workload. `gfxinfo` is scoped to the requested package and its counter window ([dumpsys](https://developer.android.com/tools/dumpsys)) |
| Generic compilation/“boost” suggestions | No forced dexopt. Android 14+ ART service has its own idle/charging schedule and thermal controls; these do not establish the behavior of an older OEM build ([ART service](https://source.android.com/docs/core/runtime/configure/art-service)) |

Verification: source inspection establishes the reference-code gaps. Primary documentation establishes the command semantics above. Synthetic tests establish parser/transport/control contracts, not real OEM compatibility, restoration or performance improvement. New runtime evidence is recorded separately in the implementation validation document.

## Decision

**Action:** [implementation plan](../plan/device-support.md), [device support contract](../feat/devices.md). Keep the current Windows runtime and add a small Python standard-library ADB boundary; no daemon, backend, Android app or telemetry is needed. Python is an additional dependency only for Android.

Alternatives considered: importing the archive's mutator would deliver actions sooner, but preserves device-selection and recovery gaps; building a cross-platform desktop wrapper now would improve packaging but not prove maintenance correctness. A diagnostic-first adapter delivers useful evidence with a directly testable boundary.

The chosen approach could fail if OEM outputs are too variable or users interpret inventory as a removal recommendation. Unknown output therefore stays unavailable, packages are opt-in and review-only, and the UI states the Android boundary. Reopen after real-device parser coverage and a disposable-device rollback exercise justify a narrowly scoped adapter. No blanket debloat, RAM booster, system-app seed list, automatic reboot or iOS automation is scheduled.

Cross-references: [support](../feat/support.md), [commands](../ref/commands.md), [architecture](../arch/project.md). VM qualification and real assistive-technology testing retain their existing unverified status.

## Amendments

- 2026-11-14: AOSP's [Windows USB backend](https://android.googlesource.com/platform/packages/modules/adb/+/refs/heads/android15-qpr2-s8-release/client/usb_windows.cpp) registers USB devices without a devpath. A regression reproduced rejection of a valid `unknown` devpath. The adapter now uses a matching unique USB selector proof in that case and rechecks it before each read. This changes the transport implementation, not the diagnostic-only decision. Real SDK/phone validation remains open.
