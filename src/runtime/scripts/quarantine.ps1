[CmdletBinding()]
param(
  [ValidateSet('quarantine','restore','purge','resume','import')][string]$Operation='quarantine',
  [string[]]$Path=@(), [Alias('Root')][string]$QuarantineRoot='', [string]$PlanFile='',
  [string]$SessionId='', [string[]]$ItemId=@(), [string]$Approval='',
  [ValidateSet('skip','rename')][string]$Conflict='skip', [string]$RestoreDirectory='', [string]$LegacyRoot='',
  [switch]$Execute, [switch]$History, [switch]$AllItems
)
$ErrorActionPreference='Stop'
try {
  Import-Module (Join-Path $PSScriptRoot '..\modules\Quarantine.psm1')
  if ($History) { $result=[PSCustomObject]@{ok=$true;sessions=@(Get-SyrinHistory $QuarantineRoot $SessionId)} }
  elseif ($Execute) { $result=Invoke-SyrinFilePlan -PlanFile $PlanFile -Approval $Approval -ItemId $ItemId }
  else { $result=New-SyrinFilePlan -Operation $Operation -Path $Path -Root $QuarantineRoot -SessionId $SessionId -ItemId $ItemId -Conflict $Conflict -RestoreDirectory $RestoreDirectory -LegacyRoot $LegacyRoot -PlanFile $PlanFile }
  if(-not $AllItems -and $result.PSObject.Properties['plan'] -and @($result.plan.items).Count -gt 50){
    $result|Add-Member -NotePropertyName totalItems -NotePropertyValue @($result.plan.items).Count
    $result|Add-Member -NotePropertyName truncated -NotePropertyValue $true
    $result.plan.items=@($result.plan.items|Select-Object -First 50)
  }
  $result | ConvertTo-Json -Depth 24
  if (-not $result.ok) { exit 2 }
} catch {
  [PSCustomObject]@{ok=$false;error=$_.Exception.Message} | ConvertTo-Json -Compress
  exit 2
}
