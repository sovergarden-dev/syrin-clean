param([string]$Runtime=(Join-Path $PSScriptRoot '..\src\runtime'))
$ErrorActionPreference='Stop'
Import-Module (Join-Path $Runtime 'modules\Audit.psm1') -Force
Import-Module (Join-Path $Runtime 'modules\Report.psm1') -Force
Import-Module (Join-Path $Runtime 'modules\Windows.psm1') -Force
$auditModule=Get-Module Audit;$windowsModule=Get-Module Windows
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('syrin-runtime-tests-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
$savedEnvironment=@{}
foreach($key in @('USERPROFILE','LOCALAPPDATA','APPDATA','TEMP','TMP')){$savedEnvironment[$key]=[Environment]::GetEnvironmentVariable($key,'Process')}
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
  $result=New-SyrinReport -OutDir $out -Lang vi
  Assert (Test-Path -LiteralPath $result.path) 'Report missing'
  $share=New-SyrinReport -OutDir $out -Lang en -Share
  $shared=[IO.File]::ReadAllText($share.path)
  Assert (-not $shared.Contains('PRIVATE_') -and -not $shared.Contains(('b'*64))) 'Private data leaked into aggregate export'
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
  Assert (@(Get-ChildItem -LiteralPath $out -Filter '.syrin-write-*').Count -eq 0) 'Atomic write left temporary files'
  Write-Output 'PASS report regeneration replaces existing output and preserves it after a locked-file failure'
  Import-Module (Join-Path $Runtime 'modules\IO.psm1') -Force
  $nested=& (Join-Path $Runtime 'scripts\make-report.ps1') -OutDir $out -Lang vi -NoOpen | ConvertFrom-Json
  Assert $nested.ok 'Nested report entry point failed'
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
  $before=[IO.File]::ReadAllBytes($result.path)
  [IO.File]::WriteAllText((Join-Path $out 'audit.json'),'not JSON')
  $rejected=$false;try{New-SyrinReport -OutDir $out|Out-Null}catch{$rejected=$true}
  Assert $rejected 'Malformed JSON accepted'
  Assert ([Convert]::ToBase64String($before) -eq [Convert]::ToBase64String([IO.File]::ReadAllBytes($result.path))) 'Valid report overwritten by failure'
  Json (Join-Path $out 'audit.json') $audit
  $none=New-SyrinReport -OutDir $out -Mode none;Assert ($null -eq $none.path) 'Disabled HTML mode produced a path'
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
} finally {
  foreach($key in $savedEnvironment.Keys){[Environment]::SetEnvironmentVariable($key,$savedEnvironment[$key],'Process')}
  [Environment]::SetEnvironmentVariable('SYRIN_TEST_RESULT',$null,'Process')
  $full=[IO.Path]::GetFullPath($fixture);$parent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
  if([IO.Path]::GetDirectoryName($full) -ne $parent -or [IO.Path]::GetFileName($full) -notlike 'syrin-runtime-tests-*'){throw 'Unexpected fixture cleanup path'}
  Remove-Item -LiteralPath $full -Recurse -Force
}
