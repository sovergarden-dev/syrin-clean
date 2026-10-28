Set-StrictMode -Version 2
Import-Module (Join-Path $PSScriptRoot 'IO.psm1') -Force

function Get-SyrinValue($Object,[string]$Name,$Default=$null) {
  if ($null -eq $Object) { return $Default }
  $property=$Object.PSObject.Properties[$Name]
  if (-not $property -or $null -eq $property.Value) { return $Default }
  return $property.Value
}

function Get-SyrinScan {
  param([string]$Path,[int]$Seconds=30,[switch]$LargeFiles)
  $full=Get-SyrinPath $Path
  [void](Assert-SyrinLocalPath ([IO.Path]::GetDirectoryName($full)))
  $timer=[Diagnostics.Stopwatch]::StartNew();$bytes=0L;$cloud=0L;$count=0;$complete=$true
  $errors=New-Object 'System.Collections.Generic.List[string]';$large=New-Object 'System.Collections.Generic.List[object]'
  $stack=New-Object 'System.Collections.Generic.Stack[string]';$stack.Push($full)
  while($stack.Count){
    if($timer.Elapsed.TotalSeconds -ge $Seconds){$complete=$false;$errors.Add('Scan budget exhausted.');break}
    $current=$stack.Pop()
    try {
      $entry=Get-Item -LiteralPath $current -Force -ErrorAction Stop
      $flags=[int]$entry.Attributes
      if(($flags -band 0x400) -ne 0){$complete=$false;$errors.Add("Reparse point skipped: $current");continue}
      if($entry -is [IO.DirectoryInfo]){
        if(($flags -band 0x441000) -ne 0){$complete=$false;$errors.Add("Cloud directory not enumerated: $current");continue}
        foreach($child in $entry.EnumerateFileSystemInfos()){
          if($timer.Elapsed.TotalSeconds -ge $Seconds){$complete=$false;$errors.Add('Scan budget exhausted.');break}
          if($LargeFiles -and $child.Name -match '^(\.git|\.ssh|\.aws|\.azure|\.gnupg|\.kube|AppData)$'){continue}
          $stack.Push($child.FullName)
        }
      } else {
        $count++
        if(($flags -band 0x441000) -ne 0){$cloud+=$entry.Length;continue}
        $bytes+=$entry.Length
        if($LargeFiles -and $entry.Length -ge 300MB){$large.Add([PSCustomObject]@{path=$entry.FullName;measuredBytes=[long]$entry.Length;lastWriteUtc=$entry.LastWriteTimeUtc.ToString('o');category='user-data'})}
      }
    } catch {$complete=$false;$errors.Add($_.Exception.Message)}
  }
  return [PSCustomObject]@{path=$full;measuredBytes=$bytes;cloudBytes=$cloud;files=$count;complete=$complete;errors=$errors.ToArray();largeFiles=@($large | Sort-Object measuredBytes -Descending | Select-Object -First 20)}
}

