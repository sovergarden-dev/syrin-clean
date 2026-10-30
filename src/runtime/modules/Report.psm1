Set-StrictMode -Version 2
Import-Module (Join-Path $PSScriptRoot 'IO.psm1')

function Test-SyrinNumber($Value) {
  return ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) -and -not [double]::IsNaN([double]$Value) -and -not [double]::IsInfinity([double]$Value) -and $Value -ge 0
}

function Assert-SyrinReportFields($Value,[string[]]$Names) {
  if($Value -isnot [PSCustomObject]){throw 'Expected a JSON object.'}
  foreach($name in $Names){if(@($Value.PSObject.Properties.Name) -cnotcontains $name){throw "Missing canonical JSON field: $name"}}
}

function Read-SyrinReportJson([string]$Path) {
  $file=Get-Item -LiteralPath (Assert-SyrinLocalPath $Path) -ErrorAction Stop
  if($file.Length -gt 20MB){throw 'Input exceeds the 20 MB report limit. Use a smaller session export.'}
  return Read-SyrinJson $file.FullName
}

function Assert-SyrinAudit($Audit) {
  if(-not $Audit -or $Audit -is [array] -or -not $Audit.PSObject.Properties['meta']){throw 'Audit must be an object with metadata.'}
  Assert-SyrinReportFields $Audit.meta @()
  if(-not $Audit.PSObject.Properties['schemaVersion']){
    Assert-SyrinReportFields $Audit @('meta','system','volumes')
    if($Audit.system -isnot [array] -or $Audit.volumes -isnot [array]){throw 'Unrecognized legacy audit format.'}
    return
  }
  Assert-SyrinReportFields $Audit @('schemaVersion','kind','meta','collectors')
  Assert-SyrinReportFields $Audit.meta @('sessionId','generatedUtc','machineId','systemDrive','reportMode','scope')
  Assert-SyrinReportFields $Audit.collectors @()
  if(-not(Test-SyrinNumber $Audit.schemaVersion) -or $Audit.schemaVersion -ne 1 -or $Audit.kind -isnot [string] -or $Audit.kind -cne 'syrin-audit'){throw 'Unsupported audit schema.'}
  if($Audit.meta.sessionId -notmatch '^[a-f0-9]{32}$' -or $Audit.meta.reportMode -notin @('3d','simple','none')){throw 'Invalid audit session or report mode.'}
  if($Audit.meta.machineId -and $Audit.meta.machineId -cnotmatch '^[a-f0-9]{64}$'){throw 'Invalid machine identity.'}
  [void][DateTime]::Parse([string]$Audit.meta.generatedUtc,[Globalization.CultureInfo]::InvariantCulture)
  if($Audit.meta.systemDrive -and $Audit.meta.systemDrive -notmatch '^[A-Za-z]:$'){throw 'Invalid system volume.'}
  foreach($property in $Audit.collectors.PSObject.Properties){
    $collector=$property.Value
    Assert-SyrinReportFields $collector @('status','data','errors')
    if($collector.status -cnotin @('complete','partial','failed','unavailable') -or $collector.errors -isnot [array]){throw "Invalid collector: $($property.Name)"}
    if($null -eq $collector.data -or $collector.data -isnot [array]){throw "Collector data must be an array: $($property.Name)"}
    foreach($row in $collector.data){if($null -eq $row -or $row -isnot [PSCustomObject]){throw 'Collector rows must be objects.'}}
    foreach($message in $collector.errors){if($message -isnot [string]){throw 'Collector errors must be strings.'}}
  }
  if($Audit.collectors.PSObject.Properties['volumes']){
    foreach($volume in @($Audit.collectors.volumes.data)){
      if($volume.drive -notmatch '^[A-Za-z]:$' -or -not (Test-SyrinNumber $volume.sizeBytes) -or -not (Test-SyrinNumber $volume.freeBytes) -or $volume.freeBytes -gt $volume.sizeBytes){throw 'Invalid measured volume sizes.'}
    }
  }
  if($Audit.collectors.PSObject.Properties['radar']){
    foreach($item in @($Audit.collectors.radar.data)){
      if($item.category -notin @('cache','app-data','user-data','vm','system','unknown') -or -not (Test-SyrinNumber $item.measuredBytes) -or -not (Test-SyrinNumber $item.cloudBytes) -or $item.status -notin @('complete','partial')){throw 'Invalid radar measurement.'}
      if($null -ne $item.estimatedReclaimableBytes -and -not (Test-SyrinNumber $item.estimatedReclaimableBytes)){throw 'Invalid reclaimable estimate.'}
    }
  }
  if($Audit.collectors.PSObject.Properties['events']){foreach($row in $Audit.collectors.events.data){if(-not (Test-SyrinNumber $row.count)){throw 'Invalid event count.'}}}
  if($Audit.collectors.PSObject.Properties['startup']){foreach($row in $Audit.collectors.startup.data){if(-not $row.PSObject.Properties['enabled'] -or ($null -ne $row.enabled -and $row.enabled -isnot [bool])){throw 'Invalid startup state.'}}}
}

