# Runtime commands

Run from an extracted package in Windows PowerShell 5.1. The examples name placeholders; they are not permission to act on real files. Keep the working directory, selected data and quarantine storage separate.

## Audit

```powershell
& .\syrin-clean\scripts\audit.ps1 -Scope full -ReportMode 3d -Lang vi -Quiet
```

The JSON result identifies the private session directory and incomplete collectors. `-Scope health` skips detailed storage scans. `-ReportMode simple` writes a report without animation; `none` writes JSON/state only and does not delete an older report. An explicit OutDir must be new/empty or already owned by the same audit session.

Read `audit-progress.json` in that directory for the last reported collector, completed count, elapsed time and completion status. `-Quiet` suppresses the console progress display, not this file. A completed audit can still contain partial or unavailable collectors.

`-Scope speed` includes a 30-second CPU/memory series. `-PerformanceSeconds 2..60` opts other scopes into sampling. Use `-ContextLabel 'same normal workload'` on comparable captures; matching labels do not themselves prove equal conditions. CPU differences are percentage points, not a percentage speed-up.

## Protection and stopping

Read the current policy with `scripts/policy.ps1`. After the user's restriction request, `scripts/policy.ps1 -Set -Mode audit -ProtectedPath <literal-path-array>` saves audit-only mode and exclusions. Merge existing exclusions when adding entries. Changing to `-Mode approve` requires an explicit unlock request and still grants no approval to act. Optional `-PolicyFile` on planning adds restrictions; the default policy always applies. A changed bound policy requires a fresh plan.

For execution, generate a fresh GUID without hyphens and choose a new stop-file path outside selected sources/quarantine. Add `-RunId <guid> -StopFile <private-stop-path>` to the reviewed execution command. `scripts/request-stop.ps1 -RunId <same-guid> -StopFile <same-path>` requests a stop after the current atomic item. Inspect `stopped`, `stopReason`, `items` and `unprocessed`; do not terminate the worker.

`scripts/quarantine.ps1 -Verify -QuarantineRoot <owned-root> -SessionId <session>` checks journals and physical stored metadata under the writer lock. It does not inspect content hashes, repair, restore or delete files. An intact snapshot is not a restore guarantee.

## Android USB diagnostics

Python 3.10+ and official Google SDK Platform Tools are additional prerequisites. No download, install or phone mutation is automatic.

```powershell
& .\syrin-clean\scripts\android-audit.ps1 -AdbPath 'C:\path-to\platform-tools\adb.exe' -Devices
& .\syrin-clean\scripts\android-audit.ps1 -AdbPath 'C:\path-to\platform-tools\adb.exe' -Serial <exact-selected-serial> -Lang en
```

The second command requires an authorized USB transport and writes to a new private session, never overwriting a previous audit. `-IncludePackages` adds current-user app inventory; `-IncludeAppSizes` adds top 25 per-package storage breakdown (`dumpsys diskstats`); `-IncludeThermal` adds thermal throttling state and skin temperature (`dumpsys thermalservice`); `-Package <exact-package>` adds cumulative frame counters for that app, and `-FrameWindowSeconds 2..30` samples two `gfxinfo` reads across a bounded user interaction without resetting counters. `-MaxSeconds` accepts 30 to 300; `-NoReport` suppresses HTML. No browser opens automatically. Missing/denied/OEM-specific fields remain incomplete. The HTML does not expose Windows file actions for Android. Use the existing `make-report.ps1 -Share -NoOpen` flow for an aggregate export. See [device boundaries](../feat/devices.md).

## Plan and execute selected files

```powershell
& .\syrin-clean\scripts\quarantine.ps1 -Operation quarantine -Path <files-or-directories> -QuarantineRoot <empty-local-root> -PlanFile <working-directory>\file-plan.json
```

Inspect the exact paths, short codes, directory `groups` (`G1..Gn`), item IDs and consequences. A directory is expanded to files; no directory tree is deleted. The source and quarantine root must be on the same volume and must not overlap. A plan saved with more than 50 items returns a clearly marked summary; inspect the file or use `-AllItems` to read the remainder.

