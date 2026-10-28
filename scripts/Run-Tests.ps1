$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'Start-Dock.ps1') -PrepareOnly
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$testDir = Join-Path $project ('work\ahk-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDir -Force | Out-Null
Get-ChildItem -LiteralPath $project -Filter '*.ahk' -File | Copy-Item -Destination $testDir
Copy-Item -LiteralPath (Join-Path $project 'AutoHotkey64.exe') -Destination $testDir
foreach ($folder in @('vendor','tests')) { Copy-Item -LiteralPath (Join-Path $project $folder) -Destination $testDir -Recurse }
$program = Join-Path $testDir 'AutoHotkey64.exe'
foreach ($case in @(
    @{Name='dock'; Args=@('/ErrorStdOut', 'winautohidev2.ahk', '--self-test')},
    @{Name='animation'; Args=@('/ErrorStdOut', 'tests\Animation.ahk')}
)) {
    $output = Join-Path $testDir ($case.Name + '.txt')
    $errorOutput = Join-Path $testDir ($case.Name + '-error.txt')
    $process = Start-Process -FilePath $program -ArgumentList $case.Args -WorkingDirectory $testDir -WindowStyle Hidden -PassThru -RedirectStandardOutput $output -RedirectStandardError $errorOutput
    if (!$process.WaitForExit(45000)) {
        Stop-Process -Id $process.Id
        throw ('Timed out in isolated fixture: ' + $case.Name)
    }
    $process.Refresh()
    Get-Content -LiteralPath $output
    Get-Content -LiteralPath $errorOutput
    if ($process.ExitCode -ne 0) { throw ('Fixture failed: ' + $case.Name) }
}
Write-Output ('PASS all AHK fixtures. Results: ' + $testDir)
