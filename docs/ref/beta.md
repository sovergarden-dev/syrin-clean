# Candidate qualification protocol

Do not recruit users, upload reports or mutate devices automatically. Record source revision, artifact digest, host/phone versions, command, observation and verdict in private evidence. Publish only reviewed aggregate findings.

## Windows target

First qualify Windows x64 + Windows PowerShell 5.1 + a local NTFS volume on a disposable VM. Test non-admin and approved same-account elevation separately. Exercise policy restrictions, stop between files, interrupted move/restore/purge, full volume, locked files and registry rollback. A workstation fixture pass does not qualify real System Restore. Windows 11/ARM64/ReFS, redirected profiles and each cloud provider remain separate rows.

For performance, capture the same normal workload twice before interpreting a change. Record power source, uptime, active applications and whether any reboot occurred. Keep apps open. Repeat after an approved change under the same conditions; retain distribution/window details, not only the mean. An observed CPU reduction is not automatically an application speed-up.

## Android target

1. User selects one phone and authorizes diagnostics. Record OEM/model, Android build, SDK Platform Tools version and host architecture privately.
2. Confirm discovery, exact serial, USB transport, RSA authorization and current Android user. Verify ambiguous/offline/unauthorized cases without changing phone settings through the agent.
3. Run the default read-only audit to a new session; compare storage and battery values with the phone's Settings screen. Record unsupported `/proc`/OEM output as unavailable.
4. With permission, collect package inventory and one named app's frame counters after normal use. Confirm sparse/empty counters remain partial and no removal recommendation appears.
5. Review EN/VI HTML and aggregate export. Verify model/serial/packages/raw errors are absent from the shared artifact. Check all user-visible values against original JSON.
6. Test disconnect/reconnect on a disposable device and confirm the run never switches to another phone. No disable/uninstall/settings/reboot/cache/file action is part of this protocol.

A future mutation adapter needs a separate design, immutable device/user-bound plans, exact prior state, durable per-item records and tested postconditions on a disposable device. Catalog grades or successful shell text are insufficient recovery proof.

## First-use and accessibility

Ask a new user to download the correct language, identify Windows versus Android scope, find missing measurements, distinguish snapshot age from current health, prepare a request and explain whether anything executed. Record where they stall; do not infer usability from the author knowing the UI.

Exercise keyboard-only navigation, real browser zoom, a screen reader, OS reduced motion and real background-tab transitions. Synthetic lifecycle tests and a narrow viewport are useful but not substitutes for these checks.

## Release gate

Freeze sources before the final build and full suite. Verify eight artifact hashes, installed-package entry points in an isolated profile, offline behavior and browser downloads. Publish only on an authorized release checkpoint, then verify remote assets, Pages behavior and `gh attestation verify`. Until the required device/VM rows pass, retain pre-release status and specific unverified labels.
