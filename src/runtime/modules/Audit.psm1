Set-StrictMode -Version 2
Import-Module (Join-Path $PSScriptRoot 'IO.psm1')

function Get-SyrinValue($Object,[string]$Name,$Default=$null) {
  if ($null -eq $Object) { return $Default }
  $property=$Object.PSObject.Properties[$Name]
  if (-not $property -or $null -eq $property.Value) { return $Default }
  return $property.Value
}

function Get-SyrinScan {
  param([string]$Path,[int]$Seconds=30,[switch]$LargeFiles,[string[]]$ExcludeNames=@())
  $full=Get-SyrinPath $Path
  [void](Assert-SyrinLocalPath ([IO.Path]::GetDirectoryName($full)))
  $timer=[Diagnostics.Stopwatch]::StartNew();$bytes=0L;$cloud=0L;$count=0;$complete=$true;$latest=[DateTime]::MinValue
  $errors=New-Object 'System.Collections.Generic.List[string]';$large=New-Object 'System.Collections.Generic.List[object]'
  $excluded=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach($item in $ExcludeNames){if($item){[void]$excluded.Add($item)}}
  try {
    $rootEntry=Get-Item -LiteralPath $full -Force -ErrorAction Stop
    $stack=New-Object 'System.Collections.Generic.Stack[IO.FileSystemInfo]'
    $stack.Push($rootEntry)
    while($stack.Count){
      if($timer.Elapsed.TotalSeconds -ge $Seconds){$complete=$false;$errors.Add('Scan budget exhausted.');break}
      $entry=$stack.Pop()
      try {
        $flags=[int]$entry.Attributes
        if(($flags -band 0x400) -ne 0){$complete=$false;$errors.Add("Reparse point skipped: $($entry.FullName)");continue}
        if($entry -is [IO.DirectoryInfo]){
          if(($flags -band 0x441000) -ne 0){$complete=$false;$errors.Add("Cloud directory not enumerated: $($entry.FullName)");continue}
          foreach($child in $entry.EnumerateFileSystemInfos()){
            if($timer.Elapsed.TotalSeconds -ge $Seconds){$complete=$false;$errors.Add('Scan budget exhausted.');break}
            if($excluded.Contains($child.Name)){continue}
            if($LargeFiles -and $child.Name -match '^(\.git|\.ssh|\.aws|\.azure|\.gnupg|\.kube|AppData|node_modules|\.venv|target)$'){continue}
            $stack.Push($child)
          }
        } else {
          $count++
          if($entry.LastWriteTimeUtc -gt $latest){$latest=$entry.LastWriteTimeUtc}
          if(($flags -band 0x441000) -ne 0){$cloud+=$entry.Length;continue}
          $bytes+=$entry.Length
          if($LargeFiles -and $entry.Length -ge 300MB){$large.Add([PSCustomObject]@{path=$entry.FullName;measuredBytes=[long]$entry.Length;lastWriteUtc=$entry.LastWriteTimeUtc.ToString('o');category='user-data'})}
        }
      } catch {$complete=$false;$errors.Add($_.Exception.Message)}
    }
  } catch {$complete=$false;$errors.Add($_.Exception.Message)}
  $latestIso=if($latest -gt [DateTime]::MinValue){$latest.ToString('o')}else{$null}
  return [PSCustomObject]@{path=$full;measuredBytes=$bytes;cloudBytes=$cloud;files=$count;latestWriteUtc=$latestIso;complete=$complete;errors=$errors.ToArray();largeFiles=@($large | Sort-Object measuredBytes -Descending | Select-Object -First 20)}
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

function Get-SyrinBrowserCacheTargets([string]$UserDataRoot) {
  $targets=New-Object 'System.Collections.Generic.List[string]'
  if(-not $UserDataRoot -or -not (Test-Path -LiteralPath $UserDataRoot)){return @()}
  foreach($sub in @('ShaderCache','GrShaderCache','GraphiteDawnCache')){
    $candidate=Join-Path $UserDataRoot $sub
    if(Test-Path -LiteralPath $candidate){$targets.Add($candidate)}
  }
  foreach($profileDir in @(Get-ChildItem -LiteralPath $UserDataRoot -Directory -Force -ErrorAction SilentlyContinue | Where-Object {$_.Name -eq 'Default' -or $_.Name -like 'Profile *' -or $_.Name -eq 'System Profile'})){
    foreach($cacheRel in @('Cache','Code Cache','GPUCache','Service Worker\CacheStorage')){
      $candidate=Join-Path $profileDir.FullName $cacheRel
      if(Test-Path -LiteralPath $candidate){$targets.Add($candidate)}
    }
  }
  return $targets.ToArray()
}

function Invoke-SyrinMultiPathScan([string[]]$Paths,[int]$Seconds,[string[]]$ExcludeNames=@()) {
  $timer=[Diagnostics.Stopwatch]::StartNew();$bytes=0L;$cloud=0L;$complete=$true
  $errors=New-Object 'System.Collections.Generic.List[string]'
  foreach($target in $Paths){
    $remaining=[math]::Max(1,[int]($Seconds-$timer.Elapsed.TotalSeconds))
    if($timer.Elapsed.TotalSeconds -ge $Seconds){$complete=$false;$errors.Add('Scan budget exhausted.');break}
    if(-not $target -or -not (Test-Path -LiteralPath $target)){continue}
    $scan=Get-SyrinScan -Path $target -Seconds $remaining -ExcludeNames $ExcludeNames
    $bytes+=$scan.measuredBytes;$cloud+=$scan.cloudBytes
    if(-not $scan.complete){$complete=$false}
    foreach($err in $scan.errors){$errors.Add($err)}
  }
  return [PSCustomObject]@{measuredBytes=$bytes;cloudBytes=$cloud;complete=$complete;errors=$errors.ToArray()}
}

function Get-SyrinRadar {
  param([int]$Seconds=40)
  $sys=$env:SystemDrive;$L=$env:LOCALAPPDATA;$R=$env:APPDATA;$U=(Get-SyrinUserFolder 'UserProfile');$W=$env:windir;$PD=$env:ProgramData
  $ownerSid=Get-SyrinOwner
  $quarantineSessions=Join-Path $L 'SyrinClean\Quarantine\sessions'
  $storedFilesPaths=@();$journalPaths=@()
  if(Test-Path -LiteralPath $quarantineSessions){
    foreach($sdir in @(Get-ChildItem -LiteralPath $quarantineSessions -Directory -Force -ErrorAction SilentlyContinue)){
      $fPath=Join-Path $sdir.FullName 'files';if(Test-Path -LiteralPath $fPath){$storedFilesPaths+=$fPath}
      foreach($jName in @('events','approvals','plan.json','session.json')){$jp=Join-Path $sdir.FullName $jName;if(Test-Path -LiteralPath $jp){$journalPaths+=$jp}}
    }
  }
  $updaterDirs=@()
  if($L -and (Test-Path -LiteralPath $L)){
    $updaterDirs=@(Get-ChildItem -LiteralPath $L -Directory -Force -ErrorAction SilentlyContinue | Where-Object {$_.Name -like '*-updater'} | ForEach-Object {$_.FullName})
  }
  $radar = [ordered]@{
    'User Temp' = $env:TEMP; 'Windows Temp' = "$W\Temp"; 'Recycle Bin (Current User)' = "$sys\`$Recycle.Bin\$ownerSid"
    'WU Download' = "$W\SoftwareDistribution\Download"; 'Delivery Optimization' = "$W\SoftwareDistribution\DeliveryOptimization"
    'Windows.old' = "$sys\Windows.old"; '$Windows.~BT' = "$sys\`$Windows.~BT"; '$WinREAgent' = "$sys\`$WinREAgent"
    'CBS Logs' = "$W\Logs\CBS"; 'MEMORY.DMP' = "$W\MEMORY.DMP"; 'Minidump' = "$W\Minidump"; 'LiveKernelReports' = "$W\LiveKernelReports"
    'WER (ProgramData)' = "$PD\Microsoft\Windows\WER"; 'CrashDumps' = "$L\CrashDumps"; 'Explorer thumbcache' = "$L\Microsoft\Windows\Explorer"
    'D3DSCache' = "$L\D3DSCache"; 'NVIDIA DXCache' = "$L\NVIDIA\DXCache"; 'NVIDIA GLCache' = "$L\NVIDIA\GLCache"
    'AMD DxCache' = "$L\AMD\DxCache"; 'AMD DxcCache' = "$L\AMD\DxcCache"; 'AMD VkCache' = "$L\AMD\VkCache"; 'Intel ShaderCache' = "$U\AppData\LocalLow\Intel\ShaderCache"
    'C:\NVIDIA' = "$sys\NVIDIA"; 'C:\AMD' = "$sys\AMD"; 'C:\Intel' = "$sys\Intel"; 'C:\SWSetup' = "$sys\SWSetup"; 'C:\Drivers' = "$sys\Drivers"
    'NVIDIA Downloader' = "$PD\NVIDIA Corporation\Downloader"; 'NVIDIA UpdateFramework' = "$PD\NVIDIA Corporation\NVIDIA app\UpdateFramework"
    'Electron App Updaters' = @{displayPath="$L\*-updater";paths=$updaterDirs}
    'Chrome Cache (All Profiles)' = @{displayPath="$L\Google\Chrome\User Data";paths=(Get-SyrinBrowserCacheTargets "$L\Google\Chrome\User Data")}
    'Edge Cache (All Profiles)' = @{displayPath="$L\Microsoft\Edge\User Data";paths=(Get-SyrinBrowserCacheTargets "$L\Microsoft\Edge\User Data")}
    'Brave Cache (All Profiles)' = @{displayPath="$L\BraveSoftware\Brave-Browser\User Data";paths=(Get-SyrinBrowserCacheTargets "$L\BraveSoftware\Brave-Browser\User Data")}
    'CocCoc Cache (All Profiles)' = @{displayPath="$L\CocCoc\Browser\User Data";paths=(Get-SyrinBrowserCacheTargets "$L\CocCoc\Browser\User Data")}
    'Zalo PC (Local)' = "$L\ZaloPC"; 'Zalo Data (Roaming)' = "$R\ZaloData"; 'Telegram tdata' = "$R\Telegram Desktop\tdata"; 'Discord Cache' = "$R\discord\Cache"
    'Teams (new)' = "$L\Packages\MSTeams_8wekyb3d8bbwe\LocalCache"; 'Spotify Storage' = "$L\Spotify\Storage"
    'Adobe Media Cache' = "$R\Adobe\Common\Media Cache Files"; 'Adobe Peak Files' = "$R\Adobe\Common\Peak Files"; 'CapCut Cache' = "$L\CapCut\User Data\Cache"
    'npm cache' = "$L\npm-cache"; 'pnpm store' = "$L\pnpm\store"; 'Yarn cache' = "$L\Yarn\Cache"; 'bun cache' = "$U\.bun\install\cache"; 'pip cache' = "$L\pip\Cache"; 'uv cache' = "$L\uv\cache"
    'Playwright browsers' = "$L\ms-playwright"; 'NuGet packages' = "$U\.nuget\packages"; 'Gradle caches' = "$U\.gradle\caches"; 'Maven .m2' = "$U\.m2\repository"; 'Cargo registry' = "$U\.cargo\registry"; 'Go build cache' = "$L\go-build"
    'HuggingFace' = "$U\.cache\huggingface"; 'PyTorch' = "$U\.cache\torch"; 'Ollama models' = "$U\.ollama\models"; 'LM Studio models' = "$U\.lmstudio\models"
    'Docker Desktop VHDX' = "$L\Docker\wsl"; 'WSL2 Distributions' = "$L\wsl"; 'Android SDK' = "$L\Android\Sdk"; 'Android AVD' = "$U\.android\avd"
    'Syrin Quarantine (Stored Files)' = @{displayPath="$L\SyrinClean\Quarantine\sessions\*\files";paths=$storedFilesPaths}
    'Syrin Quarantine (Journals)' = @{displayPath="$L\SyrinClean\Quarantine\sessions";paths=$journalPaths}
    'System Hibernate and Pagefile' = @{displayPath="$sys\hiberfil.sys, pagefile.sys, swapfile.sys";systemFiles=@("$sys\hiberfil.sys","$sys\pagefile.sys","$sys\swapfile.sys")}
    'iPhone backup (Apple Computer)' = "$R\Apple Computer\MobileSync\Backup"; 'iPhone backup (Microsoft Store)' = "$U\Apple\MobileSync\Backup"
    'Video Captures' = (Join-Path (Get-SyrinUserFolder 'MyVideos') 'Captures')
  }
  $categories=@{
    'cache'=@('User Temp','Windows Temp','Recycle Bin (Current User)','WU Download','Delivery Optimization','WER (ProgramData)','CrashDumps','D3DSCache','NVIDIA DXCache','NVIDIA GLCache','NVIDIA UpdateFramework','Electron App Updaters','AMD DxCache','AMD DxcCache','AMD VkCache','Intel ShaderCache','Discord Cache','Adobe Media Cache','Adobe Peak Files','CapCut Cache','Chrome Cache (All Profiles)','Edge Cache (All Profiles)','Brave Cache (All Profiles)','CocCoc Cache (All Profiles)','npm cache','Yarn cache','bun cache','pip cache','uv cache','Go build cache')
    'app-data'=@('Zalo PC (Local)','Zalo Data (Roaming)','Telegram tdata','Teams (new)','Spotify Storage','Playwright browsers','NuGet packages','Gradle caches','Maven .m2','Cargo registry','HuggingFace','PyTorch','Ollama models','LM Studio models','Android SDK','pnpm store','Syrin Quarantine (Stored Files)')
    'vm'=@('Docker Desktop VHDX','WSL2 Distributions','Android AVD')
    'user-data'=@('iPhone backup (Apple Computer)','iPhone backup (Microsoft Store)','Video Captures')
    'system'=@('Windows.old','$Windows.~BT','$WinREAgent','CBS Logs','MEMORY.DMP','Minidump','LiveKernelReports','Explorer thumbcache','C:\NVIDIA','C:\AMD','C:\Intel','C:\SWSetup','C:\Drivers','NVIDIA Downloader','Syrin Quarantine (Journals)','System Hibernate and Pagefile')
  }
  $timer=[Diagnostics.Stopwatch]::StartNew();$data=New-Object 'System.Collections.Generic.List[object]';$errors=New-Object 'System.Collections.Generic.List[string]'
  foreach($entry in $radar.GetEnumerator()){
    if($timer.Elapsed.TotalSeconds -ge $Seconds){$errors.Add('Radar budget exhausted; remaining locations were not measured.');break}
    $category='unknown';foreach($key in $categories.Keys){if($entry.Key -in $categories[$key]){$category=$key;break}}
    $rowId=([regex]::Replace($entry.Key.ToLowerInvariant(),'[^a-z0-9]+','-').Trim('-'))
    $locationBudget=[math]::Max(8,[int]($Seconds/4))
    $budget=[math]::Max(1,[math]::Min($locationBudget,[int]($Seconds-$timer.Elapsed.TotalSeconds)))
    try {
      if($entry.Value -is [hashtable]){
        if($entry.Value.ContainsKey('systemFiles')){
          $sum=0L;$found=$false
          foreach($sf in $entry.Value.systemFiles){
            try{$fi=New-Object IO.FileInfo $sf;if($fi.Exists){$found=$true;$sum+=[long]$fi.Length}}catch{}
          }
          if(-not $found){continue}
          $data.Add([PSCustomObject]@{id=$rowId;label=$entry.Key;path=$entry.Value.displayPath;category=$category;measuredBytes=$sum;cloudBytes=0L;estimatedReclaimableBytes=$null;status='complete';errors=@()})
        } else {
          $targets=@($entry.Value.paths)
          if(-not $targets.Count){continue}
          $multi=Invoke-SyrinMultiPathScan -Paths $targets -Seconds $budget
          $data.Add([PSCustomObject]@{id=$rowId;label=$entry.Key;path=$entry.Value.displayPath;category=$category;measuredBytes=$multi.measuredBytes;cloudBytes=$multi.cloudBytes;estimatedReclaimableBytes=$null;status=$(if($multi.complete){'complete'}else{'partial'});errors=$multi.errors})
          foreach($errorText in $multi.errors){$errors.Add($errorText)}
        }
        continue
      }
      if(-not $entry.Value -or -not(Test-Path -LiteralPath $entry.Value)){continue}
      $scan=Get-SyrinScan -Path $entry.Value -Seconds $budget
      $data.Add([PSCustomObject]@{id=$rowId;label=$entry.Key;path=$scan.path;category=$category;measuredBytes=$scan.measuredBytes;cloudBytes=$scan.cloudBytes;estimatedReclaimableBytes=$null;status=$(if($scan.complete){'complete'}else{'partial'});errors=$scan.errors})
      foreach($errorText in $scan.errors){$errors.Add($errorText)}
    } catch {$errors.Add($_.Exception.Message)}
  }
  return [PSCustomObject]@{data=$data.ToArray();errors=$errors.ToArray()}
}

function Get-SyrinHotspots {
  param([int]$Seconds=25,[long]$MinimumBytes=524288000)
  $timer=[Diagnostics.Stopwatch]::StartNew();$rows=New-Object 'System.Collections.Generic.List[object]';$errors=New-Object 'System.Collections.Generic.List[string]'
  $U=Get-SyrinUserFolder 'UserProfile';$L=$env:LOCALAPPDATA;$R=$env:APPDATA
  $skipProfile=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach($known in @('AppData','Desktop','Documents','My Documents','Downloads','Videos','Pictures','Music','OneDrive','Dropbox','Google Drive','GoogleDrive','iCloudDrive','iCloud Drive','.ssh','.gnupg','.aws','.azure','.kube','.docker','.nuget','.gradle','.m2','.cargo','.cache','.ollama','.lmstudio','.android','.bun','.syrin-clean-installer')){[void]$skipProfile.Add($known)}
  $skipLocal=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach($known in @('Temp','CrashDumps','D3DSCache','NVIDIA','AMD','Google','Microsoft','BraveSoftware','CocCoc','ZaloPC','Packages','Spotify','CapCut','npm-cache','pnpm','Yarn','pip','uv','ms-playwright','go-build','Docker','wsl','Android','SyrinClean')){[void]$skipLocal.Add($known)}
  $skipRoaming=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach($known in @('ZaloData','Telegram Desktop','discord','Adobe','Apple Computer','Microsoft')){[void]$skipRoaming.Add($known)}
  $clouds=@(Get-SyrinCloudRoots)
  $roots=@(
    @{label='LocalAppData';path=$L;skip=$skipLocal},
    @{label='RoamingAppData';path=$R;skip=$skipRoaming},
    @{label='UserProfile';path=$U;skip=$skipProfile}
  )
  foreach($scopeRoot in $roots){
    if($timer.Elapsed.TotalSeconds -ge $Seconds){$errors.Add('Hotspot scan budget exhausted.');break}
    if(-not $scopeRoot.path -or -not (Test-Path -LiteralPath $scopeRoot.path)){continue}
    foreach($dir in @(Get-ChildItem -LiteralPath $scopeRoot.path -Directory -Force -ErrorAction SilentlyContinue)){
      if($timer.Elapsed.TotalSeconds -ge $Seconds){$errors.Add('Hotspot scan budget exhausted.');break}
      if($scopeRoot.skip.Contains($dir.Name) -or $dir.Name -like '*-updater'){continue}
      if((([int]$dir.Attributes) -band 0x441400) -ne 0){continue}
      $inCloud=$false;foreach($c in $clouds){if((Test-SyrinWithin $dir.FullName $c) -or (Test-SyrinWithin $c $dir.FullName)){$inCloud=$true;break}}
      if($inCloud){continue}
      $perDir=[math]::Max(1,[math]::Min(4,[int]($Seconds-$timer.Elapsed.TotalSeconds)))
      $scan=Get-SyrinScan -Path $dir.FullName -Seconds $perDir
      if($scan.measuredBytes -ge $MinimumBytes){
        $rows.Add([PSCustomObject]@{path=$scan.path;label=$dir.Name;location=$scopeRoot.label;category='unknown';measuredBytes=$scan.measuredBytes;files=$scan.files;rootLastWriteUtc=$dir.LastWriteTimeUtc.ToString('o');latestContentWriteUtc=$scan.latestWriteUtc;status=$(if($scan.complete){'complete'}else{'partial'})})
      }
    }
  }
  return [PSCustomObject]@{data=@($rows | Sort-Object measuredBytes -Descending | Select-Object -First 15);errors=$errors.ToArray()}
}

function Get-SyrinDevArtifacts {
  param([int]$Seconds=25,[int]$MaxDepth=4)
  $timer=[Diagnostics.Stopwatch]::StartNew();$rows=New-Object 'System.Collections.Generic.List[object]';$errors=New-Object 'System.Collections.Generic.List[string]'
  $U=Get-SyrinUserFolder 'UserProfile'
  $realProfile=[Environment]::GetFolderPath('UserProfile')
  $isolated=$realProfile -and -not $U.TrimEnd('\').Equals($realProfile.TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)
  $searchRoots=New-Object 'System.Collections.Generic.List[string]'
  if($U -and (Test-Path -LiteralPath $U)){$searchRoots.Add($U)}
  if(-not $isolated -and $env:SystemDrive){
    foreach($devDir in @('AI','Projects','Repos','src','dev','work','workspace','code')){
      $candidate=Join-Path ($env:SystemDrive+'\') $devDir
      if(Test-Path -LiteralPath $candidate){$searchRoots.Add($candidate)}
    }
  }
  $clouds=@(Get-SyrinCloudRoots)
  $skipNames=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach($n in @('AppData','Application Data','Local Settings','Cookies','Windows','Program Files','Program Files (x86)','ProgramData','$Recycle.Bin','.git','.ssh','.gnupg','.aws','.azure','.kube','.docker','.nuget','.cargo','.gradle','.m2','.cache','.bun','.ollama','.lmstudio','.syrin-clean-installer')){[void]$skipNames.Add($n)}
  $queue=New-Object 'System.Collections.Generic.Queue[object]'
  $visited=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach($rootPath in $searchRoots){
    $canonical=Get-SyrinPath $rootPath
    if($visited.Add($canonical)){$queue.Enqueue([PSCustomObject]@{path=$canonical;depth=0})}
  }
  while($queue.Count -gt 0){
    if($timer.Elapsed.TotalSeconds -ge $Seconds){$errors.Add('Developer artifact scan budget exhausted.');break}
    $node=$queue.Dequeue()
    try {
      $dirInfo=New-Object IO.DirectoryInfo $node.path
      if(-not $dirInfo.Exists -or (([int]$dirInfo.Attributes) -band 0x441400) -ne 0){continue}
      foreach($child in $dirInfo.EnumerateDirectories()){
        if($timer.Elapsed.TotalSeconds -ge $Seconds){$errors.Add('Developer artifact scan budget exhausted.');break}
        if((([int]$child.Attributes) -band 0x441400) -ne 0){continue}
        if($skipNames.Contains($child.Name)){continue}
        $inCloud=$false;foreach($c in $clouds){if((Test-SyrinWithin $child.FullName $c) -or (Test-SyrinWithin $c $child.FullName)){$inCloud=$true;break}}
        if($inCloud){continue}
        $artifactType=$null
        if($child.Name -ieq 'node_modules' -and [IO.File]::Exists((Join-Path $dirInfo.FullName 'package.json'))){$artifactType='node_modules'}
        elseif($child.Name -ieq 'target' -and [IO.File]::Exists((Join-Path $dirInfo.FullName 'Cargo.toml'))){$artifactType='rust-target'}
        elseif($child.Name -in @('.venv','venv') -and [IO.File]::Exists((Join-Path $child.FullName 'pyvenv.cfg'))){$artifactType='python-venv'}
        if($artifactType){
          $perArtifact=[math]::Max(1,[math]::Min(5,[int]($Seconds-$timer.Elapsed.TotalSeconds)))
          $scan=Get-SyrinScan -Path $child.FullName -Seconds $perArtifact
          $projectLatest=$dirInfo.LastWriteTimeUtc
          foreach($sibling in $dirInfo.EnumerateFileSystemInfos()){
            if($sibling.Name -in @('node_modules','target','.venv','venv','.git')){continue}
            if($sibling.LastWriteTimeUtc -gt $projectLatest){$projectLatest=$sibling.LastWriteTimeUtc}
          }
          $staleDays=[math]::Max(0,[int]([DateTime]::UtcNow - $projectLatest).TotalDays)
          $rows.Add([PSCustomObject]@{path=$scan.path;projectRoot=$dirInfo.FullName;artifactType=$artifactType;measuredBytes=$scan.measuredBytes;files=$scan.files;projectLastWriteUtc=$projectLatest.ToString('o');staleDays=$staleDays;status=$(if($scan.complete){'complete'}else{'partial'})})
          continue
        }
        if($node.depth + 1 -le $MaxDepth -and $visited.Add($child.FullName)){
          $queue.Enqueue([PSCustomObject]@{path=$child.FullName;depth=($node.depth+1)})
        }
      }
    } catch {$errors.Add($_.Exception.Message)}
  }
  return [PSCustomObject]@{data=@($rows | Sort-Object measuredBytes -Descending | Select-Object -First 25);errors=$errors.ToArray()}
}

function Get-SyrinShallowLatestUtc([string]$DirectoryPath) {
  if(-not $DirectoryPath -or -not (Test-Path -LiteralPath $DirectoryPath)){return $null}
  try {
    $dir=New-Object IO.DirectoryInfo $DirectoryPath
    if(-not $dir.Exists -or (([int]$dir.Attributes) -band 0x441400) -ne 0){return $null}
    $latest=$dir.LastWriteTimeUtc
    foreach($entry in ($dir.EnumerateFileSystemInfos() | Select-Object -First 64)){
      if($entry.LastWriteTimeUtc -gt $latest){$latest=$entry.LastWriteTimeUtc}
      if($entry -is [IO.DirectoryInfo] -and (([int]$entry.Attributes) -band 0x441400) -eq 0){
        foreach($sub in ($entry.EnumerateFileSystemInfos() | Select-Object -First 32)){
          if($sub.LastWriteTimeUtc -gt $latest){$latest=$sub.LastWriteTimeUtc}
        }
      }
    }
    return $latest.ToString('o')
  } catch {return $null}
}

function Invoke-SyrinCollector {
  param([string]$Name,[int]$Seconds=40,[string]$ContextLabel='')
  $ErrorActionPreference='Stop';$data=@();$errors=@();$status='complete';$timer=[Diagnostics.Stopwatch]::StartNew()
  try {
    switch($Name){
      'performance' {
        Import-Module (Join-Path $PSScriptRoot 'Performance.psm1')
        $measurement=Invoke-SyrinPerformance -Seconds ([math]::Min(60,[math]::Max(2,$Seconds-3))) -ContextLabel $ContextLabel
        $data=@($measurement)
        if($measurement.sampleCount -lt 2 -or $null -eq $measurement.meanCpuPercent){$errors=@('Too few comparable performance samples.')}
      }
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
        $roots=@((Get-SyrinUserFolder 'Desktop'),(Get-SyrinUserFolder 'MyDocuments'),(Get-SyrinUserFolder 'MyVideos'),(Get-SyrinUserFolder 'Downloads')) | Select-Object -Unique
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
      'apps' {
        $rawApps=@(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction Stop | Where-Object {$_.PSObject.Properties['DisplayName'] -and [string]$_.DisplayName -ne ''})
        $sized=@($rawApps | ForEach-Object {
          $est=Get-SyrinValue $_ 'EstimatedSize'
          $installLoc=Get-SyrinValue $_ 'InstallLocation'
          [PSCustomObject]@{
            DisplayName=[string]$_.DisplayName
            DisplayVersion=(Get-SyrinValue $_ 'DisplayVersion')
            Publisher=(Get-SyrinValue $_ 'Publisher')
            EstimatedSize=$(if($null -ne $est){[long]$est}else{$null})
            InstallDate=(Get-SyrinValue $_ 'InstallDate')
            hasQuietUninstall=[bool](Get-SyrinValue $_ 'QuietUninstallString')
            latestActivityUtc=$(if($installLoc){Get-SyrinShallowLatestUtc ([string]$installLoc)}else{$null})
          }
        } | Sort-Object @{Expression={if($null -ne $_.EstimatedSize){$_.EstimatedSize}else{-1L}};Descending=$true}, DisplayName | Select-Object -First 30)
        $data=$sized
      }
      'radar' {$result=Get-SyrinRadar -Seconds $Seconds;$data=@($result.data);$errors=@($result.errors)}
      'hotspots' {$result=Get-SyrinHotspots -Seconds $Seconds;$data=@($result.data);$errors=@($result.errors)}
      'devArtifacts' {$result=Get-SyrinDevArtifacts -Seconds $Seconds;$data=@($result.data);$errors=@($result.errors)}
      default {throw 'Unknown read-only collector.'}
    }
    if($errors.Count){$status='partial'}
  } catch {$errors=@($_.Exception.Message);$status=$(if($data.Count){'partial'}else{'failed'})}
  return [PSCustomObject]@{status=$status;data=@($data);errors=@($errors);durationMs=$timer.ElapsedMilliseconds}
}

function Invoke-SyrinCollectorJob([string]$Name,[int]$Seconds,[string]$ContextLabel='') {
  $job=$null
  try {
    $job=Start-Job -ScriptBlock {param($ModulePath,$Collector,$Budget,$Context) $env:PSModulePath=Join-Path $PSHOME 'Modules';Import-Module $ModulePath;Invoke-SyrinCollector -Name $Collector -Seconds ([math]::Max(1,$Budget-2)) -ContextLabel $Context} -ArgumentList @((Join-Path $PSScriptRoot 'Audit.psm1'),$Name,$Seconds,$ContextLabel)
    if(-not(Wait-Job -Job $job -Timeout $Seconds)) {Stop-Job $job;return [PSCustomObject]@{status='unavailable';data=@();errors=@('Collector timed out.');durationMs=($Seconds*1000)}}
    $result=Receive-Job -Job $job -ErrorAction Stop
    if(-not $result -or -not $result.PSObject.Properties['status']){throw 'Collector returned no structured result.'}
    return [PSCustomObject]@{status=$result.status;data=@($result.data);errors=@($result.errors);durationMs=$result.durationMs}
  } catch {return [PSCustomObject]@{status='failed';data=@();errors=@($_.Exception.Message);durationMs=0}}
  finally {if($job){Remove-Job -Job $job -Force -ErrorAction SilentlyContinue}}
}

function Invoke-SyrinAudit {
  param([string]$OutDir='',[ValidateSet('3d','simple','none')][string]$ReportMode='3d',[ValidateSet('full','health','speed','cleanup')][string]$Scope='full',[int]$MaxSeconds=180,[switch]$Quiet,[ValidateRange(0,60)][int]$PerformanceSeconds=0,[string]$ContextLabel='')
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
  $names=@('system','volumes','memory','startup','events','security','cpu','gpu','ram','disks','diskHealth','power','battery','restorePoints','processes','tasks','services','apps','radar','hotspots','devArtifacts','largeFiles')
  if($PerformanceSeconds -eq 1){throw 'Performance sampling requires at least two seconds.'}
  if($PerformanceSeconds -eq 0 -and $Scope -eq 'speed'){$PerformanceSeconds=30}
  if($PerformanceSeconds){$names=@('system','performance')+@($names|Where-Object {$_ -ne 'system'})}
  $progressPath=Join-Path $full 'audit-progress.json'
  foreach($name in $names){
    $remaining=[int]($MaxSeconds-$timer.Elapsed.TotalSeconds)
    if($remaining -le 0 -or ($name -in @('radar','hotspots','devArtifacts','largeFiles') -and $Scope -in @('health','speed'))){$collectors[$name]=[PSCustomObject]@{status='unavailable';data=@();errors=@('Not requested or total audit budget exhausted.');durationMs=0};continue}
    Write-SyrinAtomicJson $progressPath ([ordered]@{schemaVersion=1;kind='syrin-audit-progress';sessionId=$session.sessionId;status='running';activeCollector=$name;completedCount=$collectors.Count;totalCount=$names.Count;elapsedMs=$timer.ElapsedMilliseconds;updatedUtc=[DateTime]::UtcNow.ToString('o')})
    if(-not $Quiet){Write-Progress -Activity 'Syrin clean audit' -Status $name -PercentComplete (100*$collectors.Count/$names.Count)}
    $budget=[math]::Min($remaining,$(if($name -in @('radar','largeFiles')){[math]::Max(40,[int]($MaxSeconds/4))}elseif($name -in @('hotspots','devArtifacts')){[math]::Max(20,[int]($MaxSeconds/6))}else{20}))
    if($name -eq 'performance'){$budget=[math]::Min($remaining,$PerformanceSeconds+5)}
    $collectors[$name]=Invoke-SyrinCollectorJob $name $budget $ContextLabel
  }
  $system=@($collectors.system.data) | Select-Object -First 1
  $audit=[ordered]@{schemaVersion=1;kind='syrin-audit';meta=[ordered]@{sessionId=$session.sessionId;generatedUtc=[DateTime]::UtcNow.ToString('o');machineId=(Get-SyrinValue $system 'machineId');systemDrive=(Get-SyrinValue $system 'systemDrive');reportMode=$ReportMode;scope=$Scope;durationMs=$timer.ElapsedMilliseconds;warnings=@();warningCodes=@('agent-privacy','support-unverified')};collectors=$collectors}
  Write-SyrinAtomicJson (Join-Path $full 'audit.json') $audit
  Write-SyrinAtomicJson (Join-Path $full 'state.json') ([ordered]@{schemaVersion=1;kind='syrin-state';sessionId=$session.sessionId;phase='audited';updatedUtc=[DateTime]::UtcNow.ToString('o');approvedItemIds=@();completed=@();failed=@()})
  $incomplete=@($collectors.Keys | Where-Object {$collectors[$_].status -ne 'complete'})
  Write-SyrinAtomicJson $progressPath ([ordered]@{schemaVersion=1;kind='syrin-audit-progress';sessionId=$session.sessionId;status='completed';activeCollector=$null;completedCount=$collectors.Count;totalCount=$names.Count;incomplete=$incomplete;elapsedMs=$timer.ElapsedMilliseconds;updatedUtc=[DateTime]::UtcNow.ToString('o')})
  if(-not $Quiet){Write-Progress -Activity 'Syrin clean audit' -Completed}
  return [PSCustomObject]@{ok=$true;outDir=$full;sessionId=$session.sessionId;incomplete=$incomplete;reportMode=$ReportMode;progressFile=$progressPath}
}

Export-ModuleMember -Function Get-SyrinValue,Get-SyrinScan,Get-SyrinStartup,Invoke-SyrinCollector,Invoke-SyrinAudit
