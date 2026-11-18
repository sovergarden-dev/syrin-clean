# Syrin clean

- **Stack & zero-dependency floor**: Windows PowerShell 5.1 (`Add-Type` compiles C# 5 on `.NET Framework 4.x`; no C# 6+ syntax), Python 3.10+ stdlib only, Node.js 22+ stdlib only. Never add npm, pip or NuGet dependencies.
- **PowerShell file encoding**: Every `.ps1` and `.psm1` file in `src/` and `tests/` must be saved as UTF-8 with BOM (`EF BB BF`) and CRLF (`\r\n`) line endings (`CONTRIBUTING.md`).
- **Canonical vs generated artifacts**: Edit only `src/runtime/`, `src/instructions/`, `src/report/`, `src/web/`, `src/shared/`, `src/install.ps1`, `src/extract-runtime.ps1`, `project.json` and `docs/feat/support.md`. Never hand-edit `skill/`, `web/`, `dist/`, `prompts/`, `src/prompt-template.*.txt` or `src/runtime/assets/report-template.html`.
- **Build & full verification**: Run `python -B -X utf8 tools/build.py`, then `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/run.ps1` (`python -B -X utf8 tools/build.py --check` validates parity without writing).
- **Hard execution boundaries**: Automated mutation is restricted to the journaled Windows file lifecycle (`quarantine`, `restore`, `purge`, `resume`, `import`). System tuning/repair/uninstall remain advisory; Android USB diagnostics are strictly read-only; VM and System Restore qualification remain unverified (`docs/feat/support.md`).
- **Documentation map**: Start at `docs/index.md`.
