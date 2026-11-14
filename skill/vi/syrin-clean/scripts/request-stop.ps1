[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$StopFile,[Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{32}$')][string]$RunId)
$ErrorActionPreference='Stop'
try {
  Import-Module (Join-Path $PSScriptRoot '..\modules\IO.psm1')
  $path=Assert-SyrinLocalPath $StopFile
  Write-SyrinAtomicJson $path ([ordered]@{schemaVersion=1;kind='syrin-stop';runId=$RunId;requestedUtc=[DateTime]::UtcNow.ToString('o')}) -CreateOnly
  [PSCustomObject]@{ok=$true;runId=$RunId;stopFile=$path;message='Requested. The current atomic file operation may finish; inspect the executor result and history.'}|ConvertTo-Json -Compress
} catch {[PSCustomObject]@{ok=$false;error=$_.Exception.Message}|ConvertTo-Json -Compress;exit 2}
