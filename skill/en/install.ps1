# install.ps1 - Cai skill syrin-clean cho cac agent ho tro Agent Skills
# (Claude Code doc ~/.claude/skills; Codex, GitHub Copilot, Cursor, Gemini CLI, OpenCode doc ~/.agents/skills).
# Chi sao chep thu muc skill, khong cai phan mem, khong ket noi mang.
$ErrorActionPreference = 'Stop'
$src = Join-Path $PSScriptRoot 'syrin-clean'
if (-not (Test-Path -LiteralPath (Join-Path $src 'SKILL.md'))) { throw 'Khong tim thay syrin-clean\SKILL.md canh install.ps1. Hay giai nen toan bo file zip truoc.' }
foreach ($base in (Join-Path $env:USERPROFILE '.claude\skills'), (Join-Path $env:USERPROFILE '.agents\skills')) {
  $dst = Join-Path $base 'syrin-clean'
  New-Item -ItemType Directory -Path $base -Force | Out-Null
  if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
  Copy-Item -LiteralPath $src -Destination $base -Recurse -Force
  Get-ChildItem -LiteralPath $dst -Recurse -File | Unblock-File
  Write-Host "Da cai: $dst" -ForegroundColor Green
}
Write-Host 'Xong. Hay mo PHIEN MOI cua agent de skill duoc nap.' -ForegroundColor Cyan
