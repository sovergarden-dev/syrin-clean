param([string]$ProfileRoot=$env:USERPROFILE)
$ErrorActionPreference='Stop'
$transaction=[guid]::NewGuid().ToString('N')
$targets=New-Object 'System.Collections.Generic.List[object]'
$installLock=$null
function Get-PackageHash([string]$Path){
  $hash=[Security.Cryptography.SHA256]::Create();$stream=[IO.File]::OpenRead($Path)
  try{return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-','').ToLowerInvariant()}
  finally{$stream.Dispose();$hash.Dispose()}
}
function Safe-Path([string]$Path,[string]$Parent){
  $full=[IO.Path]::GetFullPath($Path)
  if(-not $full.StartsWith($Parent.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Path escaped its expected directory.'}
  $cursor=$full
  while($cursor){if(Test-Path -LiteralPath $cursor){$entry=Get-Item -LiteralPath $cursor -Force -ErrorAction Stop;if(([int]$entry.Attributes -band 0x441400) -ne 0){throw 'Reparse or cloud path is not supported for installation.'}};$cursor=[IO.Path]::GetDirectoryName($cursor)}
  return $full
}
try {
  $package=[IO.Path]::GetFullPath($PSScriptRoot)
  $manifestPath=Join-Path $package 'bundle-manifest.json'
  $manifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
  if($manifest.schemaVersion -ne 1 -or $manifest.package -ne 'syrin-clean' -or $manifest.files -isnot [array]){throw 'Unsupported package manifest.'}
  $expected=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach($entry in $manifest.files){
    if($entry.path -match '(^|[/\\])\.\.([/\\]|$)' -or [IO.Path]::IsPathRooted($entry.path) -or $entry.path.Contains(':') -or -not $expected.Add([string]$entry.path)){throw 'Invalid package file path.'}
    $source=Safe-Path (Join-Path $package $entry.path) $package
    if(-not [IO.File]::Exists($source) -or (Get-PackageHash $source) -cne $entry.sha256){throw "Package checksum mismatch: $($entry.path)"}
  }
  $stack=New-Object 'System.Collections.Generic.Stack[string]';$stack.Push($package)
  while($stack.Count){foreach($entry in (Get-Item -LiteralPath $stack.Pop()).EnumerateFileSystemInfos()){
    [void](Safe-Path $entry.FullName $package)
    if($entry -is [IO.DirectoryInfo]){$stack.Push($entry.FullName)}else{$relative=$entry.FullName.Substring($package.Length+1).Replace('\','/');if($relative -ne 'bundle-manifest.json' -and -not $expected.Contains($relative)){throw "Unexpected package file: $relative"}}
  }}
  $profile=[IO.Path]::GetFullPath($ProfileRoot).TrimEnd('\')
  if($profile.Length -lt 4 -or $profile -notmatch '^[A-Za-z]:\\'){throw 'Choose a local profile directory, not a drive root.'}
  if((New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($profile))).DriveType -eq [IO.DriveType]::Network){throw 'Mapped network profiles are not supported.'}
  $currentProfile=[Environment]::GetFolderPath('UserProfile');$profilesParent=[IO.Path]::GetDirectoryName($currentProfile)
  if($profile.StartsWith($profilesParent+'\',[StringComparison]::OrdinalIgnoreCase) -and -not ($profile.Equals($currentProfile,[StringComparison]::OrdinalIgnoreCase) -or $profile.StartsWith($currentProfile+'\',[StringComparison]::OrdinalIgnoreCase))){throw 'Installing into another Windows account is not supported.'}
  foreach($protected in @($env:windir,$env:ProgramFiles,${env:ProgramFiles(x86)},$env:ProgramData)){
    if($protected -and ($profile.Equals($protected,[StringComparison]::OrdinalIgnoreCase) -or $profile.StartsWith($protected.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase))){throw 'System directories cannot be installation profiles.'}
  }
  $workRoot=Safe-Path (Join-Path $profile '.syrin-clean-installer') $profile
  [void][IO.Directory]::CreateDirectory($workRoot)
  $lockPath=Safe-Path (Join-Path $workRoot '.lock') $workRoot
  $installLock=New-Object IO.FileStream($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
  foreach($agent in @('.claude','.agents')){
    $base=Safe-Path (Join-Path $profile ($agent+'\skills')) $profile
    [void][IO.Directory]::CreateDirectory($base)
    $destination=Safe-Path (Join-Path $base 'syrin-clean') $base
    $transactionRoot=Safe-Path (Join-Path (Join-Path $workRoot $transaction) $agent.TrimStart('.')) $workRoot
    [void][IO.Directory]::CreateDirectory($transactionRoot)
    $stage=Safe-Path (Join-Path $transactionRoot 'staged') $workRoot
    $backup=Safe-Path (Join-Path $transactionRoot 'previous') $workRoot
    if(Test-Path -LiteralPath $destination){
      $skillFile=Join-Path $destination 'SKILL.md'
      if(-not(Test-Path -LiteralPath $skillFile) -or [IO.File]::ReadAllText($skillFile) -notmatch '(?m)^name:\s*syrin-clean\s*$'){throw 'Existing directory is not an identified Syrin clean skill.'}
    }
    [void][IO.Directory]::CreateDirectory($stage)
    foreach($entry in $manifest.files | Where-Object {$_.path.StartsWith('syrin-clean/')}){
      $relative=$entry.path.Substring('syrin-clean/'.Length)
      $target=Safe-Path (Join-Path $stage $relative) $stage
      [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
      [IO.File]::Copy((Join-Path $package $entry.path),$target,$false)
      if((Get-PackageHash $target) -cne $entry.sha256){throw 'Staging checksum mismatch.'}
      Unblock-File -LiteralPath $target -ErrorAction Stop
    }
    [IO.File]::WriteAllText((Join-Path $stage '.syrin-installed.json'),(ConvertTo-Json -InputObject @{schemaVersion=1;transaction=$transaction;version=$manifest.version;installedUtc=[DateTime]::UtcNow.ToString('o')}),(New-Object Text.UTF8Encoding $true))
    $targets.Add([PSCustomObject]@{destination=$destination;stage=$stage;backup=$backup;oldMoved=$false;installed=$false})
  }
  foreach($target in $targets){
    [void](Safe-Path $target.destination $profile);[void](Safe-Path $target.stage $workRoot);[void](Safe-Path $target.backup $workRoot)
    if(Test-Path -LiteralPath $target.destination){[IO.Directory]::Move($target.destination,$target.backup);$target.oldMoved=$true}
    [IO.Directory]::Move($target.stage,$target.destination)
    $target.installed=$true
  }
  [PSCustomObject]@{ok=$true;version=$manifest.version;installed=@($targets|ForEach-Object{$_.destination});backups=@($targets|Where-Object oldMoved|ForEach-Object{$_.backup});message='Start a new agent session. Previous versions are retained as backups.'}|ConvertTo-Json -Depth 5
} catch {
  $message=$_.Exception.Message;$rollbackErrors=@()
  for($i=$targets.Count-1;$i -ge 0;$i--){
    $target=$targets[$i]
    try {
      if($target.installed -and (Test-Path -LiteralPath $target.destination)){
        $marker=Get-Content -LiteralPath (Safe-Path (Join-Path $target.destination '.syrin-installed.json') $profile) -Raw -Encoding UTF8 | ConvertFrom-Json
        if($marker.transaction -ne $transaction){throw 'Installed directory changed ownership during rollback.'}
        [void](Safe-Path $target.destination $profile);[void](Safe-Path $target.stage $workRoot)
        [IO.Directory]::Move($target.destination,$target.stage)
      }
      if($target.oldMoved){[void](Safe-Path $target.backup $workRoot);[void](Safe-Path $target.destination $profile);[IO.Directory]::Move($target.backup,$target.destination)}
    } catch {$rollbackErrors+=$_.Exception.Message}
  }
  [PSCustomObject]@{ok=$false;error=$message;rollbackErrors=$rollbackErrors;retainedStaging=@($targets|ForEach-Object{$_.stage});backups=@($targets|Where-Object oldMoved|ForEach-Object{$_.backup})}|ConvertTo-Json -Depth 5
  exit 2
} finally {if($installLock){$installLock.Dispose()}}
