# quarantine.ps1 - Xoa mem file/thu muc ca nhan bang khu cach ly co manifest (khoi phuc duoc).
#   Xem truoc (mac dinh, khong doi gi): quarantine.ps1 -Path 'C:\a.mp4','D:\old'
#   Thuc hien:  them -Apply   -> chuyen vao <o>:\Syrin-Clean-Quarantine\<thoi gian>\..., ghi manifest.csv
#   Khoi phuc:  quarantine.ps1 -Restore      Xoa han: quarantine.ps1 -Purge  (chi khi nguoi dung duyet)
# Luu y: dung luong chi duoc giai phong sau -Purge. File trong thu muc OneDrive bi bo qua (xoa o do = xoa tren cloud).
param([string[]]$Path = @(), [switch]$Apply, [switch]$Restore, [switch]$Purge, [string]$QuarantineRoot = '')
$ErrorActionPreference = 'Stop'
$roots = if ($QuarantineRoot) { @($QuarantineRoot) } else {
  @(Get-PSDrive -PSProvider FileSystem | ForEach-Object { Join-Path $_.Root 'Syrin-Clean-Quarantine' } | Where-Object { Test-Path -LiteralPath $_ })
}
if ($Restore -or $Purge) {
  foreach ($r in $roots) {
    $mf = Join-Path $r 'manifest.csv'
    if (-not (Test-Path -LiteralPath $mf)) { continue }
    $items = @(Import-Csv -LiteralPath $mf)
    if ($Restore) {
      foreach ($i in $items) {
        if ((Test-Path -LiteralPath $i.Stored) -and -not (Test-Path -LiteralPath $i.Original)) {
          New-Item -ItemType Directory -Path (Split-Path -Parent $i.Original) -Force | Out-Null
          Move-Item -LiteralPath $i.Stored -Destination $i.Original
          "RESTORED $($i.Original)"
        } else { "SKIP $($i.Original)" }
      }
      Rename-Item -LiteralPath $mf -NewName ('manifest-restored-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.csv')
    } else {
      $gb = [math]::Round((($items | ForEach-Object { [double]$_.Bytes } | Measure-Object -Sum).Sum) / 1GB, 2)
      Remove-Item -LiteralPath $r -Recurse -Force
      "PURGED $r ($gb GB)"
    }
  }
  return
}
$cloud = @($env:OneDrive, $env:OneDriveConsumer, $env:OneDriveCommercial) | Where-Object { $_ }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$total = 0L
$rows = foreach ($p in $Path) {
  if (-not (Test-Path -LiteralPath $p)) { [PSCustomObject]@{ Path = $p; GB = 0; Status = 'NOT_FOUND' }; continue }
  $it = Get-Item -LiteralPath $p -Force
  if (@($cloud | Where-Object { $it.FullName.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }).Count) { [PSCustomObject]@{ Path = $it.FullName; GB = 0; Status = 'SKIP_CLOUD_FOLDER' }; continue }
  $bytes = if ($it -is [IO.DirectoryInfo]) { [long](Get-ChildItem -LiteralPath $it.FullName -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum } else { [long]$it.Length }
  $status = 'PREVIEW'
  if ($Apply) {
    try {
      $drv = [IO.Path]::GetPathRoot($it.FullName)
      $root = Join-Path $drv 'Syrin-Clean-Quarantine'
      $dest = Join-Path (Join-Path $root $stamp) $it.FullName.Substring($drv.Length)
      New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
      Move-Item -LiteralPath $it.FullName -Destination $dest
      [PSCustomObject]@{ Original = $it.FullName; Stored = $dest; Bytes = $bytes; Time = (Get-Date).ToString('s') } |
        Export-Csv -LiteralPath (Join-Path $root 'manifest.csv') -Append -NoTypeInformation -Encoding UTF8
      $status = 'QUARANTINED'
    } catch { $status = 'ERROR: ' + $_.Exception.Message }
  }
  $total += $bytes
  [PSCustomObject]@{ Path = $it.FullName; GB = [math]::Round($bytes / 1GB, 2); Status = $status }
}
$rows | Format-Table -AutoSize | Out-String -Width 220
"TOTAL_GB=$([math]::Round($total / 1GB, 2)) MODE=$(if ($Apply) { 'APPLY' } else { 'PREVIEW' })"
