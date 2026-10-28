# =====================================================================
#  KIEM TOAN NHANH WINDOWS - Universal v3.2 - 100% CHI DOC
#  Windows PowerShell 5.1 / PowerShell 7, moi ngon ngu Windows. Nen chay quyen Admin.
#  Khong xoa, khong sua gi tren may. Chi ghi ket qua vao thu muc -OutDir:
#    audit.json (du lieu day du cho AI agent) + audit-report.html (de doc).
#  Agent: powershell -NoProfile -ExecutionPolicy Bypass -File audit.ps1 -OutDir <thu muc> -Quiet
# =====================================================================
param([string]$OutDir = '', [switch]$Quiet)
$ErrorActionPreference = 'SilentlyContinue'
if (-not $OutDir) { $OutDir = Join-Path ([Environment]::GetFolderPath('Desktop')) ('Syrin-Clean-' + (Get-Date -Format 'yyyyMMdd-HHmm')) }
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$Audit = [ordered]@{}
function Out-Section {
  # Luu ket qua vao $Audit; chi in ra man hinh khi khong dung -Quiet
  param([Parameter(Mandatory = $true)][string]$Name, [Parameter(ValueFromPipeline = $true)]$InputObject)
  begin { $buf = New-Object System.Collections.ArrayList }
  process { if ($null -ne $InputObject) { [void]$buf.Add($InputObject) } }
  end {
    $Audit[$Name] = @($buf)
    if (-not $Quiet -and $buf.Count) {
      Write-Host "`n== $Name ==" -ForegroundColor Yellow
      if ($buf.Count -eq 1 -and $buf[0] -isnot [string]) { $buf | Format-List | Out-String -Width 200 | Write-Host }
      else { $buf | Format-Table -AutoSize -Wrap | Out-String -Width 200 | Write-Host }
    }
  }
}
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$sys = $env:SystemDrive
if (-not $Quiet) { Write-Host "Admin: $isAdmin | PowerShell: $($PSVersionTable.PSVersion) | System drive: $sys | OutDir: $OutDir" -ForegroundColor Cyan }

function Get-SafeSize {
  # Do thu muc: bo qua junction/symlink, tach file cloud-only, co gioi han thoi gian
  param([string]$Path, [int]$Seconds = 30)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $root = Get-Item -LiteralPath $Path -Force
  if ($root -is [IO.FileInfo]) { return [PSCustomObject]@{ GB = [math]::Round($root.Length/1GB,2); CloudGB = 0; Complete = $true } }
  $sw = [Diagnostics.Stopwatch]::StartNew(); $local = 0L; $cloud = 0L; $done = $true
  $stack = New-Object System.Collections.Stack; $stack.Push($root)
  while ($stack.Count -gt 0) {
    if ($sw.Elapsed.TotalSeconds -gt $Seconds) { $done = $false; break }
    $dir = $stack.Pop()
    try {
      foreach ($i in $dir.EnumerateFileSystemInfos()) {
        if ($i -is [IO.DirectoryInfo]) { if (-not ($i.Attributes -band [IO.FileAttributes]::ReparsePoint)) { $stack.Push($i) } }
        elseif (([int]$i.Attributes -band 0x441000) -ne 0) { $cloud += $i.Length }
        else { $local += $i.Length }
      }
    } catch { }
  }
  [PSCustomObject]@{ GB = [math]::Round($local/1GB,2); CloudGB = [math]::Round($cloud/1GB,2); Complete = $done }
}

# 1. He dieu hanh & loai may (Windows 11 = build >= 22000; khong tin ProductName)
$cv  = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$os  = Get-CimInstance Win32_OperatingSystem
$cs  = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
[PSCustomObject]@{
  Windows       = $(if ([int]$cv.CurrentBuild -ge 22000) { 'Windows 11' } else { 'Windows 10 (het ho tro tu 14/10/2025)' })
  Edition       = $cv.EditionID
  Version       = $cv.DisplayVersion
  Build         = "$($cv.CurrentBuild).$($cv.UBR)"
  Arch          = $(switch ($cpu.Architecture) { 9 {'x64'} 12 {'ARM64'} 0 {'x86'} default {"$($cpu.Architecture)"} })
  MakerModel    = "$($cs.Manufacturer) $($cs.Model)"
  PCSystemType  = $cs.PCSystemType   # 1 = Desktop, 2 = Laptop/Mobile, 3 = Workstation
  Chassis       = (Get-CimInstance Win32_SystemEnclosure).ChassisTypes -join ','
  HasBattery    = [bool](Get-CimInstance Win32_Battery)
  LikelyVM      = "$($cs.Manufacturer) $($cs.Model)" -match 'Virtual|VMware|VirtualBox|QEMU|KVM|Xen|Parallels'
  DomainJoined  = $cs.PartOfDomain
  RAM_GB        = [math]::Round($cs.TotalPhysicalMemory/1GB,1)
  Uptime_h      = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours,1)
  PendingReboot = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
} | Out-Section 'system'