function Read-SyrinProposals([string]$OutDir,[string]$SessionId) {
  $path=Join-Path $OutDir 'proposals.json'
  if(Test-Path -LiteralPath $path){
    $value=Read-SyrinReportJson $path
    if($value.schemaVersion -ne 1 -or $value.kind -ne 'syrin-proposals' -or $value.sessionId -ne $SessionId -or $value.items -isnot [array]){throw 'Proposal schema or session does not match the audit.'}
    $seen=New-Object 'System.Collections.Generic.HashSet[string]'
    foreach($item in $value.items){
      if($item.id -notmatch '^[A-Za-z0-9][A-Za-z0-9.-]{0,63}$' -or -not $seen.Add($item.id) -or $item.risk -notin @('low','review','high') -or $item.undo -notin @('reversible','partial','irreversible','not-applicable')){throw 'Invalid or duplicate proposal item.'}
      foreach($field in @('title','evidence','benefit','loss')){if(-not $item.PSObject.Properties[$field] -or $item.$field -isnot [string]){throw "Missing proposal text field: $field"}}
    }
    return $value
  }
  $csv=Join-Path $OutDir 'proposals.csv'
  if(Test-Path -LiteralPath $csv){return [PSCustomObject]@{schemaVersion=0;kind='legacy-proposals';items=@(Import-Csv -LiteralPath $csv -Encoding UTF8);warning='Legacy CSV is display-only; it cannot authorize an operation.'}}
  return $null
}

function Get-SyrinShareAudit($Audit) {
  if(-not $Audit.PSObject.Properties['schemaVersion'] -or $Audit.schemaVersion -ne 1){throw 'Shared export requires the current schema.'}
  $collectors=[ordered]@{}
  foreach($name in @('volumes','memory')){
    if(-not $Audit.collectors.PSObject.Properties[$name]){continue}
    $source=$Audit.collectors.$name
    $rows=@()
    foreach($row in $source.data){
      if($name -eq 'volumes'){$rows += [PSCustomObject]@{drive=$row.drive;sizeBytes=$row.sizeBytes;freeBytes=$row.freeBytes;isSystem=$row.isSystem}}
      else {$rows += [PSCustomObject]@{availableBytes=$row.availableBytes;committedBytes=$row.committedBytes;commitLimitBytes=$row.commitLimitBytes;commitPercent=$row.commitPercent}}
    }
    $collectors[$name]=[PSCustomObject]@{status=$source.status;data=$rows;errors=@();durationMs=0}
  }
  if($Audit.collectors.PSObject.Properties['radar']){
    $rows=@($Audit.collectors.radar.data | Group-Object category | ForEach-Object {[PSCustomObject]@{id=$_.Name;label=$_.Name;category=$_.Name;measuredBytes=[long](($_.Group | Measure-Object measuredBytes -Sum).Sum);cloudBytes=[long](($_.Group | Measure-Object cloudBytes -Sum).Sum);estimatedReclaimableBytes=$null;status=$(if(@($_.Group | Where-Object status -ne 'complete').Count){'partial'}else{'complete'});errors=@()}})
    $collectors.radar=[PSCustomObject]@{status=$Audit.collectors.radar.status;data=$rows;errors=@();durationMs=0}
  }
  return [PSCustomObject]@{schemaVersion=1;kind='syrin-audit';meta=[PSCustomObject]@{sessionId=[guid]::NewGuid().ToString('N');generatedUtc=([DateTime]::Parse($Audit.meta.generatedUtc).ToUniversalTime().ToString('yyyy-MM-dd'));machineId=$null;systemDrive=$Audit.meta.systemDrive;reportMode='simple';scope=$Audit.meta.scope;shared=$true;warnings=@();warningCodes=@('aggregate-only')};collectors=[PSCustomObject]$collectors}
}