After the human confirms the selected plan-local codes or directory groups, execute only that selection:

```powershell
& .\syrin-clean\scripts\quarantine.ps1 -Execute -PlanFile <plan.json> -Approval <exact-digest> -ItemId <id-1>,<id-2>
& .\syrin-clean\scripts\quarantine.ps1 -Execute -PlanFile <plan.json> -Approval <exact-digest> -GroupId G1,G2
```

Do not combine planning and automatic approval into a script. Do not edit the plan after confirmation. A mismatch requires a new review. `ok=false`, conflicts and unprocessed IDs are not completion.

## History, recovery and purge

```powershell
& .\syrin-clean\scripts\history.ps1 -Root <quarantine-root>
& .\syrin-clean\scripts\quarantine.ps1 -History -QuarantineRoot <root> -SessionId <session-id>
& .\syrin-clean\scripts\quarantine.ps1 -Operation restore -QuarantineRoot <root> -SessionId <session-id> -ItemId <id> -Conflict rename -PlanFile <working-directory>\recovery-plan.json
```

Restore defaults to retaining an existing destination and recording conflict. `-Conflict rename` proposes a different name; `-RestoreDirectory` chooses a separate local recovery directory. Review and execute the new plan as above. Repeat calls do not overwrite a later user edit.

`-Operation resume` creates a reconciliation plan for selected IDs. It never silently repeats deletion. A missing file after an interrupted purge is ambiguous and requires inspection. `-Operation purge` creates a separate irreversible plan for stored files; it never deletes unlisted data or the root.

## Legacy storage

```powershell
& .\syrin-clean\scripts\quarantine.ps1 -Operation import -LegacyRoot <old-named-root> -QuarantineRoot <separate-new-root> -PlanFile <working-directory>\legacy-plan.json
```

The importer reads both active and archived CSV manifests under `PC-Optimize-Quarantine` or `Syrin-Clean-Quarantine`, validates containment and previews still-stored files. The legacy root must pass the same source policy as new selections; restore rechecks current cloud/protected-path restrictions. Confirm IDs and execute the import plan; it creates a new journal without moving files or rewriting old metadata. Imported sessions support separately approved restore only. Unsafe, foreign-owner, inaccessible or unsupported records require separate recovery; never weaken validation to force import.

## Reports and sharing

For Android first use, run `android-audit.ps1 -Check -AdbPath <absolute-adb-path>`, then add `-Serial <selected-serial>` to verify that exact phone. `ok=true` means the check ran; only `ready=true` means the selected phone passed readiness. The command does not create an audit or authorize changes. With an existing PATH installation, `-AdbPath` can be omitted.

For app diagnostics, add `-Package <exact-package> -ContextLabel <one-line-task-description>` to the Android audit command. The label is limited to 240 characters. The report keeps the process, cumulative counter origin and capture times; unknown origins or ambiguous processes stay partial, and an observed header for a different app is rejected. No counter reset, app launch or force-stop occurs.

```powershell
& .\syrin-clean\scripts\make-report.ps1 -OutDir <audit-directory> -Lang vi -QuarantineRoot <root>
& .\syrin-clean\scripts\make-report.ps1 -OutDir <new-audit-directory> -Baseline <old-audit.json> -Lang en
& .\syrin-clean\scripts\make-report.ps1 -OutDir <audit-directory> -Share -NoOpen
```

Only compatible machine/volume identities are compared. Invalid data does not replace a good report. `share-report.html` omits raw paths, names, commands, identifiers, errors and history. Review it before sharing; it is not automatically uploaded. Use `proposals.json` with the bundled schema for advisory rows; legacy CSV is display-only.

`make-report.ps1` returns `progressFile` and `historyErrors`. Read `report-progress.json` for `phase`, `status`, `elapsedMs`, `updatedUtc` and the current run ID. During history replay, `history` contains `sessionsProcessed`, `sessionsTotal`, `sessionsFailed`, `activeSession`, `sessionEventsVerified`, `sessionEventsTotal` and cumulative `eventsVerified`. Event counts describe verified records, not permission to execute them. A completed HTML can still contain failed sessions: inspect `historyErrors` and the displayed errors.

