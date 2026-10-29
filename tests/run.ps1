$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
Push-Location $project
try {
  $files=@(Get-ChildItem -LiteralPath 'src','tests' -Recurse -File | Where-Object {$_.Extension -in @('.ps1','.psm1')})
  foreach($file in $files){$tokens=$null;$errors=$null;[System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)|Out-Null;if($errors){throw ($errors|Out-String)}}
  python -B -X utf8 tools/build.py --check
  if($LASTEXITCODE){throw 'Build parity failed'}
  node tests/report.mjs
  if($LASTEXITCODE){throw 'Report tests failed'}
  foreach($name in @('quarantine.ps1','runtime.ps1','scale.ps1')){
    & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $name)
    if($LASTEXITCODE){throw "Runtime tests failed: $name"}
  }
  python -B -X utf8 -m unittest discover -s tests -p 'test_*.py' -v
  if($LASTEXITCODE){throw 'Package tests failed'}
  Write-Output 'All checks passed. System/VM and hardware qualification remains separate.'
} finally {Pop-Location}
