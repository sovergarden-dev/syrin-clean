Set-StrictMode -Version 2
Import-Module (Join-Path $PSScriptRoot 'IO.psm1')

function Get-SyrinPolicyPath {
  return Join-Path $env:LOCALAPPDATA 'SyrinClean\policy.json'
}

function Get-SyrinProtection([string]$PolicyFile='',$Expected=$null) {
  $paths=@(Get-SyrinPolicyPath)
  if($PolicyFile){$PolicyFile=Assert-SyrinLocalPath $PolicyFile;$paths+=$PolicyFile}
  if($Expected){foreach($file in $Expected.files){$paths+=Assert-SyrinLocalPath $file.path}}
  $files=New-Object 'System.Collections.Generic.List[object]'
  $protected=New-Object 'System.Collections.Generic.List[string]'
  $mode='approve'
  foreach($path in @($paths | Select-Object -Unique)){
    $expectedFile=@()
    if($Expected){$expectedFile=@($Expected.files | Where-Object {$_.path -eq $path})}
    if(-not(Test-Path -LiteralPath $path)){
      if($path -eq $PolicyFile -or $expectedFile.Count){throw 'A required protection policy is missing. Review a new plan.'}
      continue
    }
    $document=Read-SyrinJsonDocument $path;$value=$document.value
    if($value.schemaVersion -ne 1 -or $value.kind -cne 'syrin-protection-policy' -or $value.ownerSid -ne (Get-SyrinOwner) -or $value.mode -cnotin @('audit','approve') -or $value.protectedPaths -isnot [array]){throw 'Invalid protection policy.'}
    if($expectedFile.Count -and $document.digest -cne $expectedFile[0].digest){throw 'Protection policy changed. Review a new plan.'}
    if($value.mode -eq 'audit'){$mode='audit'}
    foreach($entry in $value.protectedPaths){
      if($entry -isnot [string] -or $entry -notmatch '^[A-Za-z]:[\\/]' -or $entry -match '[*?]'){throw 'Protected paths must be absolute literal drive paths.'}
      $protected.Add((Assert-SyrinLocalPath $entry))
    }
    $files.Add([PSCustomObject]@{path=(Assert-SyrinLocalPath $path);digest=$document.digest})
  }
  return [PSCustomObject]@{mode=$mode;protectedPaths=@($protected | Select-Object -Unique);files=$files.ToArray()}
}

function Set-SyrinProtection([ValidateSet('audit','approve')][string]$Mode,[string[]]$ProtectedPath=@()) {
  $current=Get-SyrinProtection
  if(-not $PSBoundParameters.ContainsKey('ProtectedPath')){$ProtectedPath=@($current.protectedPaths)}
  $paths=@($ProtectedPath | ForEach-Object {
    if($_ -notmatch '^[A-Za-z]:[\\/]' -or $_ -match '[*?]'){throw 'Protected paths must be absolute literal drive paths.'}
    Assert-SyrinLocalPath $_
  } | Select-Object -Unique)
  $target=Assert-SyrinLocalPath (Get-SyrinPolicyPath)
  if(Test-Path -LiteralPath $target){[void](Get-SyrinProtection)}
  [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
  $value=[ordered]@{schemaVersion=1;kind='syrin-protection-policy';ownerSid=(Get-SyrinOwner);mode=$Mode.ToLowerInvariant();protectedPaths=$paths;updatedUtc=[DateTime]::UtcNow.ToString('o')}
  Write-SyrinAtomicJson $target $value
  return [PSCustomObject]@{ok=$true;path=$target;policy=(Get-SyrinProtection)}
}

function Assert-SyrinWriteAllowed($Protection) {
  if($Protection.mode -eq 'audit'){throw 'Audit-only policy blocks file planning and execution. Change the policy only after an explicit user request.'}
}

Export-ModuleMember -Function Get-SyrinProtection,Set-SyrinProtection,Assert-SyrinWriteAllowed
