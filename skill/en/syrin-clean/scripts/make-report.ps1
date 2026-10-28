# make-report.ps1 - Build report.html (3D scene from the real measurements + tables) from audit.json, proposals.csv and an optional baseline.
# Read-only: it only reads collected data and writes report.html.
#   powershell -NoProfile -ExecutionPolicy Bypass -File make-report.ps1 -OutDir <working folder> [-Baseline <old audit.json>] [-Lang vi|en] [-Template <report-template.html>] [-NoOpen]
param([Parameter(Mandatory = $true)][string]$OutDir, [string]$Baseline = '', [string]$Template = '', [ValidateSet('vi', 'en')][string]$Lang = 'vi', [switch]$NoOpen)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$tplPath = if ($Template) { $Template } else { Join-Path (Split-Path -Parent $here) 'assets\report-template.html' }
if (-not (Test-Path -LiteralPath $tplPath)) { throw "Template not found: $tplPath" }
$tpl = [IO.File]::ReadAllText($tplPath, [Text.Encoding]::UTF8)
function Read-JsonText([string]$p) {
  if ($p -and (Test-Path -LiteralPath $p)) { return ([IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)).Trim([char]0xFEFF, ' ', "`r", "`n", "`t") }
  return 'null'
}
$audit = Read-JsonText (Join-Path $OutDir 'audit.json')
if ($audit -eq 'null') { throw 'audit.json not found in OutDir. Run audit.ps1 first.' }
$base = Read-JsonText $Baseline
$prop = 'null'
$csv = Join-Path $OutDir 'proposals.csv'
if (Test-Path -LiteralPath $csv) {
  $rows = @(Import-Csv -LiteralPath $csv -Encoding UTF8)
  if ($rows.Count) { $prop = ConvertTo-Json -InputObject $rows -Depth 3 -Compress }
}
function Safe([string]$s) { return $s.Replace('</', '<\/') }
$html = $tpl.Replace('/*__AUDIT__*/null', (Safe $audit)).Replace('/*__BASELINE__*/null', (Safe $base)).Replace('/*__PROPOSALS__*/null', (Safe $prop)).Replace("/*__LANG__*/'vi'", "'$Lang'")
$out = Join-Path $OutDir 'report.html'
[IO.File]::WriteAllText($out, $html, (New-Object Text.UTF8Encoding $true))
Write-Host "REPORT=$out"
if (-not $NoOpen) { Start-Process -FilePath $out }