function New-SyrinReport {
  param([string]$OutDir,[string]$Baseline='',[ValidateSet('en','vi')][string]$Lang='vi',[string]$Template='',[ValidateSet('auto','3d','simple','none')][string]$Mode='auto',[switch]$Share,[string]$QuarantineRoot='',[switch]$Quiet)
  $folder=Assert-SyrinLocalPath $OutDir
  $Lang=$Lang.ToLowerInvariant();$Mode=$Mode.ToLowerInvariant()
  $timer=[Diagnostics.Stopwatch]::StartNew()
  $progressPath=Join-Path $folder 'report-progress.json'
  $progress=[ordered]@{schemaVersion=1;kind='syrin-report-progress';runId=[guid]::NewGuid().ToString('N');processId=$PID;sessionId=$null;status='running';phase='validating';percentComplete=$null;htmlWritten=$false;history=$null;elapsedMs=0;updatedUtc=$null;error=$null}
  $writeProgressJson=Get-Command Write-SyrinAtomicJson -CommandType Function
  $publish={
    $progress.elapsedMs=$timer.ElapsedMilliseconds;$progress.updatedUtc=[DateTime]::UtcNow.ToString('o')
    & $writeProgressJson $progressPath $progress
    if(-not $Quiet){
      $status=$progress.phase
      if($progress.phase -eq 'history' -and $progress.history){$status='History: {0}/{1} sessions; {2}/{3} events in current session' -f $progress.history.sessionsProcessed,$progress.history.sessionsTotal,$progress.history.sessionEventsVerified,$progress.history.sessionEventsTotal}
      $percent=if($progress.status -eq 'completed'){100}else{-1}
      Write-Progress -Id 31 -Activity 'Syrin clean report' -Status $status -PercentComplete $percent
    }
  }.GetNewClosure()
  try {
    & $publish
    $audit=Read-SyrinReportJson (Join-Path $folder 'audit.json');Assert-SyrinAudit $audit
    $legacy=-not $audit.PSObject.Properties['schemaVersion']
    if($Mode -eq 'auto'){$Mode=$(if($legacy){'simple'}else{$audit.meta.reportMode})}
    $progress.sessionId=$(if($legacy){''}else{$audit.meta.sessionId})
    if($Mode -eq 'none' -and -not $Share){
      $progress.status='skipped';$progress.phase='disabled';& $publish
      return [PSCustomObject]@{ok=$true;path=$null;progressFile=$progressPath;message='HTML output is disabled.'}
    }
    $base=$null
    if($Baseline){
      $base=Read-SyrinReportJson $Baseline;Assert-SyrinAudit $base
      if($legacy -or -not $base.PSObject.Properties['schemaVersion'] -or -not $audit.meta.machineId -or $audit.meta.machineId -ne $base.meta.machineId){throw 'Baseline requires the same verified machine identity and schema.'}
    }
    $sessionId=$(if($legacy){''}else{$audit.meta.sessionId})
    $proposals=Read-SyrinProposals $folder $sessionId
    $history=@()
    if($QuarantineRoot -and -not $Share){
      Import-Module (Join-Path $PSScriptRoot 'Quarantine.psm1')
      $progress.phase='history';& $publish
      $onHistory={param($Detail) $progress.history=$Detail;& $publish}.GetNewClosure()
      $history=@(Get-SyrinHistory $QuarantineRoot -OnProgress $onHistory | Sort-Object createdUtc -Descending | ForEach-Object {
        if(-not $_.ok){return [PSCustomObject]@{ok=$false;sessionId=$_.sessionId;error=$_.error;items=@()}}
        [PSCustomObject]@{ok=$true;sessionId=$_.sessionId;createdUtc=$_.createdUtc;totalItems=@($_.items).Count;items=@($_.items)}
      })
    }
    if($Share){$audit=Get-SyrinShareAudit $audit;$base=$null;$proposals=$null;$history=@();$QuarantineRoot='';$Mode='simple'}
    $progress.phase='rendering';& $publish
    if(-not $Template){$Template=Join-Path $PSScriptRoot '..\assets\report-template.html'}
    $html=[IO.File]::ReadAllText((Assert-SyrinLocalPath $Template),[Text.Encoding]::UTF8)
    if(-not $html.Contains('__SYRIN_DATA__')){throw 'Report template is incompatible with this runtime.'}
    $payload=[ordered]@{audit=$audit;baseline=$base;proposals=$proposals;history=$history;historyRoot=$QuarantineRoot;language=$Lang;mode=$Mode;shared=[bool]$Share}
    $json=(ConvertTo-Json -InputObject $payload -Depth 24 -Compress).Replace('<','\u003c').Replace('>','\u003e').Replace('&','\u0026')
    $html=$html.Replace('__SYRIN_DATA__',$json)
    $name=$(if($Share){'share-report.html'}elseif($Mode -eq 'simple'){'audit-report.html'}else{'report.html'})
    $target=Join-Path $folder $name
    $progress.phase='writing';& $publish
    Write-SyrinAtomicText $target $html
    $progress.htmlWritten=$true;$progress.status='completed';$progress.phase='completed';$progress.percentComplete=100;& $publish
    return [PSCustomObject]@{ok=$true;path=$target;mode=$Mode;shared=[bool]$Share;legacy=$legacy;progressFile=$progressPath;historyErrors=@($history | Where-Object {-not $_.ok}).Count}
  } catch {
    $failure=$_
    if($progress.phase -eq 'completed'){$progress.phase='finalizing'}
    $progress.status='failed';$progress.percentComplete=$null;$progress.error=$failure.Exception.Message
    try{& $publish}catch{Write-Warning 'Report progress could not be saved; the previous progress record may be stale.'}
    throw $failure
  } finally {
    if(-not $Quiet){Write-Progress -Id 31 -Activity 'Syrin clean report' -Completed}
    $timer.Stop()
  }
}

Export-ModuleMember -Function Assert-SyrinAudit,New-SyrinReport,Get-SyrinShareAudit
