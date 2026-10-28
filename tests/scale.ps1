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
 $sessionCount=12
 for($index=1;$index -lt $sessionCount;$index++){
  $path=Join-Path $fixture ('session-'+$index+'.txt');[IO.File]::WriteAllText($path,'fixture')
  $plan=New-SyrinFilePlan -Path @($path) -Root $root -PlanFile (Join-Path $fixture ('session-plan-'+$index+'.json'))
  $result=Invoke-SyrinFilePlan -PlanFile $plan.planFile -Approval $plan.approval -ItemId @($plan.plan.items[0].id)
  Assert $result.ok 'History fixture did not quarantine'
 }
 $timer.Restart()
 $history=@(Get-SyrinHistory $root)
 $historyMs=$timer.ElapsedMilliseconds
 Assert ($history.Count -eq $sessionCount -and @($history|Where-Object {-not $_.ok}).Count -eq 0) 'History omitted or rejected a fixture session'
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
 Write-Output ("Scale fixture: {0} files; plan {1} ms; {2} sessions; history {3} ms; complete report {4} ms" -f $fileCount,$planningMs,$sessionCount,$historyMs,$reportMs)
}finally{
 foreach($name in $saved.Keys){[Environment]::SetEnvironmentVariable($name,$saved[$name],'Process')}
 $full=[IO.Path]::GetFullPath($fixture);$parent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
 if([IO.Path]::GetDirectoryName($full) -ne $parent -or [IO.Path]::GetFileName($full) -notlike 'syrin-scale-tests-*'){throw 'Unexpected fixture cleanup path'}
 Remove-Item -LiteralPath $full -Recurse -Force
}
