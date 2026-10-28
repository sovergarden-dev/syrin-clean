param([string]$Root='',[string]$SessionId='',[string]$AuditRoot='')
$ErrorActionPreference='Stop'
try {
  Import-Module (Join-Path $PSScriptRoot '..\modules\Quarantine.psm1') -Force
  Import-Module (Join-Path $PSScriptRoot '..\modules\IO.psm1') -Force
  if(-not $AuditRoot){$AuditRoot=Join-Path $env:LOCALAPPDATA 'SyrinClean\Sessions'}
  $audits=@()
  if(Test-Path -LiteralPath $AuditRoot){
    [void](Assert-SyrinLocalPath $AuditRoot)
    foreach($folder in Get-ChildItem -LiteralPath $AuditRoot -Directory -ErrorAction Stop){
      $path=Join-Path $folder.FullName 'session.json'
      if(-not(Test-Path -LiteralPath $path)){continue}
      try{[void](Assert-SyrinLocalPath $path);$session=Read-SyrinJson $path;if($session.kind -eq 'syrin-audit-session' -and $session.ownerSid -eq (Get-SyrinOwner)){$audits += [PSCustomObject]@{sessionId=$session.sessionId;createdUtc=$session.createdUtc;outDir=$folder.FullName}}}catch{$audits += [PSCustomObject]@{outDir=$folder.FullName;error=$_.Exception.Message}}
    }
  }
  [PSCustomObject]@{ok=$true;audits=$audits;fileSessions=@(Get-SyrinHistory -Root $Root -SessionId $SessionId)}|ConvertTo-Json -Depth 24
} catch {[PSCustomObject]@{ok=$false;error=$_.Exception.Message}|ConvertTo-Json -Compress;exit 2}
