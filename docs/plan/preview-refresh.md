# Preview refresh

Status: in progress, 2026-10-30. Target: `4.0.0-preview.2`, public pre-release with GitHub Pages and offline HTML, continuing the owner's agreed delivery format.

- [x] Finish source review and commit the validated journal/progress and HTML interaction changes (`ea47a07`, `bced9cb`).
- [x] Build the next preview from canonical sources and verify its complete local checks (65 outputs, Node model/lifecycle checks, 18 quarantine cases, 12 runtime groups, dense-history fixture and 9 packaging tests).
- [ ] Push the branch, review the pull request and require both Windows and portable-artifact CI before merging.
- [ ] Publish the exact validated tag and eight allowlisted assets; retain previous release bytes.
- [ ] Deploy the matching Pages artifact, verify public hashes and exercise EN/VI behavior.

VM/System Restore, real cloud/provider matrices, ARM64 and complete assistive-technology qualification remain open. They do not become verified through a preview release. Private audit reports, journal data, screenshots and logs are excluded from public assets.

Evidence: [journal validation](../research/journal-validation.md), [HTML interaction validation](../research/html-interaction-validation.md), [support boundaries](../feat/support.md).
