param([Parameter(Mandatory=$true)][string]$OutDir,[string]$Baseline='',[string]$Template='',[ValidateSet('en','vi')][string]$Lang='vi',[ValidateSet('auto','3d','simple','none')][string]$Mode='auto',[string]$QuarantineRoot='',[switch]$Share,[switch]$NoOpen)
$ErrorActionPreference='Stop'
try {
  Import-Module (Join-Path $PSScriptRoot '..\modules\Report.psm1')
  $result=New-SyrinReport -OutDir $OutDir -Baseline $Baseline -Template $Template -Lang $Lang -Mode $Mode -QuarantineRoot $QuarantineRoot -Share:$Share
  $result|ConvertTo-Json -Compress
  if($result.path -and -not $NoOpen){Start-Process -FilePath $result.path}
} catch { [PSCustomObject]@{ok=$false;error=$_.Exception.Message}|ConvertTo-Json -Compress;exit 2 }
