Set-StrictMode -Version 2
Import-Module (Join-Path $PSScriptRoot 'IO.psm1')

function Get-SyrinRootPath([string]$Root) {
  if (-not $Root) { $Root = Join-Path $env:LOCALAPPDATA 'SyrinClean\Quarantine' }
  return Assert-SyrinSourcePath $Root @(Get-SyrinCloudRoots)
}

function Read-SyrinRoot([string]$Root) {
  $rootPath = Get-SyrinRootPath $Root
  $markerPath = Join-Path $rootPath '.syrin-clean-root.json'
  if (-not (Test-Path -LiteralPath $markerPath)) { throw 'Unowned root. Use a new empty root; import legacy CSV explicitly.' }
  [void](Assert-SyrinLocalPath $markerPath)
  $marker = Read-SyrinJson $markerPath
  if ($marker.schemaVersion -ne 1 -or $marker.kind -ne 'syrin-quarantine' -or $marker.ownerSid -ne (Get-SyrinOwner) -or $marker.rootId -notmatch '^[a-f0-9]{32}$') { throw 'Invalid root marker or different owner.' }
  return $marker
}

function Initialize-SyrinRoot([string]$Root) {
  $rootPath = Get-SyrinRootPath $Root
  if (Test-Path -LiteralPath (Join-Path $rootPath '.syrin-clean-root.json')) { return Read-SyrinRoot $rootPath }
  if ((Test-Path -LiteralPath $rootPath) -and @(Get-ChildItem -LiteralPath $rootPath -Force -ErrorAction Stop).Count) { throw 'Refusing to adopt a non-empty directory.' }
  [void][IO.Directory]::CreateDirectory($rootPath)
  $sid = Get-SyrinOwner
  $acl = New-Object Security.AccessControl.DirectorySecurity
  $acl.SetAccessRuleProtection($true,$false)
  foreach ($identity in @($sid,'S-1-5-18')) {
    $rule = New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier($identity)), 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
  }
  Set-Acl -LiteralPath $rootPath -AclObject $acl -ErrorAction Stop
  $marker = [ordered]@{schemaVersion=1;kind='syrin-quarantine';ownerSid=$sid;rootId=[guid]::NewGuid().ToString('N');createdUtc=[DateTime]::UtcNow.ToString('o')}
  Write-SyrinAtomicJson (Join-Path $rootPath '.syrin-clean-root.json') $marker -CreateOnly
  return [PSCustomObject]$marker
}

function Open-SyrinRootLock([string]$Root) {
  $path = Assert-SyrinLocalPath (Join-Path $Root '.syrin-clean.lock')
  try { return New-Object IO.FileStream($path,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) }
  catch { throw 'Another operation owns this root. Retry after it finishes.' }
}

function Get-SyrinSessionPath([string]$Root,[string]$SessionId) {
  if ($SessionId -notmatch '^[a-f0-9]{32}$') { throw 'Invalid session ID.' }
  return Assert-SyrinLocalPath (Join-Path (Join-Path $Root 'sessions') $SessionId)
}

