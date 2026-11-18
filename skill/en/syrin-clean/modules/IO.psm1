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

function Get-SyrinUserFolder([ValidateSet('UserProfile','Desktop','MyDocuments','MyVideos','Downloads')][string]$Kind) {
  Initialize-SyrinNative
  $realProfile = [Environment]::GetFolderPath('UserProfile')
  $activeProfile = if ($env:USERPROFILE) { $env:USERPROFILE } else { $realProfile }
  $isolated = $realProfile -and -not $activeProfile.TrimEnd('\').Equals($realProfile.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)
  if ($Kind -eq 'UserProfile') { return Get-SyrinPath $activeProfile }
  if ($isolated) {
    $leaf = switch ($Kind) { 'Desktop' { 'Desktop' } 'MyDocuments' { 'Documents' } 'MyVideos' { 'Videos' } 'Downloads' { 'Downloads' } }
    return Join-Path (Get-SyrinPath $activeProfile) $leaf
  }
  if ($Kind -eq 'Downloads') {
    $known = [Syrin.NativeFiles]::KnownFolder('374DE290-123F-4565-9164-39C4925E467B')
    if ($known) { return $known }
    return Join-Path $realProfile 'Downloads'
  }
  return [Environment]::GetFolderPath($Kind)
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

function New-SyrinSourcePolicy([string[]]$CloudRoots=@(),[string[]]$ProtectedPath=@()) {
  $protected = @($env:windir, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData) + $ProtectedPath
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
  [Syrin.NativeFiles]::CheckSourcePolicy($full,$Policy.profile,[string[]]$Policy.protected,[string[]]$Policy.cloud)
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
using System.Text.RegularExpressions;
using Microsoft.Win32.SafeHandles;
namespace Syrin {
  public sealed class TextDocument {
    public string Path, Text, Digest;
  }
  public sealed class PlannedFile {
    public string Path, FileId, LastWriteUtc;
    public long Length;
    public int Links;
  }
  public static class NativeFiles {
    static readonly Regex ProtectedSegment = new Regex(@"^(\.git|\.env(?:\..*)?|Cookies|Login Data|History|Bookmarks|Extensions)$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
    static bool Within(string child, string parent) {
      return child.Equals(parent, StringComparison.OrdinalIgnoreCase) || child.StartsWith(parent.TrimEnd('\\') + "\\", StringComparison.OrdinalIgnoreCase);
    }
    public static void CheckSourcePolicy(string full, string profile, string[] protectedPaths, string[] clouds) {
      if (!String.IsNullOrEmpty(profile) && Within(full, Path.GetDirectoryName(profile)) && !Within(full, profile)) throw new IOException("Other Windows profiles are blocked.");
      foreach (string path in protectedPaths) if (Within(full, path) || Within(path, full)) throw new IOException("Protected path is blocked: " + full);
      foreach (string segment in full.Split('\\')) if (ProtectedSegment.IsMatch(segment)) throw new IOException("Protected data is blocked: " + full);
      foreach (string path in clouds) if (Within(full, path) || Within(path, full)) throw new IOException("Cloud path or its ancestor is blocked: " + full);
    }
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
    [DllImport("shell32.dll")] static extern int SHGetKnownFolderPath([MarshalAs(UnmanagedType.LPStruct)] Guid rfid, uint dwFlags, IntPtr hToken, out IntPtr ppszPath);
    public static string KnownFolder(string guidText) {
      IntPtr ptr = IntPtr.Zero;
      try {
        int hr = SHGetKnownFolderPath(new Guid(guidText), 0x00004000, IntPtr.Zero, out ptr);
        if (hr != 0 || ptr == IntPtr.Zero) return null;
        return Marshal.PtrToStringUni(ptr);
      } finally {
        if (ptr != IntPtr.Zero) Marshal.FreeCoTaskMem(ptr);
      }
    }
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
        if ((info.Attributes & 0x441410) != 0) throw new IOException("Only local regular files can be transferred.");
        long length = ((long)info.SizeHigh << 32) | info.SizeLow;
        long written = ((long)(uint)info.Written.dwHighDateTime << 32) | (uint)info.Written.dwLowDateTime;
        return new [] { Id(handle), info.Links.ToString(System.Globalization.CultureInfo.InvariantCulture), length.ToString(System.Globalization.CultureInfo.InvariantCulture), DateTime.FromFileTimeUtc(written).ToString("o") };
      }
    }
    public static PlannedFile[] CollectPlanFiles(string[] validatedRoots, string profile, string[] protectedPaths, string[] clouds, int maxFiles, int maxSeconds) {
      var timer = System.Diagnostics.Stopwatch.StartNew();
      var stack = new Stack<string>();
      for (int i = validatedRoots.Length - 1; i >= 0; i--) { stack.Push(validatedRoots[i]); }
      var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
      var files = new List<PlannedFile>();
      while (stack.Count > 0) {
        if (timer.Elapsed.TotalSeconds > maxSeconds) throw new IOException("Planning scan timed out; no executable plan was produced.");
        string current = stack.Pop();
        CheckSourcePolicy(current, profile, protectedPaths, clouds);
        long attrs = Attributes(current);
        if (attrs < 0) throw new FileNotFoundException("Path does not exist: " + current);
        if ((attrs & 0x441400) != 0) throw new IOException("Reparse, offline or recall path is blocked: " + current);
        if ((attrs & 0x10) != 0) {
          foreach (FileSystemInfo child in new DirectoryInfo(current).EnumerateFileSystemInfos()) {
            if (timer.Elapsed.TotalSeconds > maxSeconds || stack.Count + files.Count >= maxFiles * 2) throw new IOException("Planning entry/time budget exceeded; narrow the selection.");
            if (child.Name.EndsWith(".", StringComparison.Ordinal) || child.Name.EndsWith(" ", StringComparison.Ordinal)) throw new ArgumentException("Ambiguous path segments are not supported.");
            stack.Push(Path.Combine(current, child.Name));
          }
        } else {
          string[] id = Identity(current);
          if (Regex.IsMatch(id[0], ":0+$")) throw new IOException("The filesystem did not provide a stable file identity.");
          int links = Int32.Parse(id[1], System.Globalization.CultureInfo.InvariantCulture);
          if (links != 1) throw new IOException("Hard-linked files require manual review: " + current);
          if (seen.Add(id[0])) {
            files.Add(new PlannedFile { Path = current, FileId = id[0], Links = links, Length = Int64.Parse(id[2], System.Globalization.CultureInfo.InvariantCulture), LastWriteUtc = id[3] });
            if (files.Count > maxFiles) throw new IOException("Planning file limit exceeded; narrow the selection.");
          }
        }
      }
      files.Sort(delegate(PlannedFile a, PlannedFile b) { return StringComparer.OrdinalIgnoreCase.Compare(a.Path, b.Path); });
      return files.ToArray();
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
  Initialize-SyrinNative
  $identity = [Syrin.NativeFiles]::Identity($full)
  if ($identity[0] -match ':0+$') { throw 'The filesystem did not provide a stable file identity.' }
  return [PSCustomObject]@{ FileId=$identity[0]; Length=[long]$identity[2]; LastWriteUtc=$identity[3]; Links=[int]$identity[1] }
}

function Test-SyrinFingerprint([string]$Path, $Expected) {
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  $actual = Get-SyrinFingerprint $Path
  return $actual.FileId -eq $Expected.FileId -and $actual.Length -eq $Expected.Length -and $actual.LastWriteUtc -eq $Expected.LastWriteUtc -and $actual.Links -eq $Expected.Links
}

function ConvertTo-SyrinFileTimeUtc([string]$IsoUtc) {
  return [DateTime]::Parse($IsoUtc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime().ToFileTimeUtc()
}

function Remove-SyrinCheckedFile([string]$Path,$Expected) {
  $full=Assert-SyrinLocalPath $Path
  Initialize-SyrinNative
  [Syrin.NativeFiles]::DeleteChecked($full,$Expected.FileId,[long]$Expected.Length,(ConvertTo-SyrinFileTimeUtc ([string]$Expected.LastWriteUtc)),[uint32]$Expected.Links)
}

function Move-SyrinCheckedFile([string]$Source,[string]$Destination,$Expected) {
  $sourcePath=Assert-SyrinLocalPath $Source;$destinationPath=Assert-SyrinLocalPath $Destination
  Initialize-SyrinNative
  [Syrin.NativeFiles]::MoveChecked($sourcePath,$destinationPath,$Expected.FileId,[long]$Expected.Length,(ConvertTo-SyrinFileTimeUtc ([string]$Expected.LastWriteUtc)),[uint32]$Expected.Links)
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
  if($null -eq $Policy){$Policy=New-SyrinSourcePolicy $CloudRoots}
  Initialize-SyrinNative
  $validated = New-Object 'System.Collections.Generic.List[string]'
  foreach ($p in $Path) { $validated.Add((Assert-SyrinSourcePath $p $CloudRoots -Policy $Policy)) }
  $planned = [Syrin.NativeFiles]::CollectPlanFiles($validated.ToArray(), [string]$Policy.profile, [string[]]$Policy.protected, [string[]]$Policy.cloud, $MaxFiles, $Seconds)
  $files = New-Object 'System.Collections.Generic.List[object]' ($planned.Length)
  foreach ($entry in $planned) {
    $fp = [PSCustomObject]@{ FileId=$entry.FileId; Length=[long]$entry.Length; LastWriteUtc=$entry.LastWriteUtc; Links=[int]$entry.Links }
    $files.Add([PSCustomObject]@{ Path=$entry.Path; Fingerprint=$fp })
  }
  return $files.ToArray()
}

function ConvertTo-SyrinCommandArgument([string]$Value) {
  if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
  $value = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
  $value = [regex]::Replace($value, '(\\+)$', '$1$1')
  return '"' + $value + '"'
}

Export-ModuleMember -Function Get-SyrinOwner,Get-SyrinPath,Test-SyrinWithin,Assert-SyrinLocalPath,Get-SyrinUserFolder,Get-SyrinCloudRoots,New-SyrinSourcePolicy,Assert-SyrinSourcePath,Get-SyrinFingerprint,Test-SyrinFingerprint,Remove-SyrinCheckedFile,Move-SyrinCheckedFile,Get-SyrinDigest,Read-SyrinJson,Read-SyrinJsonDocument,Read-SyrinJsonBatch,Write-SyrinAtomicJson,Write-SyrinAtomicText,Get-SyrinFiles,ConvertTo-SyrinCommandArgument
