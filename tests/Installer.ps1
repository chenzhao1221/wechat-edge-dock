param([Parameter(Mandatory=$true)][string]$FixtureRoot)
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$helper = Join-Path $project 'notify-tools\Manage-Notification.ps1'
$testRoot = Join-Path $project ('work\installer-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$resultPath = Join-Path $testRoot 'result.ini'
$global:EdgeDockFixtureRunning = $false
# Test-only mock. All write targets are uniquely named disposable fixture copies.
function Get-Process { param($Name, $ErrorAction) if ($global:EdgeDockFixtureRunning) { [pscustomobject]@{Name='Weixin'} } }
function Check($action, $expected) {
    & $helper -Action $action -TargetFile $script:target -ResultFile $resultPath
    $resultText = Get-Content -Raw -LiteralPath $resultPath
    if ($resultText -notmatch ('(?m)^State=' + $expected + '\r?$')) { throw "FAIL $action expected $expected : $resultText" }
    Write-Output "PASS $action => $expected"
}
function AssertHash($expected) {
    if ((Get-FileHash -LiteralPath $script:target).Hash -ne $expected) { throw 'Unexpected fixture hash' }
}
$official = '89FC940377A779BABBD64C9CD4ABE6256663681D92F12802AA2DF97A8DB18494'
$anti = '2ABDBCD647AAC934662022885C397A7F1C48D9B3D80F0DB3C2370E0EE74E2EE0'
$newOfficial = 'DB83B719C0A6691528AD3A69E6C0ED00EA035ACAD5FC8FBB31F5A53FBE6CB441'
$newAnti = '4145C6F802DFB44ECE447A173C51424DCBD09C67AABFF6D996CB394ABCDCBE70'
$script:target = Join-Path $testRoot 'Weixin.dll'
Copy-Item -LiteralPath (Join-Path $FixtureRoot 'Official.dll') -Destination $target
Check Status NotInstalled
Check Verify Compatible
$global:EdgeDockFixtureRunning = $true
Check Install Error
AssertHash $official
$global:EdgeDockFixtureRunning = $false
Check Install Installed
Check Install Installed
AssertHash $newOfficial
Check Restore NotInstalled
AssertHash $official
$antiDir = Join-Path $testRoot '9.9.9.9'
New-Item -ItemType Directory -Path $antiDir | Out-Null
$script:target = Join-Path $antiDir 'Weixin.dll'
Copy-Item -LiteralPath (Join-Path $FixtureRoot 'AntiRevoke.dll') -Destination $target
Check Verify Compatible
Check Install Installed
AssertHash $newAnti
Check Restore NotInstalled
AssertHash $anti
# Deliberately different directory version: compatibility follows bytes, not folder name.
Copy-Item -LiteralPath (Join-Path $FixtureRoot 'LegacyNotify.dll') -Destination $target -Force
Check Status UpdateAvailable
Check Install Installed
AssertHash $newAnti
Check Restore NotInstalled
AssertHash $anti
# A damaged backup must block restore and leave the installed DLL intact.
Check Install Installed
$backup = $target + '.before-notify.bak'
$stream = [IO.File]::Open($backup, 'Open', 'ReadWrite')
try { $stream.Position = 100; $old = $stream.ReadByte(); $stream.Position = 100; $stream.WriteByte($old -bxor 1) } finally { $stream.Dispose() }
Check Restore Error
AssertHash $newAnti
# Unknown hash is refused even if code patterns still match.
Copy-Item -LiteralPath (Join-Path $FixtureRoot 'AntiRevoke.dll') -Destination $target -Force
$stream = [IO.File]::Open($target, 'Open', 'ReadWrite')
try { $stream.Position = 100; $old = $stream.ReadByte(); $stream.Position = 100; $stream.WriteByte($old -bxor 1) } finally { $stream.Dispose() }
$unknownHash = (Get-FileHash -LiteralPath $target).Hash
Check Status Unsupported
Check Verify ScanOnly
Check Install Unsupported
AssertHash $unknownHash
Write-Output 'PASS installer fixtures, upgrades and rollback checks'
Write-Output ('Fixtures retained: ' + $testRoot)
