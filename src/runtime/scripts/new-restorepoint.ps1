param([string]$Description='',[string]$OutDir='')
$ErrorActionPreference='Stop'
try {
  Import-Module (Join-Path $PSScriptRoot '..\modules\Windows.psm1') -Force
  Import-Module (Join-Path $PSScriptRoot '..\modules\IO.psm1') -Force
  $parameters=@{};if($Description){$parameters.Description=$Description}
  $result=New-SyrinRestorePoint @parameters
  if($OutDir){Write-SyrinAtomicJson (Join-Path $OutDir 'restorepoint.json') $result}
  $result|ConvertTo-Json -Depth 5
  if(-not $result.ok){exit 2}
} catch { [PSCustomObject]@{ok=$false;error=$_.Exception.Message}|ConvertTo-Json -Compress;exit 2 }