function Read-SyrinSession([string]$Root,[string]$SessionId) {
  $marker = Read-SyrinRoot $Root
  $folder = Get-SyrinSessionPath $Root $SessionId
  $header = Read-SyrinJson (Join-Path $folder 'session.json')
  if ($header.schemaVersion -ne 1 -or $header.ownerSid -ne (Get-SyrinOwner) -or $header.rootId -ne $marker.rootId -or $header.sessionId -ne $SessionId) { throw 'Invalid session identity.' }
  $document=Read-SyrinJsonDocument (Join-Path $folder 'plan.json')
  if ($document.digest -ne $header.planDigest) { throw 'Session plan integrity check failed.' }
  $plan=$document.value
  $items = @{}
  foreach ($item in @($plan.items)) {
    if ($item.id -notmatch '^[a-f0-9]{32}$' -or $items.ContainsKey($item.id)) { throw 'Invalid item identity.' }
    $items[$item.id] = [PSCustomObject]@{id=$item.id;code=$item.code;original=$item.original;stored=$item.stored;fingerprint=$item.fingerprint;state='planned';error='';restoredPath=''}
  }
  $sequence=0; $previous=''
  $eventsPath = Assert-SyrinLocalPath (Join-Path $folder 'events')
  foreach ($file in @(Get-ChildItem -LiteralPath $eventsPath -File -Filter '*.json' -ErrorAction Stop | Sort-Object Name)) {
    $document=Read-SyrinJsonDocument $file.FullName
    $event=$document.value
    $sequence++
    if ($file.Name -ne ('{0:D8}.json' -f $sequence) -or $event.sequence -ne $sequence -or $event.previous -ne $previous -or -not $items.ContainsKey($event.itemId)) { throw 'Journal sequence or integrity check failed.' }
    if ($event.state -notin @('planned','moving','quarantined','restoring','restored','conflict','failed','purging','purged')) { throw 'Unknown journal state.' }
    $item = $items[$event.itemId]
    $item.state=$event.state; $item.error=$event.error; $item.restoredPath=$event.restoredPath
    $previous=$document.digest
  }
  return [PSCustomObject]@{folder=$folder;header=$header;plan=$plan;items=$items;sequence=$sequence;digest=$previous}
}

function Add-SyrinEvent($Session,[string]$ItemId,[string]$State,[string]$ErrorText='',[string]$RestoredPath='') {
  $n = $Session.sequence + 1
  $event = [ordered]@{schemaVersion=1;sequence=$n;previous=$Session.digest;itemId=$ItemId;state=$State;error=$ErrorText;restoredPath=$RestoredPath;timeUtc=[DateTime]::UtcNow.ToString('o')}
  $path = Join-Path (Join-Path $Session.folder 'events') ('{0:D8}.json' -f $n)
  Write-SyrinAtomicJson $path $event -CreateOnly
  $Session.sequence=$n; $Session.digest=Get-SyrinDigest ([IO.File]::ReadAllBytes($path))
  $Session.items[$ItemId].state=$State; $Session.items[$ItemId].error=$ErrorText; $Session.items[$ItemId].restoredPath=$RestoredPath
}

