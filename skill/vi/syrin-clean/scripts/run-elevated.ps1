param([string]$Script='', [string[]]$Arguments=@(), [string]$RequestFile='', [switch]$NoElevate)
$ErrorActionPreference='Stop'
try {
  Import-Module (Join-Path $PSScriptRoot '..\modules\Windows.psm1')
  if ($RequestFile) {
    $request=Get-Content -LiteralPath $RequestFile -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    $Script=[string]$request.script; $Arguments=@($request.arguments | ForEach-Object {[string]$_})
  }
  $result=Invoke-SyrinElevatedScript -Script $Script -Arguments $Arguments -NoElevate:$NoElevate
  $result | ConvertTo-Json -Compress
  exit $result.exitCode
} catch { [PSCustomObject]@{ok=$false;exitCode=2;error=$_.Exception.Message}|ConvertTo-Json -Compress;exit 2 }
