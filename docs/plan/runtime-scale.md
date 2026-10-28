# Runtime scale and composition

Status: implementation and local validation complete, 2026-10-29; hosted validation remains pending for the new commit. Automatic file-operation and system-tuning permissions are unchanged.

- [x] Preserve caller commands when entry points import shared modules; reproduce the failure through a public script and verify the fix.
- [x] Reduce repeated path-provider calls while retaining dynamic ancestor checks and native file identity checks at mutation time.
- [x] Parse journal records and compute their digests from the same read; retain schema, ownership, sequence and containment validation.
- [x] Provide complete, paginated offline history rather than silently omitting sessions or items; keep explicit coverage notices.
- [x] Bound animation work and retain pause, visibility and reduced-motion controls.
- [x] Verify representative large fixture trees, report regeneration, corruption detection, caller composition and the existing failure-recovery suite.
- [x] Update architecture, support boundaries, handoff and changelog. Keep private machine reports outside source and public validation.
- [ ] Update the existing draft pull request and confirm CI for its final head. Keep the unverified VM, platform, provider and accessibility gates explicit.

Acceptance: existing safety regressions stay green; a large fixture plan finishes within its existing budget; all loaded history is reachable through report controls; caller imports remain usable; benchmarks state their workload and environment rather than implying universal timings.
