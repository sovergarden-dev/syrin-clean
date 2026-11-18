param([string]$Runtime=(Join-Path $PSScriptRoot '..\src\runtime'))
$ErrorActionPreference='Stop'
Import-Module (Join-Path $Runtime 'modules\Audit.psm1') -Force
Import-Module (Join-Path $Runtime 'modules\Report.psm1') -Force
Import-Module (Join-Path $Runtime 'modules\Windows.psm1') -Force
$auditModule=Get-Module Audit;$windowsModule=Get-Module Windows
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('syrin-runtime-tests-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
$savedEnvironment=@{}
foreach($key in @('USERPROFILE','LOCALAPPDATA','APPDATA','TEMP','TMP','SystemDrive','windir','ProgramData')){$savedEnvironment[$key]=[Environment]::GetEnvironmentVariable($key,'Process')}
$env:USERPROFILE=Join-Path $fixture 'profile';$env:LOCALAPPDATA=Join-Path $env:USERPROFILE 'local';$env:APPDATA=Join-Path $env:USERPROFILE 'roaming';$env:TEMP=Join-Path $fixture 'temp';$env:TMP=$env:TEMP
foreach($directory in @($env:LOCALAPPDATA,$env:APPDATA,$env:TEMP)){[void][IO.Directory]::CreateDirectory($directory)}
function Assert($Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Json([string]$Path,$Value){[IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Value -Depth 24),(New-Object Text.UTF8Encoding $true))}
try {
  & $auditModule {
    function script:Test-Path{param($LiteralPath) return $LiteralPath -notlike '*WOW6432Node*'}
    function script:Get-ItemProperty{param($LiteralPath,$ErrorAction)
      if($LiteralPath -like '*StartupApproved*'){if($LiteralPath.StartsWith('HKCU')){return [PSCustomObject]@{Demo=[byte[]]@(2,0)}};return [PSCustomObject]@{Demo=[byte[]]@(3,0)}}
      return [PSCustomObject]@{Demo='fixture.exe'}
    }
  }
  $startup=Get-SyrinStartup
  Assert (@($startup.data|Where-Object {$_.hive -eq 'HKCU' -and $_.enabled -eq $true}).Count -eq 1) 'HKCU state overwritten'
  Assert (@($startup.data|Where-Object {$_.hive -eq 'HKLM' -and $_.branch -eq 'Run' -and $_.enabled -eq $false}).Count -eq 1) 'HKLM state incorrect'
  Write-Output 'PASS startup identities remain separate'
  & $auditModule {function script:Get-Item{param($LiteralPath,[switch]$Force,$ErrorAction)throw [UnauthorizedAccessException]::new('Fixture access denied')}}
  $scan=Get-SyrinScan -Path (Join-Path $fixture 'denied')
  Assert (-not $scan.complete -and $scan.errors.Count -gt 0) 'Failed scan marked complete'
  Write-Output 'PASS failed scan remains incomplete'
  & $auditModule {Remove-Item Function:Test-Path;Remove-Item Function:Get-ItemProperty;Remove-Item Function:Get-Item}
  $jobResult=& $auditModule {Invoke-SyrinCollectorJob 'invalid' 10}
  Assert ($jobResult.status -eq 'failed' -and @($jobResult.errors).Count -gt 0) 'Collector child failure was hidden'
  & $auditModule {
    function script:Get-SyrinCloudRoots{return @()}
    function script:Invoke-SyrinCollectorJob([string]$Name,[int]$Seconds){
      $data=@();if($Name -eq 'system'){$data=@([PSCustomObject]@{machineId=('b'*64);systemDrive='D:';windows='Fixture'})}
      return [PSCustomObject]@{status='complete';data=$data;errors=@();durationMs=0}
    }
  }
  $auditOut=Join-Path $fixture 'audit-none'
  $auditResult=& {
    function Import-Module{param($Name,[switch]$Force)}
    & (Join-Path $Runtime 'scripts\audit.ps1') -OutDir $auditOut -Scope health -ReportMode none -Quiet
  } | ConvertFrom-Json
  Assert ($auditResult.ok -and (Test-Path -LiteralPath (Join-Path $auditOut 'audit.json'))) 'Audit entry point failed'
  Assert (@(Get-ChildItem -LiteralPath $auditOut -Filter '*.html').Count -eq 0) 'None mode wrote HTML'
  $progress=Get-Content -LiteralPath $auditResult.progressFile -Raw -Encoding UTF8|ConvertFrom-Json
  $measured=Get-Content -LiteralPath (Join-Path $auditOut 'audit.json') -Raw -Encoding UTF8|ConvertFrom-Json
  Assert ($progress.status -eq 'completed' -and $null -eq $progress.activeCollector -and $progress.completedCount -eq @($measured.collectors.PSObject.Properties).Count -and $progress.sessionId -eq $auditResult.sessionId) 'Audit progress does not describe the completed session'
  Write-Output 'PASS collector process errors are explicit and the audit CLI honors none mode (fixture collectors)'

  $out=Join-Path $fixture 'reports';[void][IO.Directory]::CreateDirectory($out)
  $audit=[ordered]@{schemaVersion=1;kind='syrin-audit';meta=@{sessionId=('a'*32);machineId=('b'*64);systemDrive='D:';generatedUtc='2026-10-28T00:00:00Z';reportMode='3d';scope='full';warnings=@()};collectors=@{
    system=@{status='complete';data=@(@{model='PRIVATE_MODEL';windows='Windows 11'});errors=@()}
    volumes=@{status='complete';data=@(@{drive='D:';volumeId='PRIVATE_VOLUME';sizeBytes=1000;freeBytes=100;isSystem=$true});errors=@()}
    memory=@{status='complete';data=@(@{availableBytes=100;committedBytes=200;commitLimitBytes=400;commitPercent=50});errors=@()}
    startup=@{status='complete';data=@(@{name='PRIVATE_APP';enabled=$true});errors=@()}
    radar=@{status='partial';data=@(@{id='private';label='PRIVATE_FOLDER';path='C:\Users\PRIVATE_USER\private';category='user-data';measuredBytes=100;cloudBytes=0;estimatedReclaimableBytes=$null;status='partial';errors=@('PRIVATE_ERROR')});errors=@('PRIVATE_ERROR')}
  }}
  Json (Join-Path $out 'audit.json') $audit
  $reportModule=Get-Module Report
  & $reportModule {
    $script:BeforeReportWrite=(Get-Command Write-SyrinAtomicText).ScriptBlock
    $script:DuringWrite=$null
    function script:Write-SyrinAtomicText([string]$Path,[string]$Text){
      $script:DuringWrite=Read-SyrinJson (Join-Path ([IO.Path]::GetDirectoryName($Path)) 'report-progress.json')
      & $script:BeforeReportWrite $Path $Text
    }
  }
  try{$result=New-SyrinReport -OutDir $out -Lang vi}finally{& $reportModule {Set-Item Function:Write-SyrinAtomicText $script:BeforeReportWrite}}
  $during=& $reportModule {$script:DuringWrite}
  Assert ($during.status -eq 'running' -and $during.phase -eq 'writing' -and -not $during.htmlWritten -and $null -eq $during.percentComplete) 'Progress claimed completion before the HTML commit'
  $progress=Get-Content -LiteralPath $result.progressFile -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($progress.status -eq 'completed' -and $progress.htmlWritten -and $progress.percentComplete -eq 100 -and $progress.sessionId -eq $audit.meta.sessionId) 'Report completion was not recorded'
  $firstRunId=$progress.runId
  $result=New-SyrinReport -OutDir $out -Lang vi
  Assert (Test-Path -LiteralPath $result.path) 'Report missing'
  $progress=Get-Content -LiteralPath $result.progressFile -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($progress.runId -ne $firstRunId) 'Report rerun retained a stale run identity'
  $share=New-SyrinReport -OutDir $out -Lang en -Share -QuarantineRoot '\\fixture.invalid\never-read'
  $shared=[IO.File]::ReadAllText($share.path)
  Assert (-not $shared.Contains('PRIVATE_') -and -not $shared.Contains(('b'*64))) 'Private data leaked into aggregate export'
  $progress=Get-Content -LiteralPath $share.progressFile -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($null -eq $progress.history -and $progress.status -eq 'completed') 'Aggregate export read irrelevant private history'
  Write-Output 'PASS reports render and aggregate export omits private fields'
  $proposals=@{schemaVersion=1;kind='syrin-proposals';sessionId=('a'*32);items=@(@{id='A';title='Updated cache proposal';evidence='Fixture';benefit='Reviewed';loss='None';risk='low';undo='reversible'})}
  Json (Join-Path $out 'proposals.json') $proposals
  $result=New-SyrinReport -OutDir $out -Lang en
  Assert ([IO.File]::ReadAllText($result.path).Contains('Updated cache proposal')) 'Existing report was not replaced with updated proposals'
  $updated=[IO.File]::ReadAllBytes($result.path)
  $lock=New-Object IO.FileStream($result.path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
  try{
    $rejected=$false;try{New-SyrinReport -OutDir $out|Out-Null}catch{$rejected=$true}
    Assert $rejected 'Locked report replacement was not rejected'
  }finally{$lock.Dispose()}
  Assert ([Convert]::ToBase64String($updated) -eq [Convert]::ToBase64String([IO.File]::ReadAllBytes($result.path))) 'Failed replacement changed the existing report'
  $progress=Get-Content -LiteralPath $result.progressFile -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($progress.status -eq 'failed' -and $progress.phase -eq 'writing' -and -not $progress.htmlWritten -and $null -eq $progress.percentComplete) 'Failed HTML replacement left a completed progress record'
  Assert (@(Get-ChildItem -LiteralPath $out -Filter '.syrin-write-*').Count -eq 0) 'Atomic write left temporary files'
  Write-Output 'PASS report regeneration replaces existing output and preserves it after a locked-file failure'
  & $reportModule {
    $script:BeforeCompletionWrite=(Get-Command Write-SyrinAtomicJson).ScriptBlock
    $script:CompletionFault=$false
    function script:Write-SyrinAtomicJson([string]$Path,$Value,[switch]$CreateOnly){
      if(-not $script:CompletionFault -and $Value.status -eq 'completed'){$script:CompletionFault=$true;throw [IO.IOException]::new('Fixture completion write failure')}
      & $script:BeforeCompletionWrite $Path $Value -CreateOnly:$CreateOnly
    }
  }
  $rejected=$false
  try{New-SyrinReport -OutDir $out -Quiet | Out-Null}catch{$rejected=$true}finally{& $reportModule {Set-Item Function:Write-SyrinAtomicJson $script:BeforeCompletionWrite}}
  $progress=Get-Content -LiteralPath $result.progressFile -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($rejected -and (& $reportModule {$script:CompletionFault}) -and $progress.status -eq 'failed' -and $progress.phase -eq 'finalizing' -and $progress.htmlWritten -and $null -eq $progress.percentComplete) 'A failed completion record was reported as success'
  Write-Output 'PASS completion-status failure remains explicit after the HTML commit'
  Import-Module (Join-Path $Runtime 'modules\IO.psm1') -Force
  $nested=& (Join-Path $Runtime 'scripts\make-report.ps1') -OutDir $out -Lang vi -NoOpen -Quiet | ConvertFrom-Json
  Assert $nested.ok 'Nested report entry point failed'
  Assert ((Get-Content -LiteralPath $nested.progressFile -Raw -Encoding UTF8 | ConvertFrom-Json).status -eq 'completed') 'Quiet mode suppressed durable progress'
  Assert ([bool](Get-Command Write-SyrinAtomicJson -ErrorAction SilentlyContinue)) 'Nested entry point removed a caller IO command'
  $callerOutput=Join-Path $fixture 'caller-output.json'
  Write-SyrinAtomicJson $callerOutput ([ordered]@{caller='preserved'}) -CreateOnly
  Assert ((Read-SyrinJson $callerOutput).caller -eq 'preserved') 'Caller cannot use IO after a nested entry point'
  Write-Output 'PASS nested entry points preserve caller IO commands'
  $encodedPath=Join-Path $fixture 'encoded.json'
  [IO.File]::WriteAllText($encodedPath,'{"label":"đường dẫn","count":7}',[Text.Encoding]::Unicode)
  $document=Read-SyrinJsonDocument $encodedPath
  Assert ($document.value.label -ceq 'đường dẫn' -and $document.value.count -eq 7) 'BOM-aware JSON decoding changed'
  $hash=[Security.Cryptography.SHA256]::Create()
  try{$expectedDigest=([BitConverter]::ToString($hash.ComputeHash([IO.File]::ReadAllBytes($encodedPath)))).Replace('-','').ToLowerInvariant()}finally{$hash.Dispose()}
  Assert ($document.digest -ceq $expectedDigest) 'Document digest was not computed from the original bytes'
  Write-Output 'PASS JSON documents retain BOM decoding and raw-byte integrity'
  $missing=Join-Path $fixture 'missing\nested\future.json'
  Assert ((Assert-SyrinLocalPath $missing).EndsWith('\missing\nested\future.json')) 'Missing path suffix changed during normalization'
  Assert (-not(Test-Path -LiteralPath (Join-Path $fixture 'missing'))) 'Path normalization created directories'
  Assert ((Assert-SyrinLocalPath $encodedPath) -ceq (Get-SyrinPath $encodedPath)) 'Checked and canonical paths disagree'
  foreach($unsafePath in @('\\server\share\file.json','\\?\C:\file.json',($encodedPath+':stream'))){
    $rejected=$false;try{Assert-SyrinLocalPath $unsafePath|Out-Null}catch{$rejected=$true}
    Assert $rejected 'An unsupported path form was accepted'
  }
  Write-Output 'PASS native path normalization preserves missing tails and rejects unsafe forms'
  $before=[IO.File]::ReadAllBytes($result.path)
  [IO.File]::WriteAllText((Join-Path $out 'audit.json'),'not JSON')
  $rejected=$false;try{New-SyrinReport -OutDir $out|Out-Null}catch{$rejected=$true}
  Assert $rejected 'Malformed JSON accepted'
  $progress=Get-Content -LiteralPath $result.progressFile -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($progress.status -eq 'failed' -and $progress.phase -eq 'validating' -and -not $progress.htmlWritten) 'Input failure left stale successful progress'
  Assert ([Convert]::ToBase64String($before) -eq [Convert]::ToBase64String([IO.File]::ReadAllBytes($result.path))) 'Valid report overwritten by failure'
  Json (Join-Path $out 'audit.json') $audit
  $none=New-SyrinReport -OutDir $out -Mode none;Assert ($null -eq $none.path) 'Disabled HTML mode produced a path'
  $progress=Get-Content -LiteralPath $none.progressFile -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($progress.status -eq 'skipped' -and -not $progress.htmlWritten -and $null -eq $progress.percentComplete) 'Disabled HTML mode claimed a completed write'
  $baseline=Join-Path $out 'baseline.json';$audit.meta.machineId=('c'*64);Json $baseline $audit
  $rejected=$false;try{New-SyrinReport -OutDir $out -Baseline $baseline|Out-Null}catch{$rejected=$true}
  Assert $rejected 'Different-machine baseline accepted'
  Write-Output 'PASS malformed inputs, none mode and mismatched baselines handled without overwrite'

  $echo=Join-Path $fixture 'echo arguments.ps1';$echoResult=Join-Path $fixture 'echo.json'
  $env:SYRIN_TEST_RESULT=$echoResult
  [IO.File]::WriteAllText($echo,'param([string]$Value,[string]$Empty,[switch]$Quiet); [PSCustomObject]@{value=$Value;empty=$Empty;quiet=[bool]$Quiet}|ConvertTo-Json|Set-Content -LiteralPath $env:SYRIN_TEST_RESULT -Encoding UTF8',(New-Object Text.UTF8Encoding $true))
  $value='C:\Fixture đường dẫn "quoted"\'
  $process=Invoke-SyrinElevatedScript -Script $echo -Arguments @('-Value',$value,'-Empty','','-Quiet') -NoElevate
  Assert $process.ok 'Argument probe failed'
  $received=Get-Content -LiteralPath $echoResult -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert ($received.value -ceq $value -and $received.empty -ceq '' -and $received.quiet) 'Native argument round-trip failed'
  Write-Output 'PASS native Unicode, quotes, empty argument and trailing slash round-trip'

  & $windowsModule {
    $script:Frequency=720;$script:NewPoint=$false;$script:Calls=0;$script:RollbackFails=$false
    function script:Test-SyrinAdministrator{return $true}
    function script:Get-ItemProperty{param($LiteralPath,$ErrorAction)if($null -eq $script:Frequency){return [PSCustomObject]@{}};return [PSCustomObject]@{SystemRestorePointCreationFrequency=$script:Frequency}}
    function script:New-ItemProperty{param($LiteralPath,$Name,$Value,$PropertyType,[switch]$Force,$ErrorAction)$script:Frequency=$Value}
    function script:Set-ItemProperty{param($LiteralPath,$Name,$Value,$ErrorAction)if($script:RollbackFails){throw 'Fixture rollback failure'};$script:Frequency=$Value}
    function script:Remove-ItemProperty{param($LiteralPath,$Name,$ErrorAction)$script:Frequency=$null}
    function script:Checkpoint-Computer{param($Description,$RestorePointType,$ErrorAction)$script:Description=$Description}
    function script:Get-ComputerRestorePoint{param($ErrorAction)$script:Calls++;[PSCustomObject]@{SequenceNumber=17;Description='same';CreationTime=[DateTime]'2020-01-01'};if($script:NewPoint -and $script:Calls -gt 1){[PSCustomObject]@{SequenceNumber=18;Description=$script:Description;CreationTime=[DateTime]::UtcNow}}}
  }
  $point=New-SyrinRestorePoint -Description 'same' -VerifySeconds 0
  Assert (-not $point.ok -and -not $point.created -and $point.registryRestored) 'Old restore point accepted'
  & $windowsModule {$script:NewPoint=$true;$script:Calls=0}
  $point=New-SyrinRestorePoint -Description 'same' -VerifySeconds 0
  Assert ($point.ok -and $point.sequence -eq 18 -and $point.registryRestored) 'New restore point was not verified'
  & $windowsModule {$script:Calls=0;$script:RollbackFails=$true}
  $point=New-SyrinRestorePoint -Description 'same' -VerifySeconds 0
  Assert (-not $point.ok -and $point.created -and -not $point.registryRestored) 'Registry rollback failure hidden'
  Write-Output 'PASS restore verification checks new sequence/time and reports registry rollback failures (mocked system calls)'
  Import-Module (Join-Path $Runtime 'modules\Policy.psm1')
  Set-SyrinProtection -Mode audit | Out-Null
  $point=New-SyrinRestorePoint -VerifySeconds 0
  Assert (-not $point.ok -and -not $point.created -and $point.error -like '*Audit-only*') 'Audit-only policy reached System Restore'
  $rejected=$false;try{Invoke-SyrinElevatedScript -Script (Join-Path $fixture 'never-run.ps1')|Out-Null}catch{$rejected=$true}
  Assert $rejected 'Audit-only policy allowed elevation'
  Set-SyrinProtection -Mode approve | Out-Null
  Write-Output 'PASS audit-only policy blocks system adapters before elevation or registry access'

  Import-Module (Join-Path $Runtime 'modules\Performance.psm1')
  $frequency=[Diagnostics.Stopwatch]::Frequency
  $before=[PSCustomObject]@{timestamp=0L;logicalProcessors=4;idleTicks=20L;totalTicks=100L;processes=@([PSCustomObject]@{id=10;startedUtc='A';cpuSeconds=1},[PSCustomObject]@{id=11;startedUtc='old';cpuSeconds=1})}
  $after=[PSCustomObject]@{timestamp=2*$frequency;logicalProcessors=4;idleTicks=40L;totalTicks=180L;sampledUtc='2026-01-01T00:00:02Z';availableBytes=2000;uptimeMs=3000;unavailableProcesses=2;processes=@([PSCustomObject]@{id=10;startedUtc='A';cpuSeconds=5;name='Fixture';privateBytes=100},[PSCustomObject]@{id=11;startedUtc='new';cpuSeconds=9;name='ReusedPID';privateBytes=500})}
  $interval=ConvertTo-SyrinPerformanceInterval $before $after
  Assert ($interval.cpuPercent -eq 75 -and $interval.processes.Count -eq 1 -and $interval.processes[0].cpuPercent -eq 50 -and $interval.unavailableProcesses -eq 2) 'CPU normalization or PID reuse protection failed'
  $after.timestamp=0
  $rejected=$false;try{ConvertTo-SyrinPerformanceInterval $before $after|Out-Null}catch{$rejected=$true};Assert $rejected 'Zero-duration CPU interval accepted'
  Write-Output 'PASS performance deltas normalize across cores and exclude reused process IDs'

  $androidOut=Join-Path $fixture 'android';[void][IO.Directory]::CreateDirectory($androidOut)
  $phone=@{schemaVersion=1;kind='syrin-audit';meta=@{sessionId=('c'*32);generatedUtc='2026-01-01T00:00:00Z';machineId=('d'*64);systemDrive=$null;platform='android';reportMode='simple';scope='health';warnings=@()};collectors=@{
    system=@{status='complete';data=@(@{model='PRIVATE_PHONE';android='14';userId=10});errors=@()}
    storage=@{status='complete';data=@(@{queriedPath='/data';mount='/data/user/0';sizeBytes=1000;freeBytes=400;usedBytes=600});errors=@()}
    battery=@{status='complete';data=@(@{chargePercent=77;temperatureC=34;statusCode=2;healthCode=2;usbPowered=$true;extra='PRIVATE_UNEXPECTED'});errors=@()}
    packages=@{status='complete';data=@(@{package='PRIVATE_PACKAGE'});errors=@()}
  }}
  Json (Join-Path $androidOut 'audit.json') $phone
  $report=New-SyrinReport -OutDir $androidOut -Lang en -Quiet
  Assert (Test-Path -LiteralPath $report.path) 'Android report failed'
  $share=New-SyrinReport -OutDir $androidOut -Lang en -Share -Quiet
  $html=[IO.File]::ReadAllText($share.path)
  Assert (-not $html.Contains('PRIVATE_') -and -not $html.Contains(('d'*64)) -and -not $html.Contains('/data/user/0') -and $html.Contains('"mount":"/data"') -and $html.Contains('"platform":"android"') -and $html.Contains('"chargePercent":77')) 'Android aggregate export leaked identity or lost measured data'
  $rejected=$false;try{New-SyrinReport -OutDir $androidOut -QuarantineRoot $fixture -Quiet|Out-Null}catch{$rejected=$true};Assert $rejected 'Android report accepted Windows file history'
  $phone.collectors.storage.data[0].freeBytes=2000;Json (Join-Path $androidOut 'audit.json') $phone
  $rejected=$false;try{New-SyrinReport -OutDir $androidOut -Quiet|Out-Null}catch{$rejected=$true};Assert $rejected 'Invalid Android storage size accepted'
  Write-Output 'PASS Android reports preserve platform boundaries, validate measurements and minimize shared data'

  $firstPython=Join-Path $fixture 'first python.ps1';$secondPython=Join-Path $fixture 'second python.ps1';$fixtureAdb=Join-Path $fixture 'adb.exe'
  $stubDir=Join-Path $fixture 'Microsoft\WindowsApps';[void][IO.Directory]::CreateDirectory($stubDir)
  $storeStub=Join-Path $stubDir 'python.exe';[IO.File]::WriteAllText($storeStub,'store alias stub')
  [IO.File]::WriteAllText($firstPython,('$global:LASTEXITCODE=0'+"`n"+"'{`"ok`":true,`"devices`":[{`"serial`":`"FIXTURE`",`"state`":`"device`",`"transport`":`"7`"}]}'"))
  [IO.File]::WriteAllText($secondPython,"throw 'Second Python entry must not run'")
  [IO.File]::WriteAllText($fixtureAdb,'fixture; not executable')
  $discovery=& {
    param($Entry,$Adb,$Stub,$First,$Second)
    function Get-Command {
      param($Name,$CommandType,$ErrorAction)
      if($Name -eq 'python.exe'){return @([PSCustomObject]@{Source=$Stub},[PSCustomObject]@{Source=$First},[PSCustomObject]@{Source=$Second})}
      Microsoft.PowerShell.Core\Get-Command @PSBoundParameters
    }
    & $Entry -AdbPath $Adb -Devices
  } (Join-Path $Runtime 'scripts\android-audit.ps1') $fixtureAdb $storeStub $firstPython $secondPython | ConvertFrom-Json
  Assert ($discovery.ok -and $discovery.devices.Count -eq 1 -and $discovery.devices[0].serial -eq 'FIXTURE') 'Android CLI did not skip WindowsApps stub and select the first real Python application'
  Write-Output 'PASS Android CLI skips WindowsApps alias stubs and selects the first real Python application (fixture runner)'

  & $auditModule {
    function script:Get-SyrinCloudRoots{return @()}
    Remove-Item Function:Invoke-SyrinCollectorJob -ErrorAction SilentlyContinue
  }
  $env:SystemDrive=Join-Path $fixture 'sysdrive';$env:windir=Join-Path $fixture 'windows';$env:ProgramData=Join-Path $fixture 'programdata'
  foreach($sysFolder in @($env:SystemDrive,$env:windir,$env:ProgramData)){[void][IO.Directory]::CreateDirectory($sysFolder)}
  $downloadsDir=Join-Path $env:USERPROFILE 'Downloads';[void][IO.Directory]::CreateDirectory($downloadsDir)
  $isoStream=[IO.File]::Create((Join-Path $downloadsDir 'installer.iso'));try{$isoStream.SetLength(315621376L)}finally{$isoStream.Dispose()}
  $capturesDir=Join-Path (Join-Path $env:USERPROFILE 'Videos') 'Captures';[void][IO.Directory]::CreateDirectory($capturesDir)
  [IO.File]::WriteAllBytes((Join-Path $capturesDir 'clip.mp4'),(New-Object byte[] 1024))
  $radarRes=Invoke-SyrinCollector -Name 'radar' -Seconds 20
  $labels=@($radarRes.data | ForEach-Object {[string]$_.label})
  Assert ($labels -contains 'Video Captures' -and @($labels | Where-Object {$_ -match 'CHI LIET KE|DU LIEU CA NHAN'}).Count -eq 0) 'Radar retained hardcoded Vietnamese labels or missed Video Captures'
  $largeRes=Invoke-SyrinCollector -Name 'largeFiles' -Seconds 10
  Assert ($largeRes.data.Count -eq 1 -and $largeRes.data[0].path.EndsWith('\Downloads\installer.iso',[StringComparison]::OrdinalIgnoreCase) -and $largeRes.data[0].measuredBytes -eq 315621376L) 'Downloads folder was not measured for large files'
  $unclassifiedDir=Join-Path $env:LOCALAPPDATA 'CustomHeavyTool';[void][IO.Directory]::CreateDirectory($unclassifiedDir)
  $modelStream=[IO.File]::Create((Join-Path $unclassifiedDir 'model.bin'));try{$modelStream.SetLength(536870912L)}finally{$modelStream.Dispose()}
  $hotspots=Invoke-SyrinCollector -Name 'hotspots' -Seconds 10
  Assert (@($hotspots.data | Where-Object {$_.label -eq 'CustomHeavyTool' -and $_.location -eq 'LocalAppData' -and $_.measuredBytes -eq 536870912L}).Count -eq 1) 'Hotspot collector missed unclassified LocalAppData folder'
  $projDir=Join-Path $env:USERPROFILE 'demo-web';$nmDir=Join-Path $projDir 'node_modules\pkg';[void][IO.Directory]::CreateDirectory($nmDir)
  [IO.File]::WriteAllText((Join-Path $projDir 'package.json'),'{"name":"demo"}')
  [IO.File]::WriteAllBytes((Join-Path $nmDir 'index.js'),(New-Object byte[] 4096))
  $devRes=Invoke-SyrinCollector -Name 'devArtifacts' -Seconds 10
  Assert (@($devRes.data | Where-Object {$_.artifactType -eq 'node_modules' -and $_.measuredBytes -eq 4096}).Count -eq 1) 'Developer artifact collector missed anchored node_modules'
  $env:SystemDrive=$savedEnvironment['SystemDrive'];$env:windir=$savedEnvironment['windir'];$env:ProgramData=$savedEnvironment['ProgramData']
  Write-Output 'PASS English radar labels, Downloads large-file scan, hotspots and anchored devArtifacts verified'

  & $windowsModule {
    function script:Test-SyrinAdministrator{return $false}
    function script:Start-Process{throw (New-Object ComponentModel.Win32Exception 50)}
  }
  try {
    $sandboxed=Invoke-SyrinElevatedScript -Script $echo -Arguments @('-Quiet')
    Assert (-not $sandboxed.ok -and $sandboxed.exitCode -eq 50 -and $sandboxed.failureKind -ceq 'elevation-unsupported' -and $sandboxed.manualCommand -like '*powershell.exe*-File*') 'Sandbox elevation block did not return manualCommand'
  } finally {
    & $windowsModule {Remove-Item Function:Start-Process -ErrorAction SilentlyContinue}
  }
  Write-Output 'PASS sandboxed elevation block returns elevation-unsupported and manualCommand'
} finally {
  foreach($key in $savedEnvironment.Keys){[Environment]::SetEnvironmentVariable($key,$savedEnvironment[$key],'Process')}
  [Environment]::SetEnvironmentVariable('SYRIN_TEST_RESULT',$null,'Process')
  $full=[IO.Path]::GetFullPath($fixture);$parent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
  if([IO.Path]::GetDirectoryName($full) -ne $parent -or [IO.Path]::GetFileName($full) -notlike 'syrin-runtime-tests-*'){throw 'Unexpected fixture cleanup path'}
  Remove-Item -LiteralPath $full -Recurse -Force
}