# 2. CPU, GPU, RAM (so khe / so thanh, toc do thuc te)
Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed | Out-Section 'cpu'
Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation -Filter "Name='_Total'" | Select-Object ProcessorFrequency, PercentProcessorPerformance, PercentofMaximumFrequency | Out-Section 'cpu_perf'
Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, DriverDate | Out-Section 'gpu'
$slots  = (Get-CimInstance Win32_PhysicalMemoryArray | Measure-Object MemoryDevices -Sum).Sum
$sticks = @(Get-CimInstance Win32_PhysicalMemory)
[PSCustomObject]@{ Sticks = $sticks.Count; Slots = $slots } | Out-Section 'ram_slots'
$sticks | Select-Object DeviceLocator, Manufacturer, PartNumber, @{n='GB';e={[math]::Round($_.Capacity/1GB)}}, Speed, ConfiguredClockSpeed, SMBIOSMemoryType | Out-Section 'ram'

# 3. O dia vat ly, suc khoe, phan vung, TRIM, pagefile, hibernate
Get-PhysicalDisk | Select-Object FriendlyName, MediaType, BusType, HealthStatus, OperationalStatus, @{n='SizeGB';e={[math]::Round($_.Size/1GB)}} | Out-Section 'disks'
if ($isAdmin) { Get-PhysicalDisk | Get-StorageReliabilityCounter | Select-Object DeviceId, Temperature, Wear, ReadErrorsTotal, WriteErrorsTotal, PowerOnHours | Out-Section 'disk_health' }
Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter } | Sort-Object DriveLetter |
  Select-Object DriveLetter, FileSystemLabel, FileSystem, @{n='SizeGB';e={[math]::Round($_.Size/1GB,1)}}, @{n='FreeGB';e={[math]::Round($_.SizeRemaining/1GB,1)}}, @{n='FreePct';e={ if ($_.Size) { [math]::Round($_.SizeRemaining/$_.Size*100,1) } }} | Out-Section 'volumes'
if ($isAdmin) { fsutil behavior query DisableDeleteNotify | Out-Section 'trim' }
Get-CimInstance Win32_PageFileUsage | Select-Object Name, AllocatedBaseSize, CurrentUsage, PeakUsage | Out-Section 'pagefile'
& { foreach ($f in 'hiberfil.sys','pagefile.sys','swapfile.sys') { $i = Get-Item -LiteralPath "$sys\$f" -Force; if ($i) { [PSCustomObject]@{ File = $f; GB = [math]::Round($i.Length/1GB,2) } } } } | Out-Section 'system_files'
[PSCustomObject]@{
  AutoManagedPagefile = $cs.AutomaticManagedPagefile
  HibernateEnabled    = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Power').HibernateEnabled
  FastStartup         = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power').HiberbootEnabled
  HAGS_HwSchMode      = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers').HwSchMode   # 2 = bat
} | Out-Section 'power_flags'
powercfg /getactivescheme | Out-Section 'power_scheme'

# 4. Hieu nang tuc thoi (lop CIM, khong phu thuoc ngon ngu)
$mem = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory
[PSCustomObject]@{ Commit_GB = [math]::Round($mem.CommittedBytes/1GB,1); CommitLimit_GB = [math]::Round($mem.CommitLimit/1GB,1); CommitPct = $mem.PercentCommittedBytesInUse; Available_GB = [math]::Round($mem.AvailableBytes/1GB,1); PagesPerSec = $mem.PagesPersec } | Out-Section 'memory'
Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk | Where-Object Name -ne '_Total' | Select-Object Name, PercentIdleTime, AvgDisksecPerTransfer, CurrentDiskQueueLength | Out-Section 'disk_perf'
Get-CimInstance Win32_PerfFormattedData_PerfProc_Process | Where-Object { $_.Name -notin '_Total','Idle' } | Sort-Object PercentProcessorTime -Descending |
  Select-Object -First 10 Name, IDProcess, PercentProcessorTime, @{n='PrivateMB';e={[math]::Round($_.PrivateBytes/1MB)}}, @{n='IO_KBps';e={[math]::Round($_.IODataBytesPersec/1KB)}} | Out-Section 'top_cpu'
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 Name, Id, @{n='WorkingSetMB';e={[math]::Round($_.WorkingSet64/1MB)}}, @{n='PrivateMB';e={[math]::Round($_.PrivateMemorySize64/1MB)}} | Out-Section 'top_ram'