function Get-SyrinStartup {
  $entries=New-Object 'System.Collections.Generic.List[object]';$errors=New-Object 'System.Collections.Generic.List[string]'
  $locations=@(
    @{hive='HKCU';branch='Run';run='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';approved='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'},
    @{hive='HKLM';branch='Run';run='HKLM:\Software\Microsoft\Windows\CurrentVersion\Run';approved='HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'},
    @{hive='HKLM';branch='Run32';run='HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run';approved='HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32'}
  )
  foreach($location in $locations){
    try {
      if(-not(Test-Path -LiteralPath $location.run)){continue}
      $values=Get-ItemProperty -LiteralPath $location.run -ErrorAction Stop
      $approved=$null;if(Test-Path -LiteralPath $location.approved){$approved=Get-ItemProperty -LiteralPath $location.approved -ErrorAction Stop}
      foreach($property in $values.PSObject.Properties){
        if($property.Name -in @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider')){continue}
        $enabled=$null;$raw=$null;$entry=if($approved){$approved.PSObject.Properties[$property.Name]}else{$null}
        if($entry -and $entry.Value -is [byte[]] -and $entry.Value.Length){$raw=[int]$entry.Value[0];if($raw -in @(2,6)){$enabled=$true}elseif($raw -in @(3,7)){$enabled=$false}}
        $entries.Add([PSCustomObject]@{id=($location.hive+':'+$location.branch+':'+$property.Name);name=$property.Name;hive=$location.hive;branch=$location.branch;enabled=$enabled;rawState=$raw})
      }
    } catch {$errors.Add($_.Exception.Message)}
  }
  return [PSCustomObject]@{data=$entries.ToArray();errors=$errors.ToArray()}
}

function Get-SyrinRadar {
  param([int]$Seconds=40)
  $sys=$env:SystemDrive;$L=$env:LOCALAPPDATA;$R=$env:APPDATA;$U=$env:USERPROFILE;$W=$env:windir;$PD=$env:ProgramData
  $radar = [ordered]@{
    'User Temp' = $env:TEMP; 'Windows Temp' = "$W\Temp"; 'WU Download' = "$W\SoftwareDistribution\Download"
    'Delivery Optimization' = "$W\SoftwareDistribution\DeliveryOptimization"
    'Windows.old' = "$sys\Windows.old"; '$Windows.~BT' = "$sys\`$Windows.~BT"; '$WinREAgent' = "$sys\`$WinREAgent"
    'CBS Logs' = "$W\Logs\CBS"; 'MEMORY.DMP' = "$W\MEMORY.DMP"; 'Minidump' = "$W\Minidump"; 'LiveKernelReports' = "$W\LiveKernelReports"
    'WER (ProgramData)' = "$PD\Microsoft\Windows\WER"; 'CrashDumps' = "$L\CrashDumps"; 'Explorer thumbcache' = "$L\Microsoft\Windows\Explorer"
    'D3DSCache' = "$L\D3DSCache"; 'NVIDIA DXCache' = "$L\NVIDIA\DXCache"; 'NVIDIA GLCache' = "$L\NVIDIA\GLCache"
    'AMD DxCache' = "$L\AMD\DxCache"; 'AMD DxcCache' = "$L\AMD\DxcCache"; 'AMD VkCache' = "$L\AMD\VkCache"; 'Intel ShaderCache' = "$U\AppData\LocalLow\Intel\ShaderCache"
    'C:\NVIDIA' = "$sys\NVIDIA"; 'C:\AMD' = "$sys\AMD"; 'C:\Intel' = "$sys\Intel"; 'C:\SWSetup' = "$sys\SWSetup"; 'C:\Drivers' = "$sys\Drivers"
    'NVIDIA Downloader' = "$PD\NVIDIA Corporation\Downloader"
    'Zalo PC' = "$L\ZaloPC"; 'Telegram tdata' = "$R\Telegram Desktop\tdata"; 'Discord Cache' = "$R\discord\Cache"
    'Teams (new)' = "$L\Packages\MSTeams_8wekyb3d8bbwe\LocalCache"; 'Spotify Storage' = "$L\Spotify\Storage"
    'Adobe Media Cache' = "$R\Adobe\Common\Media Cache Files"; 'Adobe Peak Files' = "$R\Adobe\Common\Peak Files"; 'CapCut Cache' = "$L\CapCut\User Data\Cache"
    'Chrome Cache (Default)' = "$L\Google\Chrome\User Data\Default\Cache"; 'Edge Cache (Default)' = "$L\Microsoft\Edge\User Data\Default\Cache"
    'npm cache' = "$L\npm-cache"; 'pnpm store' = "$L\pnpm\store"; 'Yarn cache' = "$L\Yarn\Cache"; 'pip cache' = "$L\pip\Cache"; 'uv cache' = "$L\uv\cache"
    'NuGet packages' = "$U\.nuget\packages"; 'Gradle caches' = "$U\.gradle\caches"; 'Maven .m2' = "$U\.m2\repository"; 'Cargo registry' = "$U\.cargo\registry"; 'Go build cache' = "$L\go-build"
    'HuggingFace' = "$U\.cache\huggingface"; 'PyTorch' = "$U\.cache\torch"; 'Ollama models' = "$U\.ollama\models"; 'LM Studio models' = "$U\.lmstudio\models"
    'Docker Desktop VHDX' = "$L\Docker\wsl"; 'Android SDK' = "$L\Android\Sdk"; 'Android AVD' = "$U\.android\avd"
    'iPhone backup (CHI LIET KE)' = "$R\Apple Computer\MobileSync\Backup"
    'Captures (DU LIEU CA NHAN)' = (Join-Path ([Environment]::GetFolderPath('MyVideos')) 'Captures')
  }
  $categories=@{
    'cache'=@('User Temp','Windows Temp','WU Download','Delivery Optimization','WER (ProgramData)','CrashDumps','D3DSCache','NVIDIA DXCache','NVIDIA GLCache','AMD DxCache','AMD DxcCache','AMD VkCache','Intel ShaderCache','Discord Cache','Adobe Media Cache','Adobe Peak Files','CapCut Cache','Chrome Cache (Default)','Edge Cache (Default)','npm cache','Yarn cache','pip cache','uv cache','Go build cache')
    'app-data'=@('Zalo PC','Telegram tdata','Teams (new)','Spotify Storage','NuGet packages','Gradle caches','Maven .m2','Cargo registry','HuggingFace','PyTorch','Ollama models','LM Studio models','Android SDK','pnpm store')
    'vm'=@('Docker Desktop VHDX','Android AVD')
    'user-data'=@('iPhone backup (CHI LIET KE)','Captures (DU LIEU CA NHAN)')
    'system'=@('Windows.old','$Windows.~BT','$WinREAgent','CBS Logs','MEMORY.DMP','Minidump','LiveKernelReports','Explorer thumbcache','C:\NVIDIA','C:\AMD','C:\Intel','C:\SWSetup','C:\Drivers','NVIDIA Downloader')
  }
  $timer=[Diagnostics.Stopwatch]::StartNew();$data=New-Object 'System.Collections.Generic.List[object]';$errors=New-Object 'System.Collections.Generic.List[string]'
  foreach($entry in $radar.GetEnumerator()){
    if($timer.Elapsed.TotalSeconds -ge $Seconds){$errors.Add('Radar budget exhausted; remaining locations were not measured.');break}
    if(-not $entry.Value -or -not(Test-Path -LiteralPath $entry.Value)){continue}
    $category='unknown';foreach($key in $categories.Keys){if($entry.Key -in $categories[$key]){$category=$key;break}}
    try {
      $scan=Get-SyrinScan -Path $entry.Value -Seconds ([math]::Max(1,[math]::Min(10,$Seconds-$timer.Elapsed.TotalSeconds)))
      $data.Add([PSCustomObject]@{id=([regex]::Replace($entry.Key.ToLowerInvariant(),'[^a-z0-9]+','-').Trim('-'));label=$entry.Key;path=$scan.path;category=$category;measuredBytes=$scan.measuredBytes;cloudBytes=$scan.cloudBytes;estimatedReclaimableBytes=$null;status=$(if($scan.complete){'complete'}else{'partial'});errors=$scan.errors})
      foreach($errorText in $scan.errors){$errors.Add($errorText)}
    } catch {$errors.Add($_.Exception.Message)}
  }
  return [PSCustomObject]@{data=$data.ToArray();errors=$errors.ToArray()}
}

function Invoke-SyrinCollector {
  param([string]$Name,[int]$Seconds=40)
  $ErrorActionPreference='Stop';$data=@();$errors=@();$status='complete';$timer=[Diagnostics.Stopwatch]::StartNew()
  try {
    switch($Name){
      'system' {
        $os=Get-CimInstance Win32_OperatingSystem -OperationTimeoutSec 10 -ErrorAction Stop
        $computer=Get-CimInstance Win32_ComputerSystem -OperationTimeoutSec 10 -ErrorAction Stop
        $cpu=Get-CimInstance Win32_Processor -OperationTimeoutSec 10 -ErrorAction Stop | Select-Object -First 1
        $version=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        $machine=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid -ErrorAction Stop
        $build=[int]$os.BuildNumber
        $data=@([PSCustomObject]@{windows=$os.Caption;build=$build;edition=(Get-SyrinValue $version 'EditionID');displayVersion=(Get-SyrinValue $version 'DisplayVersion');architecture=$(switch($cpu.Architecture){9{'x64'}12{'ARM64'}default{'unknown'}});model=($computer.Manufacturer+' '+$computer.Model);ramBytes=(Get-SyrinValue $computer 'TotalPhysicalMemory');domainJoined=$computer.PartOfDomain;managementStatus=$(if($computer.PartOfDomain){'managed'}else{'unknown'});supportStatus='unknown';supportNote='Verify the lifecycle for the exact edition, channel and ESU enrollment.';systemDrive=$env:SystemDrive;machineId=(Get-SyrinDigest ([Text.Encoding]::UTF8.GetBytes([string]$machine.MachineGuid)))})
      }
      'volumes' {$data=@(Get-Volume -ErrorAction Stop | Where-Object {$_.DriveLetter -and $_.DriveType -eq 'Fixed'} | ForEach-Object {[PSCustomObject]@{drive=([string]$_.DriveLetter+':');volumeId=$_.UniqueId;filesystem=$_.FileSystem;sizeBytes=[long]$_.Size;freeBytes=[long]$_.SizeRemaining;isSystem=([string]$_.DriveLetter+':' -eq $env:SystemDrive)}})}
      'cpu' {$data=@(Get-CimInstance Win32_Processor -OperationTimeoutSec 10 -ErrorAction Stop | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed)}
      'gpu' {$data=@(Get-CimInstance Win32_VideoController -OperationTimeoutSec 10 -ErrorAction Stop | Select-Object Name,DriverVersion,DriverDate)}
      'ram' {$data=@(Get-CimInstance Win32_PhysicalMemory -OperationTimeoutSec 10 -ErrorAction Stop | Select-Object DeviceLocator,Capacity,ConfiguredClockSpeed,Speed)}
      'memory' {
        $m=Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory -OperationTimeoutSec 10 -ErrorAction Stop
        $data=@([PSCustomObject]@{availableBytes=(Get-SyrinValue $m 'AvailableBytes');committedBytes=(Get-SyrinValue $m 'CommittedBytes');commitLimitBytes=(Get-SyrinValue $m 'CommitLimit');commitPercent=(Get-SyrinValue $m 'PercentCommittedBytesInUse')})
      }
      'disks' {$data=@(Get-PhysicalDisk -ErrorAction Stop | Select-Object FriendlyName,MediaType,BusType,HealthStatus,Size)}
      'diskHealth' {$data=@(Get-PhysicalDisk -ErrorAction Stop | Get-StorageReliabilityCounter -ErrorAction Stop | Select-Object DeviceId,Temperature,Wear,ReadErrorsTotal,WriteErrorsTotal,PowerOnHours)}
      'startup' {$result=Get-SyrinStartup;$data=@($result.data);$errors=@($result.errors)}
      'processes' {$data=@(Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -OperationTimeoutSec 10 -ErrorAction Stop | Where-Object {$_.Name -notin @('_Total','Idle')} | Sort-Object PercentProcessorTime -Descending | Select-Object -First 10 Name,IDProcess,PercentProcessorTime,PrivateBytes,IODataBytesPersec)}
      'tasks' {
        $tasks=@(Get-ScheduledTask -ErrorAction Stop | Where-Object {$_.TaskPath -notlike '\Microsoft\*' -and @($_.Triggers | Where-Object {$_.CimClass.CimClassName -match '(Logon|Boot)Trigger$'}).Count})
        $data=@($tasks | Select-Object -First 100 TaskPath,TaskName,State)
        if($tasks.Count -gt 100){$errors=@('Startup task results were limited to 100 entries.')}
      }
      'services' {$data=@(Get-CimInstance Win32_Service -Filter "StartMode='Auto'" -OperationTimeoutSec 10 -ErrorAction Stop | Select-Object Name,DisplayName,State,StartMode)}
      'power' {$lines=@(& powercfg.exe /getactivescheme);if($LASTEXITCODE -ne 0){throw 'Power plan query failed.'};$data=@([PSCustomObject]@{activePlan=($lines -join ' ')})}
      'battery' {$data=@(Get-CimInstance Win32_Battery -OperationTimeoutSec 10 -ErrorAction Stop | Select-Object Name,BatteryStatus,EstimatedChargeRemaining)}
      'largeFiles' {
        $roots=@([Environment]::GetFolderPath('Desktop'),[Environment]::GetFolderPath('MyDocuments'),[Environment]::GetFolderPath('MyVideos')) | Select-Object -Unique
        $data=New-Object 'System.Collections.Generic.List[object]';$issues=New-Object 'System.Collections.Generic.List[string]'
        foreach($rootPath in $roots){if(-not $rootPath -or -not(Test-Path -LiteralPath $rootPath)){continue};$scan=Get-SyrinScan -Path $rootPath -LargeFiles -Seconds ([math]::Max(1,[int]($Seconds/$roots.Count)));foreach($file in $scan.largeFiles){$data.Add($file)};foreach($errorText in $scan.errors){$issues.Add($errorText)}}
        $data=@($data | Sort-Object measuredBytes -Descending | Select-Object -First 20);$errors=$issues.ToArray()
      }
      'events' {
        try{$events=@(Get-WinEvent -FilterHashtable @{LogName='System','Application';Level=1,2;StartTime=(Get-Date).AddDays(-7)} -MaxEvents 5000 -ErrorAction Stop)}
        catch{if($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*'){$events=@()}else{throw}}
        $groups=@($events | Group-Object ProviderName,Id | Sort-Object Count -Descending)
        $data=@($groups | Select-Object -First 20 | ForEach-Object {[PSCustomObject]@{source=$_.Name;count=$_.Count}})
        if($events.Count -ge 5000 -or $groups.Count -gt 20){$errors=@('Event results were limited; totals are a lower bound.')}
      }
      'security' {$d=Get-MpComputerStatus -ErrorAction Stop;$data=@([PSCustomObject]@{realTimeProtection=$d.RealTimeProtectionEnabled;signatureAgeDays=$d.AntivirusSignatureAge;mode=$d.AMRunningMode})}
      'restorePoints' {$data=@(Get-ComputerRestorePoint -ErrorAction Stop | Select-Object -Last 3 SequenceNumber,Description,CreationTime)}
      'apps' {$data=@(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction Stop | Where-Object {$_.PSObject.Properties['DisplayName'] -and $_.PSObject.Properties['EstimatedSize']} | Sort-Object EstimatedSize -Descending | Select-Object -First 25 DisplayName,DisplayVersion,Publisher,EstimatedSize)}
      'radar' {$result=Get-SyrinRadar -Seconds $Seconds;$data=@($result.data);$errors=@($result.errors)}
      default {throw 'Unknown read-only collector.'}
    }
    if($errors.Count){$status='partial'}
  } catch {$errors=@($_.Exception.Message);$status=$(if($data.Count){'partial'}else{'failed'})}
  return [PSCustomObject]@{status=$status;data=@($data);errors=@($errors);durationMs=$timer.ElapsedMilliseconds}
}

function Invoke-SyrinCollectorJob([string]$Name,[int]$Seconds) {
  $job=$null
  try {
    $job=Start-Job -ScriptBlock {param($ModulePath,$Collector,$Budget) $env:PSModulePath=Join-Path $PSHOME 'Modules';Import-Module $ModulePath -Force;Invoke-SyrinCollector -Name $Collector -Seconds ([math]::Max(1,$Budget-2))} -ArgumentList @((Join-Path $PSScriptRoot 'Audit.psm1'),$Name,$Seconds)
    if(-not(Wait-Job -Job $job -Timeout $Seconds)) {Stop-Job $job;return [PSCustomObject]@{status='unavailable';data=@();errors=@('Collector timed out.');durationMs=($Seconds*1000)}}
    $result=Receive-Job -Job $job -ErrorAction Stop
    if(-not $result -or -not $result.PSObject.Properties['status']){throw 'Collector returned no structured result.'}
    return [PSCustomObject]@{status=$result.status;data=@($result.data);errors=@($result.errors);durationMs=$result.durationMs}
  } catch {return [PSCustomObject]@{status='failed';data=@();errors=@($_.Exception.Message);durationMs=0}}
  finally {if($job){Remove-Job -Job $job -Force -ErrorAction SilentlyContinue}}
}

function Invoke-SyrinAudit {
  param([string]$OutDir='',[ValidateSet('3d','simple','none')][string]$ReportMode='3d',[ValidateSet('full','health','speed','cleanup')][string]$Scope='full',[int]$MaxSeconds=180)
  $ReportMode=$ReportMode.ToLowerInvariant();$Scope=$Scope.ToLowerInvariant()
  if(-not $OutDir){$OutDir=Join-Path (Join-Path $env:LOCALAPPDATA 'SyrinClean\Sessions') ([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))}
  $full=Assert-SyrinLocalPath $OutDir
  foreach($cloud in @(Get-SyrinCloudRoots)){if((Test-SyrinWithin $full $cloud) -or (Test-SyrinWithin $cloud $full)){throw 'Choose a working directory outside cloud sync roots.'}}
  $markerPath=Join-Path $full 'session.json'
  if(Test-Path -LiteralPath $markerPath){$session=Read-SyrinJson $markerPath;if($session.kind -ne 'syrin-audit-session' -or $session.schemaVersion -ne 1 -or $session.ownerSid -ne (Get-SyrinOwner)){throw 'Working directory belongs to another session format or owner.'}}
  else {
    if((Test-Path -LiteralPath $full) -and @(Get-ChildItem -LiteralPath $full -Force).Count){throw 'Choose an empty working directory for a new audit.'}
    [void][IO.Directory]::CreateDirectory($full)
    $session=[PSCustomObject]@{schemaVersion=1;kind='syrin-audit-session';sessionId=[guid]::NewGuid().ToString('N');ownerSid=(Get-SyrinOwner);createdUtc=[DateTime]::UtcNow.ToString('o')}
    Write-SyrinAtomicJson $markerPath $session -CreateOnly
  }
  $timer=[Diagnostics.Stopwatch]::StartNew();$collectors=[ordered]@{}
  foreach($name in @('system','volumes','memory','startup','events','security','cpu','gpu','ram','disks','diskHealth','power','battery','restorePoints','processes','tasks','services','apps','radar','largeFiles')){
    $remaining=[int]($MaxSeconds-$timer.Elapsed.TotalSeconds)
    if($remaining -le 0 -or ($name -in @('radar','largeFiles') -and $Scope -in @('health','speed'))){$collectors[$name]=[PSCustomObject]@{status='unavailable';data=@();errors=@('Not requested or total audit budget exhausted.');durationMs=0};continue}
    $budget=[math]::Min($remaining,$(if($name -in @('radar','largeFiles')){45}else{20}))
    $collectors[$name]=Invoke-SyrinCollectorJob $name $budget
  }
  $system=@($collectors.system.data) | Select-Object -First 1
  $audit=[ordered]@{schemaVersion=1;kind='syrin-audit';meta=[ordered]@{sessionId=$session.sessionId;generatedUtc=[DateTime]::UtcNow.ToString('o');machineId=(Get-SyrinValue $system 'machineId');systemDrive=(Get-SyrinValue $system 'systemDrive');reportMode=$ReportMode;scope=$Scope;warnings=@();warningCodes=@('agent-privacy','support-unverified')};collectors=$collectors}
  Write-SyrinAtomicJson (Join-Path $full 'audit.json') $audit
  Write-SyrinAtomicJson (Join-Path $full 'state.json') ([ordered]@{schemaVersion=1;kind='syrin-state';sessionId=$session.sessionId;phase='audited';updatedUtc=[DateTime]::UtcNow.ToString('o');approvedItemIds=@();completed=@();failed=@()})
  return [PSCustomObject]@{ok=$true;outDir=$full;sessionId=$session.sessionId;incomplete=@($collectors.Keys | Where-Object {$collectors[$_].status -ne 'complete'});reportMode=$ReportMode}
}

Export-ModuleMember -Function Get-SyrinValue,Get-SyrinScan,Get-SyrinStartup,Invoke-SyrinCollector,Invoke-SyrinAudit
