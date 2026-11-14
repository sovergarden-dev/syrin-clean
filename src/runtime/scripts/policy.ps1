[CmdletBinding()]
param([ValidateSet('audit','approve')][string]$Mode,[string[]]$ProtectedPath=@(),[switch]$Set)
$ErrorActionPreference='Stop'
try {
  Import-Module (Join-Path $PSScriptRoot '..\modules\Policy.psm1')
  if($Set){
    if(-not $Mode){throw 'Choose audit or approve mode.'}
    $settings=@{Mode=$Mode}
    if($PSBoundParameters.ContainsKey('ProtectedPath')){$settings.ProtectedPath=$ProtectedPath}
    $result=Set-SyrinProtection @settings
  }
  else {$result=[PSCustomObject]@{ok=$true;policy=(Get-SyrinProtection)}}
  $result | ConvertTo-Json -Depth 8
} catch {[PSCustomObject]@{ok=$false;error=$_.Exception.Message}|ConvertTo-Json -Compress;exit 2}
