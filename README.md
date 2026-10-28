# Syrin clean

**Inspect Windows, review the evidence, approve exact file operations.**

Syrin clean is a bilingual Agent Skill and standalone prompt with a shared Windows PowerShell runtime. This branch contains an **unreleased development hardening build**. It is not a universal compatibility or stable-release claim.

[Tiếng Việt](README.vi.md) · [Commands](docs/ref/commands.md) · [Support matrix](docs/feat/support.md) · [Validation](docs/ref/validation.md) · [Changelog](CHANGELOG.md)

## What it does

- Collects Windows, storage, memory, startup, event, security and hardware metadata through bounded read-only collectors.
- Preserves complete, partial, unavailable and failed states. Missing data never becomes a healthy zero.
- Separates caches, application data, personal files, virtual disks and system data. Measured size is not promised reclaimable space.
- Plans exact files before quarantine, restore or purge. Execution requires the reviewed plan digest and explicit item IDs; people can approve short plan-local codes through the agent.
- Keeps an owned journal, file identity checks, conflict states and recovery history. Purge deletes only the selected stored files, never a directory tree or unlisted data.
- Builds offline bilingual reports, compatible before/after comparisons and aggregate exports that omit raw private fields.

Automatic mutation is limited to the file lifecycle implemented by the runtime. System tuning, repair, uninstall and hardware suggestions remain advisory until a tested adapter/procedure is available. Quarantine is not a backup and does not free space; purge is separate and irreversible. Read the [support and qualification boundaries](docs/feat/support.md).

## Start with an audit

1. Download the [English package](dist/syrin-clean-skill-v3.6-en.zip) or [Vietnamese package](dist/syrin-clean-skill-v3.6-vi.zip) from this branch, or build them locally.
2. Ask your agent to verify the package and run `install.ps1` with Windows PowerShell 5.1. The installer stages and validates both agent locations before switching them; previous versions remain outside the discovery folders under `%USERPROFILE%\.syrin-clean-installer`.
3. Start a new agent session and ask: **Use the syrin-clean skill to audit this PC and prepare proposals only.**
4. Review the evidence and uncertainty. For any supported file action, review the exact plan and confirm only the selected codes. Do not approve a personal-file or purge operation through a vague blanket instruction.

The installer writes `.claude/skills/syrin-clean` and `.agents/skills/syrin-clean`. Installation is tested; discovery and end-to-end behavior of each agent/version still require qualification. No system cleanup runs during installation.

## Standalone prompt and web pages

Use the [English prompt](prompts/syrin-clean-prompt-en-v3.6.md) or [Vietnamese prompt](prompts/syrin-clean-prompt-vi-v3.6.md) with an agent that can run terminal commands. Read the PROMPT section, then extract the bootstrap/runtime appendix with filesystem commands; do not paste Base64 into model context. The extractor checks the digest, blocks path traversal and only writes a new empty runtime directory. It does not execute cleanup. Both channels use the same packaged helpers and safety policy.

Open `web/syrin-clean-en-v3.6.html` or `web/syrin-clean-vi-v3.6.html` after downloading the repository. The pages configure the opening message and download the embedded ZIP or prompt. They do not execute Windows commands. Landing-page fonts use the network; reports contain no external asset dependency.

## Data and privacy

Sessions default to `%LOCALAPPDATA%\SyrinClean\Sessions`; quarantine defaults to `%LOCALAPPDATA%\SyrinClean\Quarantine`. Custom storage must be local, owned and separate from the selected files. Transfers remain on the same volume. Unknown cloud-provider locations and untested filesystems need separate review.

The runtime reads metadata and its own/configuration records, not personal document contents, browser secrets or credentials. It does not upload results. Your agent/provider may process terminal output outside the machine. Raw reports and plans can contain private paths; never commit or share them by accident. `make-report.ps1 -Share -NoOpen` creates a local aggregate export for review, not guaranteed anonymization.

## Development

Python 3.10+, Node.js 22+ and Windows PowerShell 5.1 are required for the full validation flow. No package-manager dependencies are needed.

```powershell
python -B -X utf8 tools/build.py
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/run.ps1
```

`python tools/build.py --check` validates without changing files. Packaging uses an explicit allowlist, manifests, checksums and deterministic ZIP metadata. The same checks run in the [Windows CI workflow](.github/workflows/check.yml); CI does not deploy or publish a release.

| Canonical source | Responsibility |
|---|---|
| `src/runtime/modules/` | Filesystem, journal, collectors, report validation and Windows adapters |
| `src/runtime/scripts/` | Public command entry points |
| `src/instructions/{en,vi}/` | One policy and phase set per language, shared by skill and prompt |
| `src/report/` | Report template, data model, rendering and styles |
| `src/web/` | Shared landing logic/styles and localized markup/profile text |
| `src/install.ps1`, `src/extract-runtime.ps1` | Transactional installation and standalone extraction |
| `tools/build.py` | Generate and validate all delivery formats |

`skill/`, `web/`, `prompts/`, `dist/`, `src/prompt-template.*.txt` and `src/runtime/assets/report-template.html` are generated. Edit their canonical sources, then build. Do not patch an embedded script or ZIP independently.

See [architecture](docs/arch/project.md), [execution contracts](docs/arch/execution.md), [handoff](HANDOFF.md), [contributing](CONTRIBUTING.md) and [security](SECURITY.md). Historical reference material remains under `docs/history` and `docs/references`.

## License

[MIT](LICENSE). Existing attribution is retained. Design references from the original handoff are documented in [references](docs/references/README.md).
