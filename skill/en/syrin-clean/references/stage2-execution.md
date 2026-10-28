# Phase 2: Execute, undo, report

=== PHASE 2: EXECUTE, UNDO, REPORT ===
After I type `CONFIRM`:
1. Check the run conditions (rule 8) and build the safety net (rule 7). Put every Admin operation of the approved codes into ONE logged execution script and self-elevate so I click UAC only once.
2. Order A → B → R → C (repair before cleaning the component store). Never touch codes that were not approved. Log for each code: command, time, result, size before/after, locked files skipped.
3. `undo.ps1` restores every configuration change (Startup, Task, StartupType, power plan, hibernate, registry); its header lists what CANNOT be undone and where soft-deleted files are; syntax-check it (`[ScriptBlock]::Create((Get-Content -Raw <file>))`) before saying you are done.
4. If a restart is needed: explain why, let me choose when, update `state.json` first. When I type `Continue`: check the error log, startup items and boot time yourself and compare with `baseline.json`.
5. FINAL REPORT (compact chat, details in the report): open with 3 plain lines (what was done, what the machine gained in numbers, anything to watch); then a Before/After table against `baseline.json` (free space per drive, GB freed, number of Startup/Task/Service entries, idle RAM/Commit, boot time); codes done / skipped / failed with reasons; how to undo (`Undo` or `Undo: A2`; fallback without the agent: run `powershell -NoProfile -ExecutionPolicy Bypass -File "<path>\undo.ps1"` as Admin, or System Restore `rstrui.exe` with the restore point name); a 7-day checklist (3 to 5 points specific to this machine) and a maintenance plan (Storage Sense, Windows/driver updates, re-run Phase 0 after 30 days). For a before/after report, run the audit again into `<working folder>\after` and build the report with the old `audit.json` as baseline.

Before/after report: run `scripts/audit.ps1 -OutDir <working folder>\after -Quiet`, then `scripts/make-report.ps1 -OutDir <working folder>\after -Baseline <working folder>\audit.json -Lang <vi|en>`. Restore quarantined files: `scripts/quarantine.ps1 -Restore`. Empty the quarantine only when the user approves that code: `scripts/quarantine.ps1 -Purge`.
