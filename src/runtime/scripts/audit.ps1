param([string]$OutDir='',[ValidateSet('3d','simple','none')][string]$ReportMode='3d',[ValidateSet('full','health','speed','cleanup')][string]$Scope='full',[ValidateRange(20,900)][int]$MaxSeconds=180,[ValidateSet('en','vi')][string]$Lang='vi',[switch]$Quiet)
$ErrorActionPreference='Stop'
try {
  Import-Module (Join-Path $PSScriptRoot '..\modules\Audit.psm1')
  $result=Invoke-SyrinAudit -OutDir $OutDir -ReportMode $ReportMode -Scope $Scope -MaxSeconds $MaxSeconds -Quiet:$Quiet
  if($ReportMode -ne 'none'){
    Import-Module (Join-Path $PSScriptRoot '..\modules\Report.psm1')
    $report=New-SyrinReport -OutDir $result.outDir -Lang $Lang -Mode $ReportMode
    $result|Add-Member -NotePropertyName report -NotePropertyValue $report.path
  }
  $result|ConvertTo-Json -Depth 6
} catch { [PSCustomObject]@{ok=$false;error=$_.Exception.Message}|ConvertTo-Json -Compress;exit 2 }
