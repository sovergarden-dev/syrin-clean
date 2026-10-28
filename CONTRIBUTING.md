# Contributing

Thank you for helping. This project runs commands on other people's computers, so safety reviews come before features.

## Ground rules

1. Never weaken the hard safety rules (Part 1 of the prompt, `SKILL.md`). Read-only before approval, verified restore point, soft delete, never-touch list.
2. Every new action needs: a group (A/B/C/R/M/D), a plain-language description, what is gained and lost, and how to undo it.
3. Scripts: Windows PowerShell 5.1, UTF-8 with BOM, ASCII strings in code, no `Win32_Product`, no `wmic`, no English performance-counter names, no hard-coded `C:`.
4. Keep the Vietnamese and English versions in sync (`src/`, `skill/vi`, `skill/en`, `web/`).
5. Run `python tools/build.py` before committing.

## Testing checklist

- [ ] Audit-only run on a real Windows 10 or 11 machine, no changes made
- [ ] `report.html` opens and shows the 3D scene
- [ ] Web pages checked with `?check` at 390, 768, 1366, 1920 px
- [ ] `node --check` passes on page scripts (the build does this when Node.js is installed)

## Pull requests

Describe the change, which machines you tested on, and paste the relevant part of `log.txt` when scripts changed.
