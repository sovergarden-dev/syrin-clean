param([Parameter(Mandatory=$true)][string]$PromptFile,[Parameter(Mandatory=$true)][string]$OutDir)
$ErrorActionPreference='Stop'
$archive=$null;$stream=$null
try {
  $text=[IO.File]::ReadAllText($PromptFile,[Text.Encoding]::UTF8)
  $match=[regex]::Match($text,'(?ms)^## Runtime bundle \(APPENDIX-RUNTIME\)\r?\nSHA256: ([a-f0-9]{64})\r?\n\r?\n```base64\r?\n([A-Za-z0-9+/=\r\n]+)\r?\n```')
  if(-not $match.Success){throw 'Runtime appendix not found.'}
  $bytes=[Convert]::FromBase64String($match.Groups[2].Value)
  $sha=[Security.Cryptography.SHA256]::Create()
  try{$digest=([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
  if($digest -cne $match.Groups[1].Value){throw 'Runtime bundle checksum mismatch.'}
  $root=[IO.Path]::GetFullPath($OutDir).TrimEnd('\')
  if($root -notmatch '^[A-Za-z]:\\' -or $root.Length -lt 4){throw 'Choose a new local directory.'}
  $cursor=$root
  while($cursor){if(Test-Path -LiteralPath $cursor){if(([int](Get-Item -LiteralPath $cursor -Force).Attributes -band 0x441400) -ne 0){throw 'Reparse or cloud output is blocked.'}};$cursor=[IO.Path]::GetDirectoryName($cursor)}
  if((Test-Path -LiteralPath $root) -and @(Get-ChildItem -LiteralPath $root -Force).Count){throw 'Runtime output directory must be empty.'}
  Add-Type -AssemblyName System.IO.Compression
  $stream=New-Object IO.MemoryStream(,$bytes)
  $archive=New-Object IO.Compression.ZipArchive($stream,[IO.Compression.ZipArchiveMode]::Read)
  if($archive.Entries.Count -gt 128 -or ($archive.Entries|Measure-Object Length -Sum).Sum -gt 20MB){throw 'Runtime bundle exceeds its supported size.'}
  foreach($entry in $archive.Entries){
    if($entry.FullName -match '(^|[/\\])\.\.([/\\]|$)' -or [IO.Path]::IsPathRooted($entry.FullName) -or $entry.FullName.Contains(':') -or (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000){throw 'Unsafe archive entry.'}
    $target=[IO.Path]::GetFullPath((Join-Path $root $entry.FullName))
    if(-not $target.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Archive entry escaped output directory.'}
  }
  [void][IO.Directory]::CreateDirectory($root)
  foreach($entry in $archive.Entries){
    $target=[IO.Path]::GetFullPath((Join-Path $root $entry.FullName))
    if($entry.FullName.EndsWith('/')){[void][IO.Directory]::CreateDirectory($target);continue}
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
    $entryStream=$entry.Open();$outputStream=[IO.File]::Open($target,[IO.FileMode]::CreateNew)
    try{$entryStream.CopyTo($outputStream);$outputStream.Flush($true)}finally{$outputStream.Dispose();$entryStream.Dispose()}
  }
  [PSCustomObject]@{ok=$true;runtimeRoot=(Join-Path $root 'syrin-clean');sha256=$digest;message='Use a separate empty audit directory or let audit.ps1 choose its default session directory.'}|ConvertTo-Json
} catch {[PSCustomObject]@{ok=$false;error=$_.Exception.Message}|ConvertTo-Json -Compress;exit 2}
finally{if($archive){$archive.Dispose()};if($stream){$stream.Dispose()}}
