# run-elevated.ps1 - Chay mot script PowerShell bang quyen Admin (1 lan bam UAC) va cho chay xong.
# Ma thoat: ma thoat cua script con; 1223 = nguoi dung bam No o UAC.
# Vi du: powershell -NoProfile -ExecutionPolicy Bypass -File run-elevated.ps1 -Script C:\x\audit.ps1 -Arguments '-OutDir','C:\x','-Quiet'
param([Parameter(Mandatory = $true)][string]$Script, [string[]]$Arguments = @())
$ErrorActionPreference = 'Stop'
$full = (Resolve-Path -LiteralPath $Script).Path
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $full @Arguments
  exit $LASTEXITCODE
}
$quoted = @($Arguments | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } })
$argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $full + '"')) + $quoted
try {
  $p = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList -Wait -PassThru
  Write-Host "ELEVATED_EXIT=$($p.ExitCode)"
  exit $p.ExitCode
} catch {
  Write-Host 'UAC_DECLINED: nguoi dung khong cap quyen Admin.' -ForegroundColor Yellow
  exit 1223
}