`-Quiet` hides console progress but keeps the progress file; `-NoOpen` prevents launching a browser. Running phases do not estimate a percentage. Only a committed HTML reaches 100%; failures record `failed`, and `-Mode none` records `skipped` without claiming an HTML write. A completion-record failure can leave `htmlWritten=true` alongside `failed`; the HTML was saved, but status publication failed. If the process is killed or progress storage becomes unavailable, the last timestamp can be stale. Progress files are private working data and are not part of the shared export. `-Share` skips history reads even if `-QuarantineRoot` was supplied.

When `-QuarantineRoot` is supplied, all loaded sessions/items are embedded in the offline report. Select a session and use the file-page, search and state controls; selections persist across pages, filters and EN/VI changes within that session. Legacy truncated snapshots remain marked as limited. Restore and permanent-delete (`purge`) controls prepare a request only and never execute an OS command; the permanent-delete request button enables only when every selected item is intact `quarantined` in a non-imported session. The language requested by `-Lang` is the initial report language; the public sample defaults to English. Original records are not machine-translated.

`Print summary` prints measurements and proposals, with a notice that full history and raw collector records remain in the HTML. The shared canvas renderer pauses when hidden/offscreen or disabled and has a reduced-motion path. Simple mode does not start the canvas renderer.

## Public HTML delivery

`web/index.html` and `dist/syrin-clean.html` are byte-identical English-default EN/VI entry points. `web/report-demo.html` and `dist/syrin-clean-report-demo.html` contain the labeled synthetic report. The ZIP and Markdown downloads inside the page follow its selected language.

`artifact-manifest.json` lists the six release payloads by filename, and `SHA256SUMS.txt` covers those files plus the manifest itself. All paths are flat so downloaded release assets can be checked together without recreating the source tree.

From a validated clean checkout, `python -B -X utf8 tools/publish_site.py <empty-directory-outside-checkout>` stages only the two HTML files, `og-preview.png`, `robots.txt`, `sitemap.xml`, `.nojekyll` and `version.json`. It refuses nonempty staging destinations and never stages session data. GitHub Pages opens the hosted page; release attachments download as files. Opening an attachment afterward depends on the user's browser and file association.

The release workflow stages on Windows after validation, then deploys the transferred artifact after checking the published release digests. To redeploy an existing published tag explicitly, run `gh workflow run pages.yml --ref main -f release_tag=<published-tag>`. The `github-pages` environment must allow the intended deployment ref; do not remove its protection rules to force a deployment.

On release events, the workflow also stages eight current assets using `tools/stage_release.py <empty-directory-outside-checkout>`, verifies every published digest, and attests them with the pinned GitHub action. Manual redeploys verify the two published HTML assets and skip provenance staging/signing, so older tags do not need the newer staging helper. Verify a downloaded file with `gh attestation verify <downloaded-file> -R sovergarden-dev/syrin-clean --signer-workflow sovergarden-dev/syrin-clean/.github/workflows/pages.yml`; pin the intended source commit and tag as shown in the [4.1.0-preview.1 publication record](../research/device-release-verification.md). All eight files for that release were verified live. This does not claim attestations for older releases.

## Elevation and Restore Point helper

For a native PowerShell call, use an argument array. From another shell, write a request JSON containing `script` and `arguments`, then call `run-elevated.ps1 -RequestFile <json>`. This avoids shell-specific array parsing. Elevation requires `approve` policy mode; under `audit` mode `run-elevated.ps1` fails closed before launching a process. When a sandboxed agent environment blocks `Verb='RunAs'` (Win32 `5`, `50` or `740`), the JSON result returns `failureKind='elevation-unsupported'` and `manualCommand` so the human can run that command in an elevated PowerShell window. `-NoElevate` runs under the existing token and does not drop privileges if the caller is already elevated.

`new-restorepoint.ps1 -OutDir <working-directory>` requires Windows PowerShell 5.1, administrator rights and existing System Protection. It does not enable protection. Require `ok=true`, a new sequence and `registryRestored=true`. The real system path is not qualified in this development build; use a disposable VM for verification.
