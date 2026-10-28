Set-StrictMode -Version 2
if($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -lt 1){throw 'Use Windows PowerShell 5.1 (powershell.exe -NoProfile), not PowerShell 7 or another host.'}

function Get-SyrinOwner {
  return [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
}

function Get-SyrinLexicalPath([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path) -or $Path.StartsWith('\\')) { throw 'A local absolute drive path is required.' }
  $full = [IO.Path]::GetFullPath($Path)
  if ($full -notmatch '^[A-Za-z]:\\' -or $full.Substring(2).Contains(':')) { throw 'Network, device and alternate-stream paths are not supported.' }
  foreach ($part in $full.Substring(3).Split('\')) {
    if ($part.EndsWith('.') -or $part.EndsWith(' ')) { throw 'Ambiguous path segments are not supported.' }
  }
  $drive = New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($full))
  if ($drive.DriveType -eq [IO.DriveType]::Network) { throw 'Mapped network drives are not supported.' }
  return $full
}

function Get-SyrinPath([string]$Path) {
  $full=Get-SyrinLexicalPath $Path
  Initialize-SyrinNative
  $existing=$full;$suffix=New-Object 'System.Collections.Generic.List[string]'
  while(-not(Test-Path -LiteralPath $existing -ErrorAction Stop)){$suffix.Insert(0,[IO.Path]::GetFileName($existing));$existing=[IO.Path]::GetDirectoryName($existing);if(-not $existing){throw 'No local parent directory exists.'}}
  $full=[Syrin.NativeFiles]::LongPath($existing)
  foreach($part in $suffix){$full=Join-Path $full $part}
  if ($full.Length -gt 3) { $full = $full.TrimEnd('\') }
  return $full
}

function Test-SyrinWithin([string]$Child, [string]$Parent) {
  return $Child.Equals($Parent, [StringComparison]::OrdinalIgnoreCase) -or $Child.StartsWith($Parent.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Assert-SyrinLocalPath([string]$Path) {
  $full = Get-SyrinLexicalPath $Path
  $cursor = $full
  while ($cursor) {
    try {
      $entry = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
      if (([int]$entry.Attributes -band 0x441400) -ne 0) { throw "Reparse, offline or recall path is blocked: $cursor" }
    } catch { if($_.CategoryInfo.Category -ne [Management.Automation.ErrorCategory]::ObjectNotFound){throw} }
    $parent = [IO.Path]::GetDirectoryName($cursor)
    if ($parent -eq $cursor) { break }
    $cursor = $parent
  }
  return Get-SyrinPath $full
}

function Get-SyrinCloudRoots {
  $roots = New-Object 'System.Collections.Generic.List[string]'
  foreach ($p in @($env:OneDrive, $env:OneDriveConsumer, $env:OneDriveCommercial)) { if ($p) { $roots.Add((Get-SyrinPath $p)) } }
  $sync = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SyncRootManager'
  if (Test-Path -LiteralPath $sync) {
    foreach ($provider in Get-ChildItem -LiteralPath $sync -ErrorAction Stop) {
      $users = Join-Path $provider.PSPath 'UserSyncRoots'
      if (Test-Path -LiteralPath $users) {
        $values = Get-ItemProperty -LiteralPath $users -ErrorAction Stop
        $entry = $values.PSObject.Properties[(Get-SyrinOwner)]
        if ($entry -and $entry.Value) { $roots.Add((Get-SyrinPath ([string]$entry.Value))) }
      }
    }
  }
  $accounts = 'HKCU:\Software\Microsoft\OneDrive\Accounts'
  if (Test-Path -LiteralPath $accounts) {
    foreach ($key in Get-ChildItem -LiteralPath $accounts -ErrorAction Stop) {
      $entry = (Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop).PSObject.Properties['UserFolder']
      if ($entry -and $entry.Value) { $roots.Add((Get-SyrinPath $entry.Value)) }
    }
  }
  foreach ($p in @((Join-Path $env:LOCALAPPDATA 'Dropbox\info.json'), (Join-Path $env:APPDATA 'Dropbox\info.json'))) {
    if (Test-Path -LiteralPath $p) {
      $config = Read-SyrinJson $p
      foreach ($account in $config.PSObject.Properties) {
        if ($account.Value.PSObject.Properties['path']) { $roots.Add((Get-SyrinPath $account.Value.path)) }
      }
    }
  }
  foreach ($name in @('OneDrive','Dropbox','Google Drive','GoogleDrive','iCloudDrive','iCloud Drive')) {
    $p = Join-Path $env:USERPROFILE $name
    if (Test-Path -LiteralPath $p) { $roots.Add((Get-SyrinPath $p)) }
  }
  return @($roots | Select-Object -Unique)
}

function Assert-SyrinSourcePath([string]$Path, [string[]]$CloudRoots = @()) {
  $full = Assert-SyrinLocalPath $Path
  if ($full -eq [IO.Path]::GetPathRoot($full)) { throw 'A drive root cannot be selected.' }
  $format=(New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($full))).DriveFormat
  if($format -notin @('NTFS','ReFS')){throw 'File operations require NTFS or ReFS with stable file identity and access controls.'}
  $protected = @($env:windir, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData)
  foreach ($base in @($env:USERPROFILE)) {
    foreach ($name in @('.ssh','.gnupg','.aws','.azure','.kube','.docker')) { $protected += Join-Path $base $name }
  }
  $profile = [Environment]::GetFolderPath('UserProfile')
  if ($profile -and (Test-SyrinWithin $full ([IO.Path]::GetDirectoryName($profile))) -and -not (Test-SyrinWithin $full $profile)) { throw 'Other Windows profiles are blocked.' }
  foreach ($p in $protected) {
    if ($p -and ((Test-SyrinWithin $full (Get-SyrinPath $p)) -or (Test-SyrinWithin (Get-SyrinPath $p) $full))) { throw "Protected path is blocked: $full" }
  }
  foreach ($segment in $full.Split('\')) {
    if ($segment -match '^(\.git|\.env(?:\..*)?|Cookies|Login Data|History|Bookmarks|Extensions)$') { throw "Protected data is blocked: $full" }
  }
  foreach ($cloud in $CloudRoots) {
    $cloud = Get-SyrinPath $cloud
    if ((Test-SyrinWithin $full $cloud) -or (Test-SyrinWithin $cloud $full)) { throw "Cloud path or its ancestor is blocked: $full" }
  }
  return $full
}

function Initialize-SyrinNative {
  if ('Syrin.NativeFiles' -as [type]) { return }
  Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;
namespace Syrin {
  public static class NativeFiles {
    [StructLayout(LayoutKind.Sequential)] struct Info {
      public uint Attributes;
      public System.Runtime.InteropServices.ComTypes.FILETIME Created, Accessed, Written;
      public uint Volume, SizeHigh, SizeLow, Links, IndexHigh, IndexLow;
    }
    [StructLayout(LayoutKind.Sequential)] struct FileIdInfo { public ulong Volume; [MarshalAs(UnmanagedType.ByValArray, SizeConst=16)] public byte[] FileId; }
    [StructLayout(LayoutKind.Sequential)] struct RenameInfo { public uint Flags; public IntPtr RootDirectory; public uint FileNameLength; public ushort FileName; }
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr security, uint creation, uint flags, IntPtr template);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetFileInformationByHandle(SafeFileHandle handle, out Info info);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetFileInformationByHandleEx(SafeFileHandle handle, int kind, out FileIdInfo info, uint size);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern uint GetLongPathName(string path, StringBuilder buffer, uint count);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern uint GetFinalPathNameByHandle(SafeFileHandle handle, StringBuilder buffer, uint count, uint flags);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetFileInformationByHandle(SafeFileHandle handle, int kind, ref byte info, uint size);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetFileInformationByHandle(SafeFileHandle handle, int kind, IntPtr info, uint size);
    static string Id(SafeFileHandle handle) { FileIdInfo info; if (!GetFileInformationByHandleEx(handle, 18, out info, 24)) throw new Win32Exception(Marshal.GetLastWin32Error()); return info.Volume.ToString("X16") + ":" + BitConverter.ToString(info.FileId).Replace("-", ""); }
    public static string LongPath(string path) {
      var buffer = new StringBuilder(32768);
      uint size = GetLongPathName(path, buffer, (uint)buffer.Capacity);
      if (size == 0 || size >= buffer.Capacity) throw new Win32Exception(Marshal.GetLastWin32Error());
      return buffer.ToString();
    }
    public static string[] Identity(string path) {
      using (var handle = CreateFile(path, 0x80, 5, IntPtr.Zero, 3, 0x02200000, IntPtr.Zero)) {
        if (handle.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error());
        Info info;
        if (!GetFileInformationByHandle(handle, out info)) throw new Win32Exception(Marshal.GetLastWin32Error());
        return new [] { Id(handle), info.Links.ToString() };
      }
    }
    public static void DeleteChecked(string path, string expectedId, long expectedLength, long expectedWriteTime, uint expectedLinks) {
      using (var handle = CreateFile(path, 0x10080, 1, IntPtr.Zero, 3, 0x02200000, IntPtr.Zero)) {
        if (handle.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error());
        ValidateFile(handle, path, expectedId, expectedLength, expectedWriteTime, expectedLinks);
        byte delete = 1;
        if (!SetFileInformationByHandle(handle, 4, ref delete, 1)) throw new Win32Exception(Marshal.GetLastWin32Error());
      }
    }
    static string FinalPath(SafeFileHandle handle) {
      var buffer = new StringBuilder(32768);
      uint size = GetFinalPathNameByHandle(handle, buffer, (uint)buffer.Capacity, 0);
      if (size == 0 || size >= buffer.Capacity) throw new Win32Exception(Marshal.GetLastWin32Error());
      string value = buffer.ToString();
      return value.StartsWith(@"\\?\", StringComparison.Ordinal) ? value.Substring(4) : value;
    }
    static void ValidateFile(SafeFileHandle handle, string path, string expectedId, long expectedLength, long expectedWriteTime, uint expectedLinks) {
      Info info;
      if (!GetFileInformationByHandle(handle, out info)) throw new Win32Exception(Marshal.GetLastWin32Error());
      long length = ((long)info.SizeHigh << 32) | info.SizeLow;
      long written = ((long)(uint)info.Written.dwHighDateTime << 32) | (uint)info.Written.dwLowDateTime;
      if (!String.Equals(FinalPath(handle), path, StringComparison.OrdinalIgnoreCase) || Id(handle) != expectedId || length != expectedLength || written != expectedWriteTime || info.Links != expectedLinks || (info.Attributes & 0x441410) != 0) throw new InvalidOperationException("File identity or metadata changed before the operation.");
    }
    public static void MoveChecked(string source, string destination, string expectedId, long expectedLength, long expectedWriteTime, uint expectedLinks) {
      string parentPath = System.IO.Path.GetDirectoryName(destination);
      using (var file = CreateFile(source, 0x10080, 1, IntPtr.Zero, 3, 0x02200000, IntPtr.Zero)) {
        if (file.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error());
        using (var parent = CreateFile(parentPath, 0x80000002, 3, IntPtr.Zero, 3, 0x02200000, IntPtr.Zero)) {
        if (parent.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error());
        ValidateFile(file, source, expectedId, expectedLength, expectedWriteTime, expectedLinks);
        Info info;
        if (!GetFileInformationByHandle(parent, out info)) throw new Win32Exception(Marshal.GetLastWin32Error());
        if ((info.Attributes & 0x441400) != 0 || (info.Attributes & 0x10) == 0 || !String.Equals(FinalPath(parent).TrimEnd('\\'), parentPath.TrimEnd('\\'), StringComparison.OrdinalIgnoreCase) || Id(parent).Substring(0,16) != expectedId.Substring(0,16)) throw new InvalidOperationException("Destination directory changed or is on another volume.");
        byte[] name = Encoding.Unicode.GetBytes(destination + "\0");
        int offset = Marshal.OffsetOf(typeof(RenameInfo), "FileName").ToInt32();
        int size = Marshal.SizeOf(typeof(RenameInfo)) + name.Length;
        IntPtr buffer = Marshal.AllocHGlobal(size);
        try {
          Marshal.Copy(new byte[size], 0, buffer, size);
          var rename = new RenameInfo { Flags=0, RootDirectory=IntPtr.Zero, FileNameLength=(uint)(name.Length-2), FileName=0 };
          Marshal.StructureToPtr(rename, buffer, false);
          Marshal.Copy(name, 0, IntPtr.Add(buffer, offset), name.Length);
          if (!SetFileInformationByHandle(file, 3, buffer, (uint)size)) throw new Win32Exception(Marshal.GetLastWin32Error());
          GC.KeepAlive(parent);
        } finally { Marshal.FreeHGlobal(buffer); }
        }
      }
    }
  }
}
'@
}

function Get-SyrinFingerprint([string]$Path) {
  $full = Assert-SyrinLocalPath $Path
  $item = Get-Item -LiteralPath $full -Force -ErrorAction Stop
  if ($item -isnot [IO.FileInfo]) { throw 'Only regular files can be transferred.' }
  Initialize-SyrinNative
  $identity = [Syrin.NativeFiles]::Identity($full)
  if ($identity[0] -match ':0+$') { throw 'The filesystem did not provide a stable file identity.' }
  return [PSCustomObject]@{ FileId=$identity[0]; Length=[long]$item.Length; LastWriteUtc=$item.LastWriteTimeUtc.ToString('o'); Links=[int]$identity[1] }
}

function Test-SyrinFingerprint([string]$Path, $Expected) {
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  $actual = Get-SyrinFingerprint $Path
  return $actual.FileId -eq $Expected.FileId -and $actual.Length -eq $Expected.Length -and $actual.LastWriteUtc -eq $Expected.LastWriteUtc -and $actual.Links -eq $Expected.Links
}

function Remove-SyrinCheckedFile([string]$Path,$Expected) {
  $full=Assert-SyrinLocalPath $Path
  Initialize-SyrinNative
  [Syrin.NativeFiles]::DeleteChecked($full,$Expected.FileId,[long]$Expected.Length,([DateTime]::Parse($Expected.LastWriteUtc).ToUniversalTime().ToFileTimeUtc()),[uint32]$Expected.Links)
}

function Move-SyrinCheckedFile([string]$Source,[string]$Destination,$Expected) {
  $sourcePath=Assert-SyrinLocalPath $Source;$destinationPath=Assert-SyrinLocalPath $Destination
  Initialize-SyrinNative
  [Syrin.NativeFiles]::MoveChecked($sourcePath,$destinationPath,$Expected.FileId,[long]$Expected.Length,([DateTime]::Parse($Expected.LastWriteUtc).ToUniversalTime().ToFileTimeUtc()),[uint32]$Expected.Links)
}

function Get-SyrinDigest([byte[]]$Bytes) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() }
  finally { $sha.Dispose() }
}

function Read-SyrinJson([string]$Path) {
  $full=Assert-SyrinLocalPath $Path
  $text = [IO.File]::ReadAllText($full, [Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
  if ([string]::IsNullOrWhiteSpace($text)) { throw "Empty JSON: $Path" }
  try { return ConvertFrom-Json -InputObject $text -ErrorAction Stop }
  catch { throw "Invalid JSON in $Path. Check the file format; input content is not echoed." }
}

function Write-SyrinAtomicJson([string]$Path, $Value, [switch]$CreateOnly) {
  $text = ConvertTo-Json -InputObject $Value -Depth 24 -Compress
  Write-SyrinAtomicText -Path $Path -Text $text -CreateOnly:$CreateOnly
}

function Write-SyrinAtomicText([string]$Path, [string]$Text, [switch]$CreateOnly) {
  $full = Assert-SyrinLocalPath $Path
  $parent = [IO.Path]::GetDirectoryName($full)
  if (-not (Test-Path -LiteralPath $parent)) { throw "Output directory does not exist: $parent" }
  $temp = Join-Path $parent ('.syrin-write-' + [guid]::NewGuid().ToString('N'))
  $stream = $null
  try {
    $bytes = (New-Object Text.UTF8Encoding $true).GetPreamble() + [Text.Encoding]::UTF8.GetBytes($Text)
    $stream = New-Object IO.FileStream($temp, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $stream.Write($bytes,0,$bytes.Length); $stream.Flush($true); $stream.Dispose(); $stream=$null
    if (Test-Path -LiteralPath $full) {
      if ($CreateOnly) { throw "Output already exists: $full" }
      [IO.File]::Replace($temp,$full,$null)
    } else { [IO.File]::Move($temp,$full) }
  } finally {
    if ($stream) { $stream.Dispose() }
    if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) }
  }
}

function Get-SyrinFiles([string[]]$Path, [string[]]$CloudRoots, [int]$MaxFiles=10000, [int]$Seconds=120) {
  $timer = [Diagnostics.Stopwatch]::StartNew()
  $stack = New-Object 'System.Collections.Generic.Stack[string]'
  foreach ($p in $Path) { $stack.Push((Assert-SyrinSourcePath $p $CloudRoots)) }
  $seen = New-Object 'System.Collections.Generic.HashSet[string]'
  $files = New-Object 'System.Collections.Generic.List[object]'
  while ($stack.Count) {
    if ($timer.Elapsed.TotalSeconds -gt $Seconds) { throw 'Planning scan timed out; no executable plan was produced.' }
    $p = Assert-SyrinSourcePath $stack.Pop() $CloudRoots
    $entry = Get-Item -LiteralPath $p -Force -ErrorAction Stop
    if ($entry -is [IO.DirectoryInfo]) {
      foreach ($child in $entry.EnumerateFileSystemInfos()) {
        if($timer.Elapsed.TotalSeconds -gt $Seconds -or $stack.Count+$files.Count -ge $MaxFiles*2){throw 'Planning entry/time budget exceeded; narrow the selection.'}
        $stack.Push($child.FullName)
      }
    } else {
      $fp = Get-SyrinFingerprint $p
      if ($fp.Links -ne 1) { throw "Hard-linked files require manual review: $p" }
      if ($seen.Add($fp.FileId)) {
        $files.Add([PSCustomObject]@{Path=$p;Fingerprint=$fp})
        if ($files.Count -gt $MaxFiles) { throw 'Planning file limit exceeded; narrow the selection.' }
      }
    }
  }
  return $files.ToArray()
}

function ConvertTo-SyrinCommandArgument([string]$Value) {
  if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
  $value = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
  $value = [regex]::Replace($value, '(\\+)$', '$1$1')
  return '"' + $value + '"'
}

Export-ModuleMember -Function Get-SyrinOwner,Get-SyrinPath,Test-SyrinWithin,Assert-SyrinLocalPath,Get-SyrinCloudRoots,Assert-SyrinSourcePath,Get-SyrinFingerprint,Test-SyrinFingerprint,Remove-SyrinCheckedFile,Move-SyrinCheckedFile,Get-SyrinDigest,Read-SyrinJson,Write-SyrinAtomicJson,Write-SyrinAtomicText,Get-SyrinFiles,ConvertTo-SyrinCommandArgument
