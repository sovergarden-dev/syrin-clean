Set-StrictMode -Version 2
if($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -lt 1){throw 'Use Windows PowerShell 5.1 (powershell.exe -NoProfile), not PowerShell 7 or another host.'}

function Get-SyrinOwner {
  return [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
}

function Get-SyrinPath([string]$Path) {
  Initialize-SyrinNative
  return [Syrin.NativeFiles]::LocalPath($Path,$false)
}

function Test-SyrinWithin([string]$Child, [string]$Parent) {
  return $Child.Equals($Parent, [StringComparison]::OrdinalIgnoreCase) -or $Child.StartsWith($Parent.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Assert-SyrinLocalPath([string]$Path) {
  Initialize-SyrinNative
  return [Syrin.NativeFiles]::LocalPath($Path,$true)
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

function New-SyrinSourcePolicy([string[]]$CloudRoots=@()) {
  $protected = @($env:windir, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData)
  foreach ($base in @($env:USERPROFILE)) {
    foreach ($name in @('.ssh','.gnupg','.aws','.azure','.kube','.docker')) { $protected += Join-Path $base $name }
  }
  $profile = Get-SyrinPath ([Environment]::GetFolderPath('UserProfile'))
  return [PSCustomObject]@{profile=$profile;protected=@($protected|Where-Object {$_}|ForEach-Object {Get-SyrinPath $_}|Select-Object -Unique);cloud=@($CloudRoots|ForEach-Object {Get-SyrinPath $_}|Select-Object -Unique);formats=@{}}
}

function Assert-SyrinSourcePath([string]$Path, [string[]]$CloudRoots = @(), $Policy=$null) {
  if($null -eq $Policy){$Policy=New-SyrinSourcePolicy $CloudRoots}
  $full = Assert-SyrinLocalPath $Path
  $driveRoot=[IO.Path]::GetPathRoot($full)
  if ($full -eq $driveRoot) { throw 'A drive root cannot be selected.' }
  if(-not $Policy.formats.ContainsKey($driveRoot)){
    $format=(New-Object IO.DriveInfo $driveRoot).DriveFormat
    if($format -notin @('NTFS','ReFS')){throw 'File operations require NTFS or ReFS with stable file identity and access controls.'}
    $Policy.formats[$driveRoot]=$format
  }
  $profile=$Policy.profile
  if ($profile -and (Test-SyrinWithin $full ([IO.Path]::GetDirectoryName($profile))) -and -not (Test-SyrinWithin $full $profile)) { throw 'Other Windows profiles are blocked.' }
  foreach ($protectedPath in $Policy.protected) {
    if ((Test-SyrinWithin $full $protectedPath) -or (Test-SyrinWithin $protectedPath $full)) { throw "Protected path is blocked: $full" }
  }
  foreach ($segment in $full.Split('\')) {
    if ($segment -match '^(\.git|\.env(?:\..*)?|Cookies|Login Data|History|Bookmarks|Extensions)$') { throw "Protected data is blocked: $full" }
  }
  foreach ($cloud in $Policy.cloud) {
    if ((Test-SyrinWithin $full $cloud) -or (Test-SyrinWithin $cloud $full)) { throw "Cloud path or its ancestor is blocked: $full" }
  }
  return $full
}

function Initialize-SyrinNative {
  if ('Syrin.NativeFiles' -as [type]) { return }
  Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Win32.SafeHandles;
namespace Syrin {
  public sealed class TextDocument {
    public string Path, Text, Digest;
  }
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
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern uint GetFileAttributes(string path);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern uint GetFinalPathNameByHandle(SafeFileHandle handle, StringBuilder buffer, uint count, uint flags);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetFileInformationByHandle(SafeFileHandle handle, int kind, ref byte info, uint size);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetFileInformationByHandle(SafeFileHandle handle, int kind, IntPtr info, uint size);
    static string Id(SafeFileHandle handle) { FileIdInfo info; if (!GetFileInformationByHandleEx(handle, 18, out info, 24)) throw new Win32Exception(Marshal.GetLastWin32Error()); return info.Volume.ToString("X16") + ":" + BitConverter.ToString(info.FileId).Replace("-", ""); }
    public static long Attributes(string path) {
      uint attributes = GetFileAttributes(path);
      if (attributes != UInt32.MaxValue) return attributes;
      int error = Marshal.GetLastWin32Error();
      if (error == 2 || error == 3) return -1;
      throw new Win32Exception(error);
    }
    public static string LocalPath(string path, bool checkAncestors) {
      if (String.IsNullOrWhiteSpace(path) || path.StartsWith(@"\\", StringComparison.Ordinal)) throw new ArgumentException("A local absolute drive path is required.");
      string full = Path.GetFullPath(path);
      bool driveLetter = full.Length > 0 && ((full[0] >= 'A' && full[0] <= 'Z') || (full[0] >= 'a' && full[0] <= 'z'));
      if (full.Length < 3 || !driveLetter || full[1] != ':' || full[2] != '\\' || full.IndexOf(':', 2) >= 0) throw new ArgumentException("Network, device and alternate-stream paths are not supported.");
      foreach (string part in full.Substring(3).Split('\\')) {
        if (part.EndsWith(".", StringComparison.Ordinal) || part.EndsWith(" ", StringComparison.Ordinal)) throw new ArgumentException("Ambiguous path segments are not supported.");
      }
      if (new DriveInfo(Path.GetPathRoot(full)).DriveType == DriveType.Network) throw new ArgumentException("Mapped network drives are not supported.");
      if (checkAncestors) {
        for (string cursor = full; !String.IsNullOrEmpty(cursor); cursor = Path.GetDirectoryName(cursor)) {
          long attributes = Attributes(cursor);
          if (attributes >= 0 && (attributes & 0x441400) != 0) throw new IOException("Reparse, offline or recall path is blocked: " + cursor);
        }
      }
      string existing = full;
      var suffix = new Stack<string>();
      while (Attributes(existing) < 0) {
        suffix.Push(Path.GetFileName(existing)); existing = Path.GetDirectoryName(existing);
        if (String.IsNullOrEmpty(existing)) throw new IOException("No local parent directory exists.");
      }
      full = LongPath(existing);
      while (suffix.Count > 0) full = Path.Combine(full, suffix.Pop());
      return full.Length > 3 ? full.TrimEnd('\\') : full;
    }
    public static string LongPath(string path) {
      var buffer = new StringBuilder(512);
      uint size = GetLongPathName(path, buffer, (uint)buffer.Capacity);
      if (size >= buffer.Capacity && size < 32768) { buffer = new StringBuilder((int)size + 1); size = GetLongPathName(path, buffer, (uint)buffer.Capacity); }
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
    public static TextDocument[] ReadDocuments(string[] paths, int offset, int count) {
      var documents = new TextDocument[count];
      using (var hash = SHA256.Create()) {
        for (int index = 0; index < count; index++) {
          string path = LocalPath(paths[offset + index], true);
          byte[] bytes = File.ReadAllBytes(path);
          string text;
          using (var memory = new MemoryStream(bytes, false))
          using (var reader = new StreamReader(memory, Encoding.UTF8, true)) {
            text = reader.ReadToEnd().TrimStart('\uFEFF');
          }
          documents[index] = new TextDocument { Path = path, Text = text, Digest = BitConverter.ToString(hash.ComputeHash(bytes)).Replace("-", "").ToLowerInvariant() };
        }
      }
      return documents;
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
      var buffer = new StringBuilder(512);
      uint size = GetFinalPathNameByHandle(handle, buffer, (uint)buffer.Capacity, 0);
      if (size >= buffer.Capacity && size < 32768) { buffer = new StringBuilder((int)size + 1); size = GetFinalPathNameByHandle(handle, buffer, (uint)buffer.Capacity, 0); }
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

function Read-SyrinJsonDocument([string]$Path) {
  $full=Assert-SyrinLocalPath $Path
  $bytes=[IO.File]::ReadAllBytes($full)
  $memory=[IO.MemoryStream]::new($bytes,$false)
  $reader=[IO.StreamReader]::new($memory,[Text.Encoding]::UTF8,$true)
  try{$text=$reader.ReadToEnd().TrimStart([char]0xFEFF)}finally{$reader.Dispose();$memory.Dispose()}
  if ([string]::IsNullOrWhiteSpace($text)) { throw "Empty JSON: $Path" }
  try { $value=ConvertFrom-Json -InputObject $text -ErrorAction Stop }
  catch { throw "Invalid JSON in $Path. Check the file format; input content is not echoed." }
  return [PSCustomObject]@{value=$value;text=$text;digest=(Get-SyrinDigest $bytes)}
}

function Read-SyrinJson([string]$Path) {
  return (Read-SyrinJsonDocument $Path).value
}

function Read-SyrinJsonBatch([string[]]$Path,[int]$Offset,[int]$Count) {
  Initialize-SyrinNative
  foreach($document in [Syrin.NativeFiles]::ReadDocuments($Path,$Offset,$Count)) {
    if([string]::IsNullOrWhiteSpace($document.Text)){throw "Empty JSON: $($document.Path)"}
    try{$value=ConvertFrom-Json -InputObject $document.Text -ErrorAction Stop}
    catch{throw "Invalid JSON in $($document.Path). Check the file format; input content is not echoed."}
    [PSCustomObject]@{value=$value;digest=$document.Digest}
  }
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
      [IO.File]::Replace($temp,$full,[NullString]::Value)
    } else { [IO.File]::Move($temp,$full) }
  } finally {
    if ($stream) { $stream.Dispose() }
    if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) }
  }
}

function Get-SyrinFiles([string[]]$Path, [string[]]$CloudRoots, [int]$MaxFiles=10000, [int]$Seconds=120, $Policy=$null) {
  $timer = [Diagnostics.Stopwatch]::StartNew()
  if($null -eq $Policy){$Policy=New-SyrinSourcePolicy $CloudRoots}
  $stack = New-Object 'System.Collections.Generic.Stack[string]'
  foreach ($p in $Path) { $stack.Push((Assert-SyrinSourcePath $p $CloudRoots -Policy $Policy)) }
  $seen = New-Object 'System.Collections.Generic.HashSet[string]'
  $files = New-Object 'System.Collections.Generic.List[object]'
  while ($stack.Count) {
    if ($timer.Elapsed.TotalSeconds -gt $Seconds) { throw 'Planning scan timed out; no executable plan was produced.' }
    $p = Assert-SyrinSourcePath $stack.Pop() $CloudRoots -Policy $Policy
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

Export-ModuleMember -Function Get-SyrinOwner,Get-SyrinPath,Test-SyrinWithin,Assert-SyrinLocalPath,Get-SyrinCloudRoots,New-SyrinSourcePolicy,Assert-SyrinSourcePath,Get-SyrinFingerprint,Test-SyrinFingerprint,Remove-SyrinCheckedFile,Move-SyrinCheckedFile,Get-SyrinDigest,Read-SyrinJson,Read-SyrinJsonDocument,Read-SyrinJsonBatch,Write-SyrinAtomicJson,Write-SyrinAtomicText,Get-SyrinFiles,ConvertTo-SyrinCommandArgument
