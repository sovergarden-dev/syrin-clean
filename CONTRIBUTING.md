# Contributing

Syrin clean can move or permanently remove files. Preserve the safety boundary and prove failure behavior before adding new mutation capabilities.

## Sources

Edit `src/runtime`, `src/instructions`, `src/report` and `src/web`. Skill trees, web pages, prompts and distribution archives are generated. Both languages share the same runtime; policy/phase content is authored once per language.

Use Windows PowerShell 5.1, UTF-8 BOM and CRLF for PowerShell sources. Keep executable code/messages in English and product UI localized. Avoid arbitrary command evaluation, whole-root deletion, profile changes, downloaded scripts and real personal data in tests.

## Validation

Run `python -B -X utf8 tools/build.py`, then `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/run.ps1`. Tests must use owned disposable directories/profiles and restore process environment. Dangerous OS boundaries are mocked in the default suite; real qualification belongs in a disposable VM with a snapshot.

A regression test should prove an observable failure or safety property. Include conflict, interrupted write, identity replacement, stale plan, lock, reparse and missing-data cases where relevant. A passing syntax check or a mock does not certify the real Windows service.

For UI changes, inspect real rendered pages, keyboard behavior, report states and actual downloads. Keep self-contained offline output. Do not ship synthetic audit data as a runtime fallback.

## Change descriptions

Describe the trigger, changed behavior, validation and remaining limitations. Include recovery/compatibility handling for persisted formats. Use explicit imports for legacy data; never silently rewrite existing journals on startup. Do not publish a release or claim a supported platform until its qualification gates have passed.

See [execution](docs/arch/execution.md), [validation](docs/ref/validation.md) and [support](docs/feat/support.md).
