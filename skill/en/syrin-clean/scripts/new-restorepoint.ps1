# new-restorepoint.ps1 - Tao System Restore Point dung cach va xac minh.
# Windows chi cho 1 diem / 24 gio; -RestorePointType KHONG vuot duoc gioi han nay.
# Script tam dat SystemRestorePointCreationFrequency = 0, tao diem, tra gia tri cu, roi xac minh.
# Yeu cau: quyen Admin, Windows PowerShell 5.1 (powershell.exe), System Protection dang bat tren o he thong.
param([string]$Description = ('Before-Syrin-Clean-' + (Get-Date -Format 'yyyyMMdd-HHmm')), [string]$OutDir = '')
$ErrorActionPreference = 'Stop'
$result = [ordered]@{ Created = $false; Description = $Description; Sequence = $null; Message = '' }
$key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
$name = 'SystemRestorePointCreationFrequency'
$had = $false; $old = $null; $touched = $false
try {
  if (-not (Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue)) { throw 'Can chay bang Windows PowerShell 5.1 (powershell.exe), khong phai PowerShell 7.' }
  $prop = Get-ItemProperty -Path $key -Name $name -ErrorAction SilentlyContinue
  if ($null -ne $prop) { $had = $true; $old = $prop.$name }
  New-ItemProperty -Path $key -Name $name -Value 0 -PropertyType DWord -Force | Out-Null
  $touched = $true
  Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS
  Start-Sleep -Seconds 3
  $rp = @(Get-ComputerRestorePoint | Where-Object { $_.Description -eq $Description }) | Select-Object -Last 1
  if ($rp) { $result.Created = $true; $result.Sequence = $rp.SequenceNumber; $result.Message = 'OK' }
  else { $result.Message = 'Khong thay Restore Point moi. System Protection co the dang tat tren o he thong.' }
} catch {
  $result.Message = $_.Exception.Message
} finally {
  if ($touched) {
    if ($had) { Set-ItemProperty -Path $key -Name $name -Value $old }
    else { Remove-ItemProperty -Path $key -Name $name -ErrorAction SilentlyContinue }
  }
}
if ($OutDir) { [PSCustomObject]$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutDir 'restorepoint.json') -Encoding UTF8 }
[PSCustomObject]$result
if (-not $result.Created) { exit 2 }
