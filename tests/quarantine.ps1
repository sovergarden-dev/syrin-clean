param([string]$Runtime=(Join-Path $PSScriptRoot '..\src\runtime'))
$ErrorActionPreference='Stop'
Import-Module (Join-Path $Runtime 'modules\Quarantine.psm1') -Force
$module=Get-Module Quarantine
& $module { $script:FixtureCloudRoots=@(); function script:Get-SyrinCloudRoots { return $script:FixtureCloudRoots } }
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('syrin-tests-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
$savedEnv=@{}
foreach($key in @('USERPROFILE','LOCALAPPDATA','APPDATA','TEMP','TMP')) {$savedEnv[$key]=[Environment]::GetEnvironmentVariable($key,'Process')}
$env:USERPROFILE=Join-Path $fixture 'profile';$env:LOCALAPPDATA=Join-Path $env:USERPROFILE 'local';$env:APPDATA=Join-Path $env:USERPROFILE 'roaming';$env:TEMP=Join-Path $fixture 'temp';$env:TMP=$env:TEMP
foreach($p in @($env:LOCALAPPDATA,$env:APPDATA,$env:TEMP)){[void][IO.Directory]::CreateDirectory($p)}
$script:count=0
$script:planNumber=0
function Assert($Condition,[string]$Message){if(-not $Condition){throw $Message}}
function File([string]$Name,[string]$Text='original'){$p=Join-Path $fixture $Name;[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($p));[IO.File]::WriteAllText($p,$Text);return $p}
function Plan($Arguments){$script:planNumber++;$Arguments.PlanFile=Join-Path $fixture ('plan-'+$script:planNumber+'.json');return New-SyrinFilePlan @Arguments}
function Execute($Plan,[string[]]$Ids=@()) {if(-not $Ids.Count){$Ids=@($Plan.plan.items|ForEach-Object{$_.id})};return Invoke-SyrinFilePlan -PlanFile $Plan.planFile -Approval $Plan.approval -ItemId $Ids}
function Pass([string]$Name){$script:count++;Write-Output "PASS $Name"}
try {
  $source=File 'first\one.txt';$root=Join-Path $fixture 'storage'
  $plan=Plan @{Path=@($source);Root=$root}
  Assert (Test-Path -LiteralPath $source) 'Plan changed source'
  Assert (-not (Test-Path -LiteralPath $root)) 'Plan created storage'
  $rejected=$false;try{Invoke-SyrinFilePlan -PlanFile $plan.planFile -Approval ('0'*64) -ItemId @($plan.plan.items[0].id)|Out-Null}catch{$rejected=$true}
  Assert $rejected 'Wrong approval was accepted'
  $result=Execute $plan
  Assert $result.ok ('Quarantine failed: '+($result|ConvertTo-Json -Depth 5 -Compress))
  Assert (-not(Test-Path -LiteralPath $source)) 'Source was not moved'
  $item=$plan.plan.items[0]
  Assert ([IO.File]::ReadAllText($item.stored) -eq 'original') 'Stored bytes changed'
  Pass 'plan is read-only; approval binds execution; custom root honored'

  [IO.File]::WriteAllText($source,'new content')
  $restore=Plan @{Operation='restore';Root=$root;SessionId=$plan.plan.sessionId;ItemId=@($item.id)}
  $result=Execute $restore
  Assert (-not $result.ok -and $result.items[0].state -eq 'conflict') 'Conflict was hidden'
  Assert ([IO.File]::ReadAllText($source) -eq 'new content') 'Existing file overwritten'
  $history=@(Get-SyrinHistory $root $plan.plan.sessionId)
  Assert ($history[0].items[0].state -eq 'conflict') 'Conflict vanished from history'
  $restore=Plan @{Operation='restore';Root=$root;SessionId=$plan.plan.sessionId;ItemId=@($item.id);Conflict='rename'}
  $result=Execute $restore
  Assert $result.ok 'Rename restore failed'
  Assert ([IO.File]::ReadAllText($restore.plan.items[0].destination) -eq 'original') 'Restored bytes differ'
  Pass 'restore conflict retained; alternate name preserves both versions'

  $a=File 'purge\a.txt';$b=File 'purge\b.txt';$p=Plan @{Path=@($a,$b);Root=$root};$r=Execute $p;Assert $r.ok 'Purge setup failed'
  $unlisted=Join-Path $root 'unlisted.txt';[IO.File]::WriteAllText($unlisted,'keep')
  $purge=Plan @{Operation='purge';Root=$root;SessionId=$p.plan.sessionId;ItemId=@($p.plan.items[0].id)}
  $r=Execute $purge;Assert $r.ok 'Selected purge failed'
  Assert (-not(Test-Path -LiteralPath $p.plan.items[0].stored)) 'Selected file remains'
  Assert (Test-Path -LiteralPath $p.plan.items[1].stored) 'Unselected file removed'
  Assert (Test-Path -LiteralPath $unlisted) 'Unlisted file removed'
  Assert (Test-Path -LiteralPath (Join-Path $root '.syrin-clean-root.json')) 'Root marker removed'
  Pass 'purge touches only the selected stored file'

  $outside=Join-Path $fixture 'not-owned';[void][IO.Directory]::CreateDirectory($outside);[IO.File]::WriteAllText((Join-Path $outside 'manifest.csv'),'Original,Stored,Bytes')
  $rejected=$false;try{Plan @{Path=@($source);Root=$outside}|Out-Null}catch{$rejected=$true}
  Assert $rejected 'Non-empty unowned directory adopted'
  Pass 'unowned root rejected'

  $changed=File 'changed.txt';$p=Plan @{Path=@($changed);Root=$root};[IO.File]::WriteAllText($changed,'changed length')
  $r=Execute $p;Assert (-not $r.ok) 'Changed source accepted';Assert (Test-Path -LiteralPath $changed) 'Changed source moved'
  Pass 'changed source rejected after approval'

  $cloud=Join-Path $fixture 'cloud\OneDrive';[void][IO.Directory]::CreateDirectory($cloud);[void](File 'cloud\OneDrive\keep.txt')
  & $module {param($p)$script:FixtureCloudRoots=@($p)} $cloud
  $rejected=$false;try{Plan @{Path=@((Split-Path -Parent $cloud));Root=$root}|Out-Null}catch{$rejected=$true}
  Assert $rejected 'Cloud ancestor accepted'
  $sibling=File 'cloud\OneDriveBackup\safe.txt';$p=Plan @{Path=@($sibling);Root=$root};Assert $p.ok 'Non-cloud sibling was blocked'
  & $module {$script:FixtureCloudRoots=@()}
  Pass 'cloud ancestry blocked without prefix false positives'

  $fault=File 'fault.txt';$p=Plan @{Path=@($fault);Root=$root}
  & $module {
    $script:OriginalAtomic=(Get-Command Write-SyrinAtomicJson).ScriptBlock
    function script:Write-SyrinAtomicJson([string]$Path,$Value,[switch]$CreateOnly){
      if($Path -match 'events\\00000002\.json$'){throw 'Injected journal failure'}
      & $script:OriginalAtomic -Path $Path -Value $Value -CreateOnly:$CreateOnly
    }
  }
  $r=Execute $p
  Assert (-not $r.ok) 'Journal failure reported as success'
  Assert (Test-Path -LiteralPath $fault) 'Move was not rolled back after journal failure'
  & $module {Set-Item -LiteralPath Function:Write-SyrinAtomicJson -Value $script:OriginalAtomic}
  $resume=Plan @{Operation='resume';Root=$root;SessionId=$p.plan.sessionId;ItemId=@($p.plan.items[0].id)}
  $r=Execute $resume;Assert ($r.ok -and $r.items[0].state -eq 'planned') 'Interrupted move did not reconcile'
  Pass 'journal failure rolls back; resume reconciles the durable state'

  $lockPath=Join-Path $root '.syrin-clean.lock';$lock=[IO.File]::Open($lockPath,'Open','ReadWrite','None')
  try{$rejected=$false;try{Execute $p|Out-Null}catch{$rejected=$true};Assert $rejected 'Concurrent writer accepted'}finally{$lock.Dispose()}
  Pass 'concurrent writer rejected'

  $legacy=Join-Path $fixture 'PC-Optimize-Quarantine';$legacyStored=File 'PC-Optimize-Quarantine\20200101-010101\old.txt' 'legacy'
  $legacyOriginal=Join-Path $fixture 'recovered\old.txt'
  [PSCustomObject]@{Original=$legacyOriginal;Stored=$legacyStored;Bytes=6;Time='fixture'}|Export-Csv -LiteralPath (Join-Path $legacy 'manifest-restored-old.csv') -NoTypeInformation
  $import=Plan @{Operation='import';Root=$root;LegacyRoot=$legacy};$r=Execute $import;Assert $r.ok 'Explicit legacy import failed'
  Assert (Test-Path -LiteralPath $legacyStored) 'Import moved legacy data'
  $restore=Plan @{Operation='restore';Root=$root;SessionId=$import.plan.sessionId;ItemId=@($import.plan.items[0].id)}
  $r=Execute $restore;Assert ($r.ok -and [IO.File]::ReadAllText($legacyOriginal) -eq 'legacy') 'Legacy restore failed'
  Pass 'legacy archived CSV imported explicitly and restored without rewriting old metadata'

  $raceSource=File 'race\source.txt';$p=Plan @{Path=@($raceSource);Root=$root};$r=Execute $p;Assert $r.ok 'Race setup failed'
  $stored=$p.plan.items[0].stored;$preserved=Join-Path $root 'preserved-original.txt'
  $purge=Plan @{Operation='purge';Root=$root;SessionId=$p.plan.sessionId;ItemId=@($p.plan.items[0].id)}
  & $module {
    param($stored,$preserved)
    $script:RaceStored=$stored;$script:RacePreserved=$preserved
    $script:BeforeRace=(Get-Command Write-SyrinAtomicJson).ScriptBlock
    function script:Write-SyrinAtomicJson([string]$Path,$Value,[switch]$CreateOnly){
      & $script:BeforeRace -Path $Path -Value $Value -CreateOnly:$CreateOnly
      if($Value -is [Collections.IDictionary] -and $Value.Contains('state') -and $Value.state -eq 'purging'){
        [IO.File]::Move($script:RaceStored,$script:RacePreserved)
        [IO.File]::WriteAllText($script:RaceStored,'replacement must survive')
      }
    }
  } $stored $preserved
  $r=Execute $purge
  Assert (-not $r.ok -and (Test-Path -LiteralPath $preserved)) 'Race was not rejected'
  Assert ([IO.File]::ReadAllText($stored) -eq 'replacement must survive') 'A replacement file was deleted'
  & $module {Set-Item -LiteralPath Function:Write-SyrinAtomicJson -Value $script:BeforeRace}
  Pass 'native purge rejects replacement after journal preparation'

  $target=File 'junction-target\data.txt'
  $link=Join-Path $fixture 'junction'
  $policy=& $module {New-SyrinSourcePolicy @()}
  New-Item -ItemType Junction -Path $link -Target ([IO.Path]::GetDirectoryName($target)) | Out-Null
  $rejected=$false;try{& $module {param($Path,$Policy) Assert-SyrinSourcePath $Path -Policy $Policy} $link $policy|Out-Null}catch{$rejected=$true}
  Assert $rejected 'A policy snapshot cached mutable junction attributes'
  $rejected=$false;try{Plan @{Path=@($link);Root=$root}|Out-Null}catch{$rejected=$true}
  Assert $rejected 'Junction source was followed'
  Assert (Test-Path -LiteralPath $target) 'Junction target changed'
  Pass 'real junction rejected before enumeration or mutation'

  $locked=File 'locked.txt';$p=Plan @{Path=@($locked);Root=$root}
  $handle=[IO.File]::Open($locked,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::Read)
  try{$r=Execute $p;Assert (-not $r.ok -and (Test-Path -LiteralPath $locked)) 'Locked file was transferred'}finally{$handle.Dispose()}
  $resume=Plan @{Operation='resume';Root=$root;SessionId=$p.plan.sessionId;ItemId=@($p.plan.items[0].id)}
  $r=Execute $resume;Assert ($r.ok -and $r.items[0].state -eq 'planned') 'Locked-file failure could not reconcile'
  Pass 'real write lock blocks transfer and recovers after unlock'

  $readonly=File 'readonly.txt';$p=Plan @{Path=@($readonly);Root=$root};$r=Execute $p;Assert $r.ok 'Read-only test setup failed'
  $purge=Plan @{Operation='purge';Root=$root;SessionId=$p.plan.sessionId;ItemId=@($p.plan.items[0].id)}
  [IO.File]::SetAttributes($p.plan.items[0].stored,[IO.FileAttributes]::ReadOnly)
  try{$r=Execute $purge;Assert (-not $r.ok -and (Test-Path -LiteralPath $p.plan.items[0].stored)) 'Read-only data was force-deleted'}finally{[IO.File]::SetAttributes($p.plan.items[0].stored,[IO.FileAttributes]::Normal)}
  $resume=Plan @{Operation='resume';Root=$root;SessionId=$p.plan.sessionId;ItemId=@($p.plan.items[0].id)}
  $r=Execute $resume;Assert ($r.ok -and $r.items[0].state -eq 'quarantined') 'Failed purge could not reconcile intact storage'
  Pass 'access denial preserves stored data without forcing attributes'

  $disk=File 'disk-failure.txt';$p=Plan @{Path=@($disk);Root=$root}
  & $module {
    $script:BeforeDiskWriter=(Get-Command Write-SyrinAtomicJson).ScriptBlock
    $script:BeforeDiskMove=(Get-Command Move-SyrinCheckedFile).ScriptBlock
    $script:DiskMoves=0
    function script:Write-SyrinAtomicJson([string]$Path,$Value,[switch]$CreateOnly){if($Path -match 'events\\00000002\.json$'){throw [IO.IOException]::new('Simulated disk full after transfer')}; & $script:BeforeDiskWriter -Path $Path -Value $Value -CreateOnly:$CreateOnly}
    function script:Move-SyrinCheckedFile([string]$Source,[string]$Destination,$Expected){$script:DiskMoves++;if($script:DiskMoves -gt 1){throw [IO.IOException]::new('Simulated rollback I/O failure')}; & $script:BeforeDiskMove $Source $Destination $Expected}
  }
  $r=Execute $p
  Assert (-not $r.ok -and -not(Test-Path -LiteralPath $disk) -and (Test-Path -LiteralPath $p.plan.items[0].stored)) 'Interrupted transfer lost its known stored location'
  & $module {Set-Item -LiteralPath Function:Write-SyrinAtomicJson -Value $script:BeforeDiskWriter;Set-Item -LiteralPath Function:Move-SyrinCheckedFile -Value $script:BeforeDiskMove}
  $resume=Plan @{Operation='resume';Root=$root;SessionId=$p.plan.sessionId;ItemId=@($p.plan.items[0].id)}
  $r=Execute $resume;Assert ($r.ok -and $r.items[0].state -eq 'quarantined') 'Transfer did not reconcile after I/O recovery'
  Pass 'simulated disk and rollback failure retain a recoverable journal'

  $restore=Plan @{Operation='restore';Root=$root;SessionId=$p.plan.sessionId;ItemId=@($p.plan.items[0].id)}
  & $module {
    $script:BeforeRestoreWriter=(Get-Command Write-SyrinAtomicJson).ScriptBlock
    function script:Write-SyrinAtomicJson([string]$Path,$Value,[switch]$CreateOnly){if($Value -is [Collections.IDictionary] -and $Value.Contains('state') -and $Value.state -eq 'restored'){throw [IO.IOException]::new('Simulated restore commit failure')}; & $script:BeforeRestoreWriter -Path $Path -Value $Value -CreateOnly:$CreateOnly}
  }
  $r=Execute $restore;Assert (-not $r.ok -and (Test-Path -LiteralPath $disk)) 'Restore interruption did not preserve restored data'
  & $module {Set-Item -LiteralPath Function:Write-SyrinAtomicJson -Value $script:BeforeRestoreWriter}
  $resume=Plan @{Operation='resume';Root=$root;SessionId=$p.plan.sessionId;ItemId=@($p.plan.items[0].id)}
  $r=Execute $resume;Assert ($r.ok -and $r.items[0].state -eq 'restored') 'Restore interruption did not reconcile'
  [IO.File]::WriteAllText($disk,'later user edit')
  $r=Execute $restore;Assert ($r.ok -and [IO.File]::ReadAllText($disk) -eq 'later user edit') 'Replay overwrote a later edit'
  Pass 'interrupted restore reconciles and replay preserves later edits'

  $proof=File 'integrity\proof.txt';$proofRoot=Join-Path $fixture 'integrity-storage'
  $p=Plan @{Path=@($proof);Root=$proofRoot};$r=Execute $p;Assert $r.ok 'Integrity fixture did not quarantine'
  $sessionFolder=Join-Path (Join-Path $proofRoot 'sessions') $p.plan.sessionId
  $storedPlan=Join-Path $sessionFolder 'plan.json';$planBytes=[IO.File]::ReadAllBytes($storedPlan)
  [IO.File]::AppendAllText($storedPlan,' ')
  $history=@(Get-SyrinHistory $proofRoot $p.plan.sessionId)
  Assert (-not $history[0].ok -and $history[0].error -like '*plan integrity*') 'Changed plan bytes were accepted'
  [IO.File]::WriteAllBytes($storedPlan,$planBytes)
  $eventPath=Join-Path $sessionFolder 'events\00000001.json'
  $event=Get-Content -LiteralPath $eventPath -Raw -Encoding UTF8|ConvertFrom-Json
  $event.error='Changed after the next event was recorded'
  [IO.File]::WriteAllText($eventPath,($event|ConvertTo-Json -Compress),(New-Object Text.UTF8Encoding $true))
  $history=@(Get-SyrinHistory $proofRoot $p.plan.sessionId)
  Assert (-not $history[0].ok -and $history[0].error -like '*integrity*') 'Changed journal bytes were accepted'
  Assert ([IO.File]::ReadAllText($p.plan.items[0].stored) -eq 'original') 'History validation changed stored data'
  Pass 'history verifies raw plan bytes and the journal hash chain'

  $approvalSource=File 'approval-race\source.txt';$approvalRoot=Join-Path $fixture 'approval-storage'
  $p=Plan @{Path=@($approvalSource);Root=$approvalRoot};$r=Execute $p;Assert $r.ok 'Approval-race setup failed'
  $restore=Plan @{Operation='restore';Root=$approvalRoot;SessionId=$p.plan.sessionId;ItemId=@($p.plan.items[0].id)}
  $replacement=$restore.plan|ConvertTo-Json -Depth 24|ConvertFrom-Json
  $replacement.items[0].destination=Join-Path $fixture 'unapproved-destination.txt'
  $race=[PSCustomObject]@{armed=$true;changed=$false;path=$restore.planFile;text=($replacement|ConvertTo-Json -Depth 24)}
  $digestModules=@($module,(Get-Module -All IO|Select-Object -First 1))
  foreach($targetModule in $digestModules){
    & $targetModule {param($Race)
      $script:DigestRace=$Race;$script:BeforeDigest=(Get-Command Get-SyrinDigest).ScriptBlock
      function script:Get-SyrinDigest([byte[]]$Bytes){
        $digest=& $script:BeforeDigest $Bytes
        if($script:DigestRace.armed){$script:DigestRace.armed=$false;[IO.File]::WriteAllText($script:DigestRace.path,$script:DigestRace.text,[Text.UTF8Encoding]::new($false));$script:DigestRace.changed=$true}
        return $digest
      }
    } $race
  }
  try{$r=Execute $restore}finally{foreach($targetModule in $digestModules){& $targetModule {Set-Item -LiteralPath Function:Get-SyrinDigest -Value $script:BeforeDigest}}}
  Assert $race.changed 'Approval race was not exercised'
  Assert ($r.ok -and (Test-Path -LiteralPath $approvalSource) -and -not(Test-Path -LiteralPath $replacement.items[0].destination)) 'Execution used plan content changed after its approval digest was read'
  Pass 'approval and execution use the same plan snapshot'

  Write-Output "Quarantine tests: $script:count passed"
} finally {
  foreach($key in $savedEnv.Keys){[Environment]::SetEnvironmentVariable($key,$savedEnv[$key],'Process')}
  $full=[IO.Path]::GetFullPath($fixture)
  $parent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
  if([IO.Path]::GetDirectoryName($full) -ne $parent -or [IO.Path]::GetFileName($full) -notlike 'syrin-tests-*'){throw 'Unexpected fixture cleanup path'}
  Remove-Item -LiteralPath $full -Recurse -Force
}