function Get-SyrinStoredPath($Session,$Item,[string]$Root) {
  $path = Assert-SyrinLocalPath $Item.stored
  if ($Session.plan.operation -eq 'import') {
    $legacy = Assert-SyrinLocalPath $Session.plan.legacyRoot
    $relative = $path.Substring($legacy.TrimEnd('\').Length).TrimStart('\')
    if (-not (Test-SyrinWithin $path $legacy) -or $relative -notmatch '^\d{8}-\d{6}\\') { throw 'Legacy stored path escaped its timestamp directory.' }
  } else {
    $expected = Join-Path (Join-Path $Session.folder 'files') $Item.id
    if (-not $path.Equals($expected,[StringComparison]::OrdinalIgnoreCase)) { throw 'Stored path is not owned by this item.' }
  }
  if ($path -eq (Get-SyrinPath $Root)) { throw 'A root is not a stored file.' }
  return $path
}

function New-SyrinFilePlan {
  param([ValidateSet('quarantine','restore','purge','resume','import')][string]$Operation='quarantine',[string[]]$Path=@(),[string]$Root='',[string]$SessionId='',[string[]]$ItemId=@(),[ValidateSet('skip','rename')][string]$Conflict='skip',[string]$RestoreDirectory='', [string]$LegacyRoot='',[string]$PlanFile='')
  $Operation=$Operation.ToLowerInvariant();$Conflict=$Conflict.ToLowerInvariant()
  $rootPath=Get-SyrinRootPath $Root
  $rootId=$null
  if (Test-Path -LiteralPath (Join-Path $rootPath '.syrin-clean-root.json')) { $rootId=(Read-SyrinRoot $rootPath).rootId }
  elseif ((Test-Path -LiteralPath $rootPath) -and @(Get-ChildItem -LiteralPath $rootPath -Force).Count) { throw 'Choose an empty owned quarantine root.' }
  $cloud=@(Get-SyrinCloudRoots)
  $policy=New-SyrinSourcePolicy $cloud
  $planId=[guid]::NewGuid().ToString('N')
  $items=New-Object 'System.Collections.Generic.List[object]'
  if ($Operation -in @('quarantine','import')) { $SessionId=$planId }
  $sessionFolder=Get-SyrinSessionPath $rootPath $SessionId
  if ($Operation -eq 'quarantine') {
    if (-not $Path.Count) { throw 'Select at least one file or directory.' }
    foreach($selection in $Path){$selection=Assert-SyrinSourcePath $selection $cloud -Policy $policy;if((Test-SyrinWithin $selection $rootPath) -or (Test-SyrinWithin $rootPath $selection)){throw 'Source selection and quarantine storage cannot overlap.'}}
    foreach ($file in @(Get-SyrinFiles $Path $cloud -Policy $policy)) {
      if ((Test-SyrinWithin $file.Path $rootPath) -or (Test-SyrinWithin $rootPath $file.Path)) { throw 'Source and quarantine storage cannot overlap.' }
      if ([IO.Path]::GetPathRoot($file.Path) -ne [IO.Path]::GetPathRoot($rootPath)) { throw 'Choose a quarantine root on the same volume. Cross-volume copy-and-delete is unsupported.' }
      $id=[guid]::NewGuid().ToString('N')
      $items.Add([PSCustomObject]@{id=$id;original=$file.Path;stored=(Join-Path (Join-Path $sessionFolder 'files') $id);fingerprint=$file.Fingerprint;destination='';expectedState='planned'})
    }
  } elseif ($Operation -eq 'import') {
    $LegacyRoot=Assert-SyrinLocalPath $LegacyRoot
    if ([IO.Path]::GetFileName($LegacyRoot) -notin @('Syrin-Clean-Quarantine','PC-Optimize-Quarantine')) { throw 'Only named legacy quarantine roots can be imported.' }
    if ((Test-SyrinWithin $rootPath $LegacyRoot) -or (Test-SyrinWithin $LegacyRoot $rootPath)) { throw 'Import into a separate new root; legacy metadata is not rewritten.' }
    $seen=New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($csv in @(Get-ChildItem -LiteralPath $LegacyRoot -File -Filter 'manifest*.csv' -ErrorAction Stop)) {
      [void](Assert-SyrinLocalPath $csv.FullName)
      foreach ($row in @(Import-Csv -LiteralPath $csv.FullName -Encoding UTF8 -ErrorAction Stop)) {
        $stored=Assert-SyrinLocalPath $row.Stored
        if (-not (Test-SyrinWithin $stored $LegacyRoot) -or $stored.Substring($LegacyRoot.Length).TrimStart('\') -notmatch '^\d{8}-\d{6}\\') { throw 'Unsafe stored path in legacy CSV.' }
        if (-not (Test-Path -LiteralPath $stored)) { continue }
        $original=Assert-SyrinSourcePath $row.Original $cloud
        $fp=Get-SyrinFingerprint $stored
        if ($seen.Add($fp.FileId)) { $items.Add([PSCustomObject]@{id=[guid]::NewGuid().ToString('N');original=$original;stored=$stored;fingerprint=$fp;destination='';expectedState='planned'}) }
      }
    }
  } else {
    $session=Read-SyrinSession $rootPath $SessionId
    if (-not $ItemId.Count) { throw 'Select explicit item IDs from History.' }
    foreach ($id in $ItemId) {
      if (-not $session.items.ContainsKey($id)) { throw "Unknown item ID: $id" }
      $item=$session.items[$id]
      $stored=Get-SyrinStoredPath $session $item $rootPath
      if ($Operation -eq 'purge' -and $session.plan.operation -eq 'import') { throw 'Imported legacy items support restore only. Restore and quarantine with the current engine before purging.' }
      if ($Operation -eq 'purge' -and $item.state -notin @('quarantined','conflict','failed')) { throw 'Only stored items can be planned for purge.' }
      if ($Operation -in @('restore','purge') -and -not (Test-SyrinFingerprint $stored $item.fingerprint)) { throw "Stored file changed or is missing: $id" }
      $destination=$item.original
      if ($RestoreDirectory) { $destination=Join-Path (Assert-SyrinSourcePath $RestoreDirectory $cloud) ([IO.Path]::GetFileName($item.original)) }
      if ($Operation -eq 'restore') {
        $destination=Assert-SyrinSourcePath $destination $cloud
        if (Test-SyrinWithin $destination $rootPath) { throw 'Restore destination cannot be inside quarantine storage.' }
        if ([IO.Path]::GetPathRoot($destination) -ne [IO.Path]::GetPathRoot($stored)) { throw 'Restore must stay on the same volume.' }
        if ((Test-Path -LiteralPath $destination) -and $Conflict -eq 'rename') {
          $destination=Join-Path ([IO.Path]::GetDirectoryName($destination)) (([IO.Path]::GetFileNameWithoutExtension($destination))+' (restored '+$id.Substring(0,8)+')'+[IO.Path]::GetExtension($destination))
          if (Test-Path -LiteralPath $destination) { throw 'The proposed renamed destination also exists. Choose another recovery directory.' }
        }
      }
      $items.Add([PSCustomObject]@{id=$id;original=$item.original;stored=$stored;fingerprint=$item.fingerprint;destination=$destination;expectedState=$item.state})
    }
  }
  if (-not $items.Count) { throw 'No regular files were selected.' }
  $prefix=@{quarantine='Q';restore='R';purge='P';resume='S';import='I'}[$Operation]
  for($index=0;$index -lt $items.Count;$index++){$items[$index]|Add-Member -NotePropertyName code -NotePropertyValue ($prefix+($index+1))}
  $plan=[ordered]@{schemaVersion=1;kind='syrin-file-plan';planId=$planId;sessionId=$SessionId;operation=$Operation;ownerSid=(Get-SyrinOwner);root=$rootPath;rootId=$rootId;legacyRoot=$LegacyRoot;createdUtc=[DateTime]::UtcNow.ToString('o');conflict=$Conflict;items=$items.ToArray();measuredBytes=[long](($items | ForEach-Object {$_.fingerprint.Length} | Measure-Object -Sum).Sum);estimatedReclaimableBytes=$null;warnings=@('No content was read. File identity and metadata are checked again before execution.','Unknown cloud-provider locations must be excluded explicitly.');}
  if ($Operation -eq 'quarantine') { $plan.estimatedReclaimableBytes=0 }
  if ($Operation -eq 'purge') { $plan.estimatedReclaimableBytes=$plan.measuredBytes; $plan.warnings+= 'Purge is irreversible. Logical file length is only an estimate of disk space recovered.' }
  if (-not $PlanFile) { return [PSCustomObject]@{ok=$true;previewOnly=$true;plan=[PSCustomObject]$plan;approval=$null} }
  $planPath=Assert-SyrinLocalPath $PlanFile
  if (Test-SyrinWithin $planPath $rootPath) { throw 'Keep the plan in the working directory, outside quarantine storage.' }
  if($Operation -eq 'quarantine'){foreach($selection in $Path){if(Test-SyrinWithin $planPath (Get-SyrinPath $selection)){throw 'Keep the plan outside the selected source files and directories.'}}}
  if(Test-Path -LiteralPath $planPath){$existing=Read-SyrinJson $planPath;if(-not $existing.PSObject.Properties['kind'] -or $existing.kind -ne 'syrin-file-plan'){throw 'Refusing to overwrite a file that is not a Syrin clean plan.'}}
  Write-SyrinAtomicJson $planPath $plan
  return [PSCustomObject]@{ok=$true;planFile=$planPath;approval=(Get-SyrinDigest ([IO.File]::ReadAllBytes($planPath)));plan=[PSCustomObject]$plan}
}

function New-SyrinSession([string]$Root,$Marker,$Plan,[string]$PlanFile) {
  $folder=Get-SyrinSessionPath $Root $Plan.sessionId
  [void][IO.Directory]::CreateDirectory($folder)
  foreach ($name in @('events','files','approvals')) { [void][IO.Directory]::CreateDirectory((Join-Path $folder $name)) }
  $planText=[IO.File]::ReadAllText($PlanFile,[Text.Encoding]::UTF8)
  Write-SyrinAtomicText (Join-Path $folder 'plan.json') $planText -CreateOnly
  $digest=Get-SyrinDigest ([IO.File]::ReadAllBytes((Join-Path $folder 'plan.json')))
  $header=[ordered]@{schemaVersion=1;sessionId=$Plan.sessionId;rootId=$Marker.rootId;ownerSid=(Get-SyrinOwner);createdUtc=$Plan.createdUtc;planDigest=$digest}
  Write-SyrinAtomicJson (Join-Path $folder 'session.json') $header -CreateOnly
  return Read-SyrinSession $Root $Plan.sessionId
}

function Invoke-SyrinFilePlan {
  param([string]$PlanFile,[string]$Approval,[string[]]$ItemId)
  $planPath=Assert-SyrinLocalPath $PlanFile
  $digest=Get-SyrinDigest ([IO.File]::ReadAllBytes($planPath))
  if ($Approval -notmatch '^[a-f0-9]{64}$' -or $digest -cne $Approval) { throw 'Approval digest does not match. Review the current plan again.' }
  $plan=Read-SyrinJson $planPath
  if ($plan.schemaVersion -ne 1 -or $plan.kind -ne 'syrin-file-plan' -or $plan.ownerSid -ne (Get-SyrinOwner)) { throw 'Invalid plan schema or owner.' }
  if ($plan.operation -notin @('quarantine','restore','purge','resume','import')) { throw 'Unsupported operation.' }
  if (-not $ItemId.Count -or @($ItemId | Select-Object -Unique).Count -ne $ItemId.Count) { throw 'An explicit unique selection of item IDs is required.' }
  $selected=@($plan.items | Where-Object {$_.id -in $ItemId})
  if ($selected.Count -ne $ItemId.Count) { throw 'Selection contains an item outside this plan.' }
  $root=Get-SyrinRootPath $plan.root
  $marker=Initialize-SyrinRoot $root
  if ($plan.rootId -and $plan.rootId -ne $marker.rootId) { throw 'Root identity changed after planning.' }
  $lock=Open-SyrinRootLock $root
  $outcomes=New-Object 'System.Collections.Generic.List[object]'
  try {
    $folder=Get-SyrinSessionPath $root $plan.sessionId
    if (Test-Path -LiteralPath (Join-Path $folder 'session.json')) { $session=Read-SyrinSession $root $plan.sessionId }
    elseif ($plan.operation -in @('quarantine','import')) { $session=New-SyrinSession $root $marker $plan $planPath }
    else { throw 'Session does not exist.' }
    if ($plan.operation -in @('quarantine','import') -and $session.plan.planId -ne $plan.planId) { throw 'Session plan mismatch.' }
    foreach($requested in $selected){
      if(-not $session.items.ContainsKey($requested.id)){throw 'An item is not part of the source session.'}
      $current=$session.items[$requested.id]
      $repeat=($plan.operation -in @('quarantine','import') -and $current.state -eq 'quarantined') -or ($plan.operation -eq 'restore' -and $current.state -eq 'restored') -or ($plan.operation -eq 'purge' -and $current.state -eq 'purged')
      if($current.state -ne $requested.expectedState -and -not $repeat){throw 'Session state changed after planning; create and review a new plan.'}
      if($requested.original -ne $current.original -or $requested.stored -ne $current.stored -or $requested.fingerprint.FileId -ne $current.fingerprint.FileId){throw 'Item identity differs from its source session.'}
    }
    $receipt=Join-Path (Join-Path $session.folder 'approvals') ([guid]::NewGuid().ToString('N')+'.json')
    Write-SyrinAtomicJson $receipt ([ordered]@{plan=$plan;digest=$digest;selected=$ItemId;timeUtc=[DateTime]::UtcNow.ToString('o')}) -CreateOnly
    $cloud=@(Get-SyrinCloudRoots)
    $policy=New-SyrinSourcePolicy $cloud
    foreach ($requested in $selected) {
      if (-not $session.items.ContainsKey($requested.id)) { throw 'Selected item is not part of the source session.' }
      $item=$session.items[$requested.id]
      $stored=Get-SyrinStoredPath $session $item $root
      $state=$item.state; $errorText=''
      try {
        if ($requested.original -ne $item.original -or $requested.stored -ne $item.stored -or $requested.fingerprint.FileId -ne $item.fingerprint.FileId) { throw 'Item changed since planning.' }
        if ($plan.operation -eq 'import') {
          if (-not (Test-SyrinFingerprint $stored $item.fingerprint)) { throw 'Legacy file identity changed.' }
          Add-SyrinEvent $session $item.id 'quarantined'
        } elseif ($plan.operation -eq 'quarantine') {
          [void](Assert-SyrinSourcePath $item.original $cloud -Policy $policy)
          if ((Test-SyrinWithin $item.original $root) -or (Test-SyrinWithin $root $item.original)) { throw 'Source overlaps storage.' }
          if ([IO.Path]::GetPathRoot($stored) -ne [IO.Path]::GetPathRoot($item.original)) { throw 'Cross-volume transfers are unsupported.' }
          if ($item.state -eq 'quarantined' -and (Test-SyrinFingerprint $stored $item.fingerprint)) { $outcomes.Add([PSCustomObject]@{id=$item.id;state='quarantined';error='';unchanged=$true}); continue }
          if (-not (Test-SyrinFingerprint $item.original $item.fingerprint) -or (Test-Path -LiteralPath $stored)) { throw 'Source changed or destination exists. Use a new plan or Resume.' }
          Add-SyrinEvent $session $item.id 'moving'
          [void](Assert-SyrinLocalPath $stored)
          if(-not (Test-SyrinFingerprint $item.original $item.fingerprint)){throw 'Source changed while preparing the journal.'}
          Move-SyrinCheckedFile $item.original $stored $item.fingerprint
          try { if(-not (Test-SyrinFingerprint $stored $item.fingerprint)){throw 'Source changed during transfer.'}; Add-SyrinEvent $session $item.id 'quarantined' }
          catch {
            if (-not (Test-Path -LiteralPath $item.original) -and (Test-SyrinFingerprint $stored $item.fingerprint)) { Move-SyrinCheckedFile $stored $item.original $item.fingerprint }
            throw 'Journal commit failed after move. Original was restored when safe; use Resume to reconcile.'
          }
        } elseif ($plan.operation -eq 'restore') {
          if ($item.state -eq 'restored' -and $item.restoredPath -eq $requested.destination -and -not (Test-Path -LiteralPath $stored)) { $outcomes.Add([PSCustomObject]@{id=$item.id;state='restored';error='';unchanged=$true}); continue }
          if (-not (Test-SyrinFingerprint $stored $item.fingerprint)) { throw 'Stored file changed or is missing.' }
          $destination=Assert-SyrinSourcePath $requested.destination $cloud -Policy $policy
          if (Test-SyrinWithin $destination $root) { throw 'Restore destination overlaps storage.' }
          if ([IO.Path]::GetPathRoot($destination) -ne [IO.Path]::GetPathRoot($stored)) { throw 'Cross-volume restore is unsupported.' }
          if (Test-Path -LiteralPath $destination) { Add-SyrinEvent $session $item.id 'conflict' 'Destination already exists.'; $outcomes.Add([PSCustomObject]@{id=$item.id;state='conflict';error='Destination already exists.'}); continue }
          [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
          [void](Assert-SyrinSourcePath $destination $cloud -Policy $policy)
          Add-SyrinEvent $session $item.id 'restoring' '' $destination
          if(-not (Test-SyrinFingerprint $stored $item.fingerprint)){throw 'Stored file changed while preparing restore.'}
          Move-SyrinCheckedFile $stored $destination $item.fingerprint
          try { Add-SyrinEvent $session $item.id 'restored' '' $destination }
          catch { throw 'Restore completed but its journal commit failed. Use Resume; do not repeat the move.' }
        } elseif ($plan.operation -eq 'purge') {
          if ($session.plan.operation -eq 'import') { throw 'Legacy imports cannot be purged.' }
          if ($item.state -eq 'purged' -and -not (Test-Path -LiteralPath $stored)) { $outcomes.Add([PSCustomObject]@{id=$item.id;state='purged';error='';unchanged=$true}); continue }
          if (-not (Test-SyrinFingerprint $stored $item.fingerprint)) { throw 'Stored file changed or is missing.' }
          Add-SyrinEvent $session $item.id 'purging'
          [void](Assert-SyrinLocalPath $stored)
          Remove-SyrinCheckedFile $stored $item.fingerprint
          Add-SyrinEvent $session $item.id 'purged'
        } else {
          if($item.state -in @('restored','purged')){$outcomes.Add([PSCustomObject]@{id=$item.id;state=$item.state;error='';unchanged=$true});continue}
          if ($item.state -eq 'moving' -and (Test-SyrinFingerprint $stored $item.fingerprint) -and -not (Test-Path -LiteralPath $item.original)) { Add-SyrinEvent $session $item.id 'quarantined' }
          elseif ($item.state -in @('moving','failed') -and (Test-SyrinFingerprint $item.original $item.fingerprint) -and -not (Test-Path -LiteralPath $stored)) { Add-SyrinEvent $session $item.id 'planned' }
          elseif ($item.state -eq 'restoring' -and $item.restoredPath -and (Test-SyrinFingerprint $item.restoredPath $item.fingerprint) -and -not (Test-Path -LiteralPath $stored)) { Add-SyrinEvent $session $item.id 'restored' '' $item.restoredPath }
          elseif ($item.state -in @('moving','restoring','purging','quarantined','conflict','failed') -and (Test-SyrinFingerprint $stored $item.fingerprint)) { Add-SyrinEvent $session $item.id 'quarantined' }
          else { throw 'State is ambiguous. No file was moved or deleted; inspect history and the recorded paths.' }
        }
        $state=$session.items[$item.id].state
      } catch {
        $errorText=$_.Exception.Message
        $state=$session.items[$item.id].state
        if ($state -notin @('moving','restoring','purging','restored','purged')) {
          try { Add-SyrinEvent $session $item.id 'failed' $errorText; $state='failed' } catch { $errorText+=' Journal error: '+$_.Exception.Message }
        }
      }
      $outcomes.Add([PSCustomObject]@{id=$item.id;state=$state;error=$errorText})
      if ($errorText) { break }
    }
  } finally { $lock.Dispose() }
  $ok=@($outcomes | Where-Object {$_.error -or $_.state -eq 'conflict'}).Count -eq 0 -and $outcomes.Count -eq $selected.Count
  return [PSCustomObject]@{ok=$ok;schemaVersion=1;sessionId=$plan.sessionId;operation=$plan.operation;root=$root;items=$outcomes.ToArray();unprocessed=@($ItemId | Where-Object {$_ -notin @($outcomes | ForEach-Object {$_.id})})}
}

function Get-SyrinHistory([string]$Root='',[string]$SessionId='') {
  $rootPath=Get-SyrinRootPath $Root
  if (-not (Test-Path -LiteralPath $rootPath)) { return @() }
  [void](Read-SyrinRoot $rootPath)
  $sessionsPath=Join-Path $rootPath 'sessions'
  if (-not (Test-Path -LiteralPath $sessionsPath)) { return @() }
  $ids=if ($SessionId) {@($SessionId)} else {@(Get-ChildItem -LiteralPath $sessionsPath -Directory | ForEach-Object {$_.Name})}
  foreach ($id in $ids) {
    try {
      $session=Read-SyrinSession $rootPath $id
      [PSCustomObject]@{ok=$true;sessionId=$id;createdUtc=$session.header.createdUtc;operation=$session.plan.operation;items=@($session.items.Values | Sort-Object original)}
    } catch { [PSCustomObject]@{ok=$false;sessionId=$id;error=$_.Exception.Message;items=@()} }
  }
}

Export-ModuleMember -Function New-SyrinFilePlan,Invoke-SyrinFilePlan,Get-SyrinHistory
