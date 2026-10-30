param([string]$Runtime=(Join-Path $PSScriptRoot '..\src\runtime'))
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('syrin-scale-tests-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
$saved=@{}
foreach($name in @('USERPROFILE','LOCALAPPDATA','APPDATA','TEMP','TMP')){$saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
$env:USERPROFILE=Join-Path $fixture 'profile'
$env:LOCALAPPDATA=Join-Path $env:USERPROFILE 'local'
$env:APPDATA=Join-Path $env:USERPROFILE 'roaming'
$env:TEMP=Join-Path $fixture 'temp';$env:TMP=$env:TEMP
foreach($path in @($env:LOCALAPPDATA,$env:APPDATA,$env:TEMP)){[void][IO.Directory]::CreateDirectory($path)}
function Assert($Condition,[string]$Message){if(-not $Condition){throw $Message}}
try{
 Import-Module (Join-Path $Runtime 'modules\Quarantine.psm1')
 Import-Module (Join-Path $Runtime 'modules\Report.psm1')
 $module=Get-Module Quarantine
 & $module {function script:Get-SyrinCloudRoots{return @()}}
 $source=Join-Path $fixture 'source'
 $fileCount=2048
 $hash=[Security.Cryptography.SHA256]::Create()
 try{
  for($index=0;$index -lt $fileCount;$index++){
   $name=([BitConverter]::ToString($hash.ComputeHash([BitConverter]::GetBytes($index)))).Replace('-','').ToLowerInvariant()
   $folder=Join-Path $source ('cache\'+$name[0]+'\'+$name[1]+'\'+$name[2])
   [void][IO.Directory]::CreateDirectory($folder)
   [IO.File]::WriteAllText((Join-Path $folder ($name.Substring(0,32)+'.bin')),'fixture')
  }
 }finally{$hash.Dispose()}
 $root=Join-Path $fixture 'storage'
 $timer=[Diagnostics.Stopwatch]::StartNew()
 $large=New-SyrinFilePlan -Path @($source) -Root $root -PlanFile (Join-Path $fixture 'large-plan.json')
 $planningMs=$timer.ElapsedMilliseconds
 Assert ($large.ok -and $large.plan.items.Count -eq $fileCount -and $large.plan.measuredBytes -eq ($fileCount*7)) 'Large plan lost files or measured bytes'
 Assert (@(Get-ChildItem -LiteralPath $source -Recurse -File).Count -eq $fileCount) 'Planning mutated the large fixture'
 Assert (-not(Test-Path -LiteralPath $root)) 'Planning created quarantine storage'
 $result=Invoke-SyrinFilePlan -PlanFile $large.planFile -Approval $large.approval -ItemId @($large.plan.items[0].id)
 Assert $result.ok 'Large-plan item did not quarantine'
 $eventDir=Join-Path (Join-Path (Join-Path $root 'sessions') $large.plan.sessionId) 'events'
 $hash=[Security.Cryptography.SHA256]::Create()
 $eventCount=2
 try{
  $previous=([BitConverter]::ToString($hash.ComputeHash([IO.File]::ReadAllBytes((Join-Path $eventDir '00000002.json'))))).Replace('-','').ToLowerInvariant()
  for($index=1;$index -le $fileCount;$index++){
   $item=$large.plan.items[$index % $fileCount]
   foreach($state in @('moving','quarantined')){
    $eventCount++
    $record=[ordered]@{schemaVersion=1;sequence=$eventCount;previous=$previous;itemId=$item.id;state=$state;error='Fixture đường dẫn';restoredPath='';timeUtc='2026-01-01T00:00:00Z'}
    $encoding=if($eventCount % 2){[Text.Encoding]::Unicode}else{[Text.UTF8Encoding]::new($true)}
    $bytes=$encoding.GetPreamble()+$encoding.GetBytes(($record | ConvertTo-Json -Compress))
    [IO.File]::WriteAllBytes((Join-Path $eventDir ('{0:D8}.json' -f $eventCount)),$bytes)
    $previous=([BitConverter]::ToString($hash.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()
   }
  }
 }finally{$hash.Dispose()}
 $sessionCount=12
 for($index=1;$index -lt $sessionCount;$index++){
  $path=Join-Path $fixture ('session-'+$index+'.txt');[IO.File]::WriteAllText($path,'fixture')
  $plan=New-SyrinFilePlan -Path @($path) -Root $root -PlanFile (Join-Path $fixture ('session-plan-'+$index+'.json'))
  $result=Invoke-SyrinFilePlan -PlanFile $plan.planFile -Approval $plan.approval -ItemId @($plan.plan.items[0].id)
  Assert $result.ok 'History fixture did not quarantine'
 }
 $timer.Restart()
 $updates=[Collections.Generic.List[object]]::new()
 $observe={param($Detail) $updates.Add($Detail)}.GetNewClosure()
 $history=@(Get-SyrinHistory $root -OnProgress $observe)
 $historyMs=$timer.ElapsedMilliseconds
 Assert ($history.Count -eq $sessionCount -and @($history|Where-Object {-not $_.ok}).Count -eq 0) 'History omitted or rejected a fixture session'
 $dense=@($history | Where-Object sessionId -eq $large.plan.sessionId)[0]
 Assert (@($dense.items | Where-Object {$_.state -ne 'quarantined' -or $_.error -cne 'Fixture đường dẫn'}).Count -eq 0) 'Dense replay lost a final state or Unicode text'
 $partial=@($updates | Where-Object {$_.activeSession -eq $large.plan.sessionId -and $_.sessionEventsVerified -gt 0 -and $_.sessionEventsVerified -lt $eventCount})
 Assert ($partial.Count -gt 1) 'Dense replay did not publish intermediate verified batches'
 Assert ($updates[$updates.Count-1].sessionsProcessed -eq $sessionCount -and $updates[$updates.Count-1].eventsVerified -eq ($eventCount+2*($sessionCount-1))) 'History progress totals omitted records'
 $rejected=$false
 try{Get-SyrinHistory $root $large.plan.sessionId -OnProgress {param($Detail) if($Detail.sessionEventsVerified -gt 0){throw 'Fixture observer failure'}} | Out-Null}catch{$rejected=$_.Exception -is [OperationCanceledException]}
 Assert $rejected 'Observer failure was swallowed as a corrupt history session'
 $out=Join-Path $fixture 'report';[void][IO.Directory]::CreateDirectory($out)
 $audit=@{schemaVersion=1;kind='syrin-audit';meta=@{sessionId=('a'*32);machineId=('b'*64);systemDrive='C:';generatedUtc=[DateTime]::UtcNow.ToString('o');reportMode='simple';scope='health'};collectors=@{system=@{status='complete';data=@(@{model='Synthetic fixture'});errors=@()};volumes=@{status='complete';data=@(@{drive='C:';volumeId='fixture';sizeBytes=1000;freeBytes=500;isSystem=$true});errors=@()}}}
 [IO.File]::WriteAllText((Join-Path $out 'audit.json'),($audit|ConvertTo-Json -Depth 10),(New-Object Text.UTF8Encoding $true))
 $timer.Restart()
 $report=New-SyrinReport -OutDir $out -QuarantineRoot $root -Lang en
 $reportMs=$timer.ElapsedMilliseconds
 $html=[IO.File]::ReadAllText($report.path)
 $payload=[regex]::Match($html,'(?s)<script type="application/json" id="syrin-data">(.*?)</script>').Groups[1].Value|ConvertFrom-Json
 Assert (@($payload.history).Count -eq $sessionCount) 'Report omitted sessions beyond its old cap'
 $largeHistory=@($payload.history|Where-Object sessionId -eq $large.plan.sessionId)
 Assert ($largeHistory.Count -eq 1 -and $largeHistory[0].items.Count -eq $fileCount -and $largeHistory[0].totalItems -eq $fileCount) 'Report omitted items beyond its old cap'
 $progress=Get-Content -LiteralPath $report.progressFile -Raw -Encoding UTF8 | ConvertFrom-Json
 Assert ($progress.status -eq 'completed' -and $progress.history.sessionsProcessed -eq $sessionCount -and $progress.history.sessionsFailed -eq 0 -and $progress.history.eventsVerified -eq ($eventCount+2*($sessionCount-1))) 'Report progress does not describe its complete history'
 $changedPath=Join-Path $eventDir '00000129.json'
 $originalBytes=[IO.File]::ReadAllBytes($changedPath)
 try{
  $changed=[IO.File]::ReadAllText($changedPath) | ConvertFrom-Json
  $changed.previous='0'*64
  [IO.File]::WriteAllText($changedPath,($changed | ConvertTo-Json -Compress),[Text.Encoding]::Unicode)
  $broken=@(Get-SyrinHistory $root $large.plan.sessionId)
  Assert (-not $broken[0].ok -and $broken[0].error -like '*integrity*') 'Hash-chain damage after a batch boundary was accepted'
  $partialReport=New-SyrinReport -OutDir $out -QuarantineRoot $root -Quiet
  $partialProgress=Get-Content -LiteralPath $partialReport.progressFile -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($partialReport.historyErrors -eq 1 -and $partialProgress.history.sessionsFailed -eq 1 -and $partialProgress.status -eq 'completed') 'Completed HTML hid a failed history session'
  [IO.File]::WriteAllText($changedPath,'{"PRIVATE_MALFORMED":',[Text.Encoding]::UTF8)
  $broken=@(Get-SyrinHistory $root $large.plan.sessionId)
  Assert (-not $broken[0].ok -and $broken[0].error -like '*Invalid JSON*' -and $broken[0].error -notlike '*PRIVATE_MALFORMED*') 'Individual malformed JSON was accepted or echoed'
 }finally{[IO.File]::WriteAllBytes($changedPath,$originalBytes)}
 $before=[IO.File]::ReadAllBytes($report.path)
 $reportModule=Get-Module Report
 & $reportModule {
  $script:BeforeProgressWrite=(Get-Command Write-SyrinAtomicJson).ScriptBlock
  $script:ProgressFault=$false
  function script:Write-SyrinAtomicJson([string]$Path,$Value,[switch]$CreateOnly){
   if(-not $script:ProgressFault -and $Value.kind -eq 'syrin-report-progress' -and $Value.phase -eq 'history' -and $Value.history -and $Value.history.sessionEventsVerified -gt 0){$script:ProgressFault=$true;throw [IO.IOException]::new('Fixture progress write failure')}
   & $script:BeforeProgressWrite $Path $Value -CreateOnly:$CreateOnly
  }
 }
 $rejected=$false
 try{New-SyrinReport -OutDir $out -QuarantineRoot $root -Quiet | Out-Null}catch{$rejected=$true}finally{& $reportModule {Set-Item Function:Write-SyrinAtomicJson $script:BeforeProgressWrite}}
 Assert ($rejected -and (& $reportModule {$script:ProgressFault})) 'Progress I/O failure was ignored during journal replay'
 $failedProgress=Get-Content -LiteralPath $report.progressFile -Raw -Encoding UTF8 | ConvertFrom-Json
 Assert ($failedProgress.status -eq 'failed' -and -not $failedProgress.htmlWritten -and $null -eq $failedProgress.percentComplete) 'Progress I/O failure was converted into completed HTML'
 Assert ([Convert]::ToBase64String($before) -eq [Convert]::ToBase64String([IO.File]::ReadAllBytes($report.path))) 'Failed progress reporting replaced the prior HTML'
 $backupDir=$eventDir+'-original'
 foreach($path in @($eventDir,$backupDir)){Assert ([IO.Path]::GetFullPath($path).StartsWith([IO.Path]::GetFullPath($fixture)+'\',[StringComparison]::OrdinalIgnoreCase)) 'Event fixture move escaped the owned test directory'}
 $swap=@{done=$false}
 $swapEvents={param($Detail)
  if(-not $swap.done -and $Detail.activeSession -eq $large.plan.sessionId -and $Detail.sessionEventsVerified -gt 0 -and $Detail.sessionEventsVerified -lt $Detail.sessionEventsTotal){
   [IO.Directory]::Move($eventDir,$backupDir);$swap.done=$true
   New-Item -ItemType Junction -Path $eventDir -Target $backupDir | Out-Null
  }
 }.GetNewClosure()
 try{
  $broken=@(Get-SyrinHistory $root $large.plan.sessionId -OnProgress $swapEvents)
  Assert ($swap.done -and -not $broken[0].ok -and $broken[0].error -like '*Reparse*') 'A later batch reused stale ancestor validation'
 }finally{
  if($swap.done){
   if(Test-Path -LiteralPath $eventDir){Assert (([IO.File]::GetAttributes($eventDir) -band [IO.FileAttributes]::ReparsePoint) -ne 0) 'Event fixture is not the expected junction';[IO.Directory]::Delete($eventDir)}
   [IO.Directory]::Move($backupDir,$eventDir)
  }
 }
 Write-Output ("Scale fixture: {0} files; plan {1} ms; {2} sessions; {3} events in dense session; history {4} ms; complete report {5} ms" -f $fileCount,$planningMs,$sessionCount,$eventCount,$historyMs,$reportMs)
}finally{
 foreach($name in $saved.Keys){[Environment]::SetEnvironmentVariable($name,$saved[$name],'Process')}
 $full=[IO.Path]::GetFullPath($fixture);$parent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
 if([IO.Path]::GetDirectoryName($full) -ne $parent -or [IO.Path]::GetFileName($full) -notlike 'syrin-scale-tests-*'){throw 'Unexpected fixture cleanup path'}
 Remove-Item -LiteralPath $full -Recurse -Force
}
