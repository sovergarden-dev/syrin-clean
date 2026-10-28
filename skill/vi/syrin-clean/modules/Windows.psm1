Set-StrictMode -Version 2
Import-Module (Join-Path $PSScriptRoot 'IO.psm1') -Force

function Test-SyrinAdministrator {
  return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-SyrinElevatedScript {
  param([string]$Script,[string[]]$Arguments=@(),[switch]$NoElevate)
  $full=Assert-SyrinLocalPath $Script
  if (-not [IO.File]::Exists($full) -or [IO.Path]::GetExtension($full) -ne '.ps1') { throw 'Choose an existing local PowerShell script.' }
  $argsList=@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$full)+$Arguments
  $commandLine=(@($argsList | ForEach-Object {ConvertTo-SyrinCommandArgument ([string]$_)}) -join ' ')
  if ($commandLine.Length -gt 30000) { throw 'Argument list is too long; use a request file.' }
  $elevate=-not $NoElevate -and -not (Test-SyrinAdministrator)
  try {
    $params=@{FilePath=(Join-Path $env:windir 'System32\WindowsPowerShell\v1.0\powershell.exe');ArgumentList=$commandLine;WindowStyle='Hidden';Wait=$true;PassThru=$true;ErrorAction='Stop'}
    if ($elevate) { $params.Verb='RunAs' }
    $process=Start-Process @params
    return [PSCustomObject]@{ok=($process.ExitCode -eq 0);exitCode=$process.ExitCode;elevationRequested=$elevate;error=''}
  } catch {
    $errorCode=2; $exception=$_.Exception
    while ($exception) {
      if ($exception -is [ComponentModel.Win32Exception]) { if ($exception.NativeErrorCode -eq 1223) {$errorCode=1223}; break }
      $exception=$exception.InnerException
    }
    return [PSCustomObject]@{ok=$false;exitCode=$errorCode;elevationRequested=$elevate;error=$_.Exception.Message}
  }
}

function Get-SyrinRestoreTimestamp($Point) {
  try {
    if ($Point.CreationTime -is [DateTime]) { return $Point.CreationTime.ToUniversalTime() }
    if ([string]$Point.CreationTime -match '^\d{14}\.\d{6}[+-]\d{3}$') { return [Management.ManagementDateTimeConverter]::ToDateTime($Point.CreationTime).ToUniversalTime() }
    return [DateTime]::Parse([string]$Point.CreationTime,[Globalization.CultureInfo]::InvariantCulture).ToUniversalTime()
  } catch { return [DateTime]::MinValue }
}

function New-SyrinRestorePoint {
  param([string]$Description=('Syrin clean '+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+' '+[guid]::NewGuid().ToString('N').Substring(0,8)),[int]$VerifySeconds=20)
  $result=[ordered]@{schemaVersion=1;ok=$false;created=$false;description=$Description;sequence=$null;createdUtc=$null;registryRestored=$true;error=''}
  $key='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore';$name='SystemRestorePointCreationFrequency'
  $had=$false;$old=$null;$touched=$false
  try {
    if (-not (Test-SyrinAdministrator)) { throw 'Administrator rights are required; use run-elevated.ps1 after approval.' }
    if (-not (Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue)) { throw 'Windows PowerShell 5.1 and System Restore support are required.' }
    $before=@(Get-ComputerRestorePoint -ErrorAction Stop)
    $last=0; foreach($point in $before){if([long]$point.SequenceNumber -gt $last){$last=[long]$point.SequenceNumber}}
    $props=Get-ItemProperty -LiteralPath $key -ErrorAction Stop
    $entry=$props.PSObject.Properties[$name]
    if ($entry) {$had=$true;$old=$entry.Value}
    New-ItemProperty -LiteralPath $key -Name $name -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
    $touched=$true
    $started=[DateTime]::UtcNow
    Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    $timer=[Diagnostics.Stopwatch]::StartNew()
    do {
      $new=@(Get-ComputerRestorePoint -ErrorAction Stop | Where-Object { [long]$_.SequenceNumber -gt $last -and $_.Description -eq $Description -and (Get-SyrinRestoreTimestamp $_) -ge $started.AddSeconds(-5) } | Sort-Object SequenceNumber)
      if ($new.Count) { $point=$new[-1];$result.created=$true;$result.sequence=$point.SequenceNumber;$result.createdUtc=(Get-SyrinRestoreTimestamp $point).ToString('o');break }
      if ($timer.Elapsed.TotalSeconds -lt $VerifySeconds) { Start-Sleep -Milliseconds 250 }
    } while ($timer.Elapsed.TotalSeconds -lt $VerifySeconds)
    if (-not $result.created) { throw 'A new restore point was not verified. No safety approval was produced.' }
  } catch { $result.error=$_.Exception.Message }
  finally {
    if ($touched) {
      try {
        if ($had) { Set-ItemProperty -LiteralPath $key -Name $name -Value $old -ErrorAction Stop }
        else { Remove-ItemProperty -LiteralPath $key -Name $name -ErrorAction Stop }
        $entry=(Get-ItemProperty -LiteralPath $key -ErrorAction Stop).PSObject.Properties[$name]
        if (($had -and (-not $entry -or $entry.Value -ne $old)) -or (-not $had -and $entry)) { throw 'Original registry value was not restored.' }
      } catch { $result.registryRestored=$false;$result.error+= ' Registry rollback: '+$_.Exception.Message }
    }
  }
  $result.ok=$result.created -and $result.registryRestored
  return [PSCustomObject]$result
}

Export-ModuleMember -Function Invoke-SyrinElevatedScript,New-SyrinRestorePoint