# 5. Muc khoi dong (Run + trang thai StartupApproved), thu muc Startup, task & dich vu ben thu ba
$skip = 'PSPath','PSParentPath','PSChildName','PSDrive','PSProvider'
$approved = @{}
foreach ($a in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run',
               'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run',
               'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32') {
  $p = Get-ItemProperty $a
  if ($p) { $p.PSObject.Properties | Where-Object { $_.Name -notin $skip } | ForEach-Object { $approved[$_.Name] = (($_.Value[0] % 2) -eq 0) } }
}
& {
  foreach ($k in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
                 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
                 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run') {
    $p = Get-ItemProperty $k
    if ($p) { $p.PSObject.Properties | Where-Object { $_.Name -notin $skip } | ForEach-Object {
      $cmd = "$($_.Value)"
      [PSCustomObject]@{ Hive = ($k -split ':')[0]; Name = $_.Name; Enabled = $(if ($approved.ContainsKey($_.Name)) { $approved[$_.Name] } else { $true }); Command = $cmd.Substring(0, [math]::Min(90, $cmd.Length)) }
    } }
  }
} | Out-Section 'startup_run'
& { foreach ($f in [Environment]::GetFolderPath('Startup'), [Environment]::GetFolderPath('CommonStartup')) {
  Get-ChildItem -LiteralPath $f -Force | Where-Object Name -ne 'desktop.ini' | Select-Object @{n='StartupFolder';e={$f}}, Name
} } | Out-Section 'startup_folders'
Get-ScheduledTask | Where-Object { $_.TaskPath -notlike '\Microsoft\*' -and $_.State -ne 'Disabled' } |
  Select-Object -First 40 TaskPath, TaskName, State, @{n='Triggers';e={ ($_.Triggers | ForEach-Object { $_.CimClass.CimClassName -replace '^MSFT_Task|Trigger$','' }) -join ',' }} | Out-Section 'tasks'
Get-CimInstance Win32_Service -Filter "StartMode='Auto'" |
  Where-Object { $_.PathName -and $_.PathName -notmatch '\\Windows\\(System32|SysWOW64|servicing)\\' -and $_.PathName -notmatch 'Windows Defender' } |
  Select-Object Name, DisplayName, State | Sort-Object DisplayName | Out-Section 'services'

# 6. Nhat ky loi 7 ngay (nhom theo nguon + ID) & bao mat nen
Get-WinEvent -FilterHashtable @{ LogName = 'System','Application'; Level = 1,2; StartTime = (Get-Date).AddDays(-7) } -MaxEvents 5000 |
  Group-Object ProviderName, Id | Sort-Object Count -Descending | Select-Object -First 20 Count, Name | Out-Section 'events'
Get-MpComputerStatus | Select-Object AMRunningMode, RealTimeProtectionEnabled, AntivirusSignatureAge | Out-Section 'defender'
Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct | Select-Object displayName, productState | Out-Section 'antivirus'
if ($isAdmin -and (Get-Command Get-ComputerRestorePoint -ErrorAction SilentlyContinue)) {
  Get-ComputerRestorePoint | Select-Object -Last 3 SequenceNumber, Description, @{n='Created';e={$_.ConvertToDateTime($_.CreationTime)}} | Out-Section 'restore_points'
}

# 7. Radar rac ngam (chi do thu muc ton tai, chi hien muc >= 0.1 GB)
$L = $env:LOCALAPPDATA; $R = $env:APPDATA; $U = $env:USERPROFILE; $W = $env:windir; $PD = $env:ProgramData
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
$res = foreach ($e in $radar.GetEnumerator()) {
  $s = Get-SafeSize -Path $e.Value -Seconds 30
  if ($s -and ($s.GB -ge 0.1 -or $s.CloudGB -ge 0.1)) { [PSCustomObject]@{ Item = $e.Key; GB = $s.GB; CloudOnlyGB = $s.CloudGB; Complete = $s.Complete; Path = $e.Value } }
}
$res | Sort-Object GB -Descending | Out-Section 'radar'
$rb = (New-Object -ComObject Shell.Application).NameSpace(10)
[PSCustomObject]@{ GB = [math]::Round((($rb.Items() | Measure-Object -Property Size -Sum).Sum)/1GB,2); Items = $rb.Items().Count } | Out-Section 'recycle_bin'
Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' | ForEach-Object {
  $p = Get-ItemProperty $_.PSPath; $v = Join-Path ($p.BasePath -replace '^\\\\\?\\','') 'ext4.vhdx'
  if (Test-Path -LiteralPath $v) { [PSCustomObject]@{ WSL = $p.DistributionName; VhdxGB = [math]::Round((Get-Item -LiteralPath $v -Force).Length/1GB,2); Path = $v } }
} | Out-Section 'wsl'

