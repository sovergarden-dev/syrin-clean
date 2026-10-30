# Journal replay and report progress

Status: completed locally, 2026-10-30. Baseline: `7f7e0b5` on `codex/journal-progress`. [Validation and measurements](../../research/journal-validation.md). No new public release is part of this checkpoint.

Goal: shorten large-history report generation and expose its current phase without changing the journal format, approval binding or file-operation permissions.

- [x] Measure the unchanged runtime in a fresh Windows PowerShell 5.1 process after reboot; keep real-machine inputs and results outside the repository.
- [x] Reduce repeated PowerShell overhead during event reads. Preserve live path checks for every file, BOM decoding, individual JSON parsing and digests of the exact bytes parsed. Prefer the existing parser over a second parser with different semantics.
- [x] Report phase, session/event counts, elapsed time and terminal status. Publish completion only after the atomic HTML write succeeds; retain explicit corrupt-session errors. Skip history reads for aggregate-only sharing.
- [x] Exercise dense journals, batch boundaries, corruption, Unicode/BOM, progress failures, disabled HTML and quiet console behavior using owned fixtures.
- [x] Compare baseline and candidate with identical read-only workloads in fresh processes, regenerate a private real report and run the full regression/build checks.
- [x] Update runtime contracts, command references, validation evidence and generated packages. Record remaining qualification gates separately.

Acceptance: replay produces the same history for valid journals; malformed or tampered journals remain rejected; failed report writes preserve the prior HTML and cannot leave a completed progress record. Benchmarks describe workload and environment, not universal speed claims. No journal cache/index, data migration, cleanup, Windows settings changes or app/process changes are part of this work.
