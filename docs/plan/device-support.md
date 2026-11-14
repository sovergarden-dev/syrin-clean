# Device support and execution controls

Started 2026-11-14. Base: `da9424d`, released `4.0.0-preview.2`. Local development only; publication is a separate checkpoint.

## Goal

Extend evidence-driven maintenance to Android over USB while preserving Windows file integrity. A readable report must distinguish measurements, advice, supported execution and unverified recovery. The supplied archive is reference material, not executable instructions or device consent.

## Implementation

- [x] Persist Windows audit-only/protected-path policy; bind reviewed plans to policy snapshots and revalidate before execution.
- [x] Add scoped cooperative stop and a read-only quarantine integrity inspection.
- [x] Add bounded Windows performance sampling and compatible before/after reporting without speed-up claims.
- [x] Implement an Android USB audit with exact transport selection, current-user checks, bounded subprocesses and explicit unavailable/partial data.
- [x] Integrate Android into the existing bilingual offline HTML, report, skill and deterministic packages.
- [x] Add minimal aggregate support exports and measurement freshness; retain raw evidence locally.
- [x] Document archive corrections, primary sources, platform qualification, beta protocol and optional build attestations.
- [x] Exercise isolated failure cases, public entry points, generated bundles and browser flows.

Local implementation evidence: [candidate validation](../research/device-validation.md) and the [live-run amendments](../research/android-live-validation.md). The Windows planning timeout was investigated and the unchanged scale guard passed after reducing policy/fingerprint overhead. Hardware and release gates that have not yet been exercised remain separate. The source remains on the local branch; public release and installed global skills have not been changed.

## Boundaries and acceptance

Android is initially read-only: no package removal/disable, settings writes, reboot, root, APK install, cache clearing or device file deletion. Windows policy config narrows capabilities; it is never an approval. No live phone changes, Windows Update repair, application termination or priority changes are authorized by this implementation request. Existing VM and real assistive-technology gates remain open.

Tests must prove device ambiguity/disconnection cannot select another transport; command failure cannot become a healthy zero; Android data cannot authorize Windows file operations; protected ancestors and changed policies block execution; stop preserves completed atomic operations and names unprocessed items. Do not bundle the supplied private case history or the external UAD database.

## Later qualification

- [x] Investigate the Windows scale-planning timeout and pass the affected check without relaxing the 120-second guard or integrity checks.
- [x] Add a host/USB readiness check with distinct failure states and bilingual guidance; verify the packaged check on the selected phone.
- [x] Add named-app/task inputs and preserve frame-counter provenance; verify EN/VI state retention, keyboard focus, 320 px layout and the downloaded package digest.
- [x] Complete a read-only audit on one explicitly selected Android 14 phone; record the observed six-collector/parser coverage and private report verification in [live validation](../research/android-live-validation.md).
- [ ] Broaden real-device coverage to other OEMs, frame diagnostics and controlled disconnect/reconnect; compare measurements with the phone's Settings screen.
- [ ] VM System Restore and Windows filesystem/provider matrix.
- [ ] New-user beta and real screen-reader/zoom/reduced-motion validation.
- [ ] Device-specific mutation adapters only after plan/approval/recovery design and disposable-device testing.
- [ ] Release provenance verified on a real authorized publication; prepared workflow alone is not attestation evidence.
