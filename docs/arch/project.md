# Syrin clean architecture

> updated 2026-10-28 · v3.6

Syrin clean is a bilingual Windows maintenance skill and prompt toolkit. A compatible AI agent executes the workflow; the HTML pages configure and distribute it. There is no desktop executable, backend or package-manager dependency.

## Sources and generated artifacts

| Source | Role | Output |
|---|---|---|
| `skill/{vi,en}/syrin-clean/` | Skill entry point, phase references, PowerShell scripts and report template | Language-specific skill ZIPs |
| `skill/{vi,en}/install.ps1` | Copies the skill into the user's agent skill directories | Included in each ZIP |
| `src/prompt-template.{vi,en}.txt` | Full prompt with a profile placeholder | Standalone Markdown prompts and embedded browser prompts |
| `web/syrin-clean-{vi,en}-v3.6.html` | Page layout, profile choices, local downloads and visual scene | Updated in place by the build |
| `tools/build.py` | Packages the two editions and updates embedded data | `dist/`, `prompts/` and `web/` |

The two skill editions share identical scripts and report templates. Their skill instructions and phase references are translated separately. Changes to common assets must be applied to both editions before building.

The build stores both ZIP payloads in the Vietnamese page and the English ZIP in the English page. Each generated prompt embeds the audit script, report template and report builder as appendices A, B and C. The build validates page JavaScript when Node.js is available. It does not execute a system audit or cleanup.

## Runtime workflow

1. The agent reads `SKILL.md` and the current phase reference. `audit.ps1` gathers machine metadata and writes JSON plus a simple HTML report.
2. The agent prepares coded proposals and waits for approval, a dry run and confirmation.
3. For approved changes, the agent uses the elevation helper, restore-point helper and quarantine script as needed. It records state, backups and undo commands in the working directory.
4. `make-report.ps1` combines the recorded audit, proposals and optional baseline into a bilingual offline report. The report uses Canvas; the landing page uses WebGL with a Canvas fallback.

Approval is enforced by agent instructions, not by a central execution engine. Running a PowerShell helper directly bypasses the conversational workflow. Runtime validation across Windows editions and architectures remains listed in [HANDOFF.md](../../HANDOFF.md).

## Identity and existing data

The display name is **Syrin clean**, the skill and repository slug is `syrin-clean`, and artifact version 3.6 is retained from the imported handoff. New working folders use `Syrin-Clean-<timestamp>`; new quarantine roots use `Syrin-Clean-Quarantine`.

Renaming the source does not move previously created working folders, installed skills or quarantined data. To restore an older quarantine, explicitly pass its existing directory to `quarantine.ps1 -Restore -QuarantineRoot <existing-directory>`. Continue interrupted sessions from their original state files. The historical v2.0 document stays unchanged for reference.