# 8. Top 20 file lon nhat (>= 300 MB) trong thu muc nguoi dung (bo qua junction & file cloud-only, toi da 120 giay)
function Find-LargeFiles {
  param([string]$Root, [long]$MinBytes = 300MB, [int]$Seconds = 120)
  $sw = [Diagnostics.Stopwatch]::StartNew(); $stack = New-Object System.Collections.Stack
  $r = Get-Item -LiteralPath $Root -Force; if (-not $r) { return }; $stack.Push($r)
  while ($stack.Count -gt 0 -and $sw.Elapsed.TotalSeconds -lt $Seconds) {
    $d = $stack.Pop()
    try { foreach ($i in $d.EnumerateFileSystemInfos()) {
      if ($i -is [IO.DirectoryInfo]) { if (-not ($i.Attributes -band [IO.FileAttributes]::ReparsePoint)) { $stack.Push($i) } }
      elseif ($i.Length -ge $MinBytes -and (([int]$i.Attributes -band 0x441000) -eq 0)) { $i }
    } } catch { }
  }
}
Find-LargeFiles -Root $env:USERPROFILE | Sort-Object Length -Descending |
  Select-Object -First 20 @{n='GB';e={[math]::Round($_.Length/1GB,2)}}, LastWriteTime, FullName | Out-Section 'large_files'

# 9. Top 25 phan mem nang nhat (doc Registry Uninstall, KHONG dung Win32_Product)
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' |
  Where-Object { $_.DisplayName -and $_.EstimatedSize -and -not $_.SystemComponent } |
  Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, @{n='EstimatedGB';e={[math]::Round($_.EstimatedSize/1MB,2)}} |
  Sort-Object EstimatedGB -Descending | Select-Object -First 25 | Out-Section 'apps'

# 10. Xuat ket qua: audit.json cho agent, audit-report.html de doc, tom tat ngan
$Audit['meta'] = [PSCustomObject]@{ GeneratedAt = (Get-Date).ToString('s'); IsAdmin = $isAdmin; PSVersion = "$($PSVersionTable.PSVersion)"; OutDir = $OutDir }
$json = Join-Path $OutDir 'audit.json'
$Audit | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $json -Encoding UTF8
$frag = foreach ($k in $Audit.Keys) {
  $rows = @($Audit[$k]) | ForEach-Object { if ($_ -is [string]) { [PSCustomObject]@{ Value = $_ } } else { $_ } }
  if ($rows) { $rows | ConvertTo-Html -Fragment -PreContent "<h2>$k</h2>" | Out-String }
}
$css = '<style>body{font-family:Segoe UI,Arial,sans-serif;margin:24px;color:#16202e}h2{margin-top:26px;font-size:16px}table{border-collapse:collapse}td,th{border:1px solid #d7dee9;padding:4px 8px;font-size:13px;vertical-align:top}th{background:#eef1f6}</style>'
ConvertTo-Html -Title 'Syrin clean audit' -Head $css -Body ($frag -join "`n") | Set-Content -LiteralPath (Join-Path $OutDir 'audit-report.html') -Encoding UTF8
$sv = @($Audit['volumes']) | Where-Object { "$($_.DriveLetter):" -eq $sys } | Select-Object -First 1
$radarGB = [math]::Round(((@($Audit['radar']) | Measure-Object GB -Sum).Sum), 1)
Write-Host ('SUMMARY | {0} {1} | RAM {2} GB | {3} free {4} GB ({5}%) | radar {6} items {7} GB | startup {8} | events7d {9} | admin {10}' -f `
  $Audit['system'][0].Windows, $Audit['system'][0].Version, $Audit['system'][0].RAM_GB, $sys, $sv.FreeGB, $sv.FreePct, `
  @($Audit['radar']).Count, $radarGB, @($Audit['startup_run']).Count, ((@($Audit['events']) | Measure-Object Count -Sum).Sum), $isAdmin) -ForegroundColor Green
Write-Host "Xong, khong co thay doi nao tren may. Ket qua: $json" -ForegroundColor Green
