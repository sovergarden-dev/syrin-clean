[CmdletBinding()]
param([string]$AdbPath='', [string]$Serial='', [string]$OutDir='', [switch]$Devices,[switch]$Check,[switch]$IncludePackages,[switch]$IncludeThermal,[switch]$IncludeAppSizes,[string]$Package='', [ValidateRange(0,30)][int]$FrameWindowSeconds=0, [ValidateLength(0,240)][string]$ContextLabel='', [ValidateRange(30,300)][int]$MaxSeconds=120,[ValidateSet('en','vi')][string]$Lang='en',[switch]$NoReport)
$ErrorActionPreference='Stop'
try {
  Import-Module (Join-Path $PSScriptRoot '..\modules\IO.psm1')
  $candidates=@(Get-Command python.exe -CommandType Application -ErrorAction SilentlyContinue)
  $python=@($candidates | Where-Object {$_.Source -notmatch '[\\/]Microsoft[\\/]WindowsApps[\\/]python(?:3)?\.exe$'}) | Select-Object -First 1
  if(-not $python){
    $launcher=Get-Command py.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if($launcher){
      $resolvedPy=(& $launcher.Source -3 -c 'import sys; print(sys.executable)' 2>$null | Out-String).Trim()
      if(-not $LASTEXITCODE -and $resolvedPy -and [IO.File]::Exists($resolvedPy)){$python=[PSCustomObject]@{Source=$resolvedPy}}
    }
  }
  if(-not $python){throw 'Python 3.10+ was not found. Install official Python (not the Microsoft Store stub alias) and run this check again.'}
  if(-not $AdbPath){$resolved=Get-Command adb.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1;if($resolved){$AdbPath=$resolved.Source}else{throw "ADB was not found. Supply -AdbPath with the absolute path to Google's SDK Platform Tools adb.exe."}}
  $adb=Assert-SyrinLocalPath $AdbPath
  if($FrameWindowSeconds -eq 1){throw 'Frame sampling window must be 0 (single snapshot) or between 2 and 30 seconds.'}
  if($FrameWindowSeconds -gt 0 -and (-not $Package -or $Check -or $Devices)){throw '-FrameWindowSeconds requires -Package during an audit run.'}
  $arguments=@('-B','-X','utf8',(Join-Path $PSScriptRoot '..\android\audit.py'),'--adb',$adb,'--seconds',[string]$MaxSeconds)
  if($Check){
    $version=(& $python.Source --version 2>&1 | Out-String).Trim()
    if($LASTEXITCODE -or $version -notmatch '^Python (\d+)\.(\d+)(?:\.|$)' -or [int]$Matches[1] -lt 3 -or ([int]$Matches[1] -eq 3 -and [int]$Matches[2] -lt 10)){throw 'Python 3.10+ is required. The selected PATH application did not report a supported Python version.'}
    $arguments+='--check';if($Serial){$arguments+=@('--serial',$Serial)}
  }
  elseif($Devices){$arguments+='--list-devices'}
  else {
    if(-not $Serial){throw 'Choose the exact phone serial shown by -Devices.'}
    if(-not $OutDir){$OutDir=Join-Path $env:LOCALAPPDATA ('SyrinClean\Sessions\android-'+[guid]::NewGuid().ToString('N'))}
    $OutDir=Assert-SyrinLocalPath $OutDir
    foreach($cloud in @(Get-SyrinCloudRoots)){if((Test-SyrinWithin $OutDir $cloud) -or (Test-SyrinWithin $cloud $OutDir)){throw 'Keep phone reports outside cloud sync roots.'}}
    $arguments+=@('--serial',$Serial,'--out',$OutDir)
    if($IncludePackages){$arguments+='--include-packages'}
    if($IncludeThermal){$arguments+='--include-thermal'}
    if($IncludeAppSizes){$arguments+='--include-app-sizes'}
    if($Package){$arguments+=@('--package',$Package);if($FrameWindowSeconds -ge 2){$arguments+=@('--frame-window-seconds',[string]$FrameWindowSeconds)}}
    if($ContextLabel){$arguments+=@('--context-label',$ContextLabel)}
  }
  $json=& $python.Source @arguments
  $code=$LASTEXITCODE
  try{$result=($json -join "`n") | ConvertFrom-Json -ErrorAction Stop}
  catch{throw 'Android audit returned no structured result. Verify Python 3.10+ and the bundled runtime.'}
  if($code -or -not $result.ok){throw ('Android audit failed: '+$result.error)}
  if(-not $Check -and -not $Devices -and -not $NoReport){
    Import-Module (Join-Path $PSScriptRoot '..\modules\Report.psm1')
    $report=New-SyrinReport -OutDir $OutDir -Lang $Lang -Mode simple -Quiet
    $result|Add-Member -NotePropertyName report -NotePropertyValue $report.path
  }
  $result | ConvertTo-Json -Depth 8
} catch {[PSCustomObject]@{ok=$false;error=$_.Exception.Message}|ConvertTo-Json -Compress;exit 2}
