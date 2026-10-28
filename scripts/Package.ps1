param([string]$Version = '0.1.0')
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid release version.' }
$project = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $project 'dist'
$bundleName = 'wechat-edge-dock-v' + $Version + '-windows-x64'
$stageParent = Join-Path $project ('work\package-' + [guid]::NewGuid().ToString('N'))
$stage = Join-Path $stageParent $bundleName
New-Item -ItemType Directory -Path $stage,$dist -Force | Out-Null
Get-ChildItem -LiteralPath $project -File | Where-Object { $_.Extension -in @('.ahk','.md','.cmd') -or $_.Name -in @('LICENSE','AutoHotkey-LICENSE.txt') } | Copy-Item -Destination $stage
foreach ($folder in @('vendor','licenses','scripts','tests','docs')) {
    Copy-Item -LiteralPath (Join-Path $project $folder) -Destination $stage -Recurse
}
$tools = Join-Path $stage 'notify-tools'
New-Item -ItemType Directory -Path $tools | Out-Null
foreach ($file in @('Manage-Notification.ps1','wechat-notify-module.exe','LICENSE')) {
    Copy-Item -LiteralPath (Join-Path $project ('notify-tools\' + $file)) -Destination $tools
}
$source = Join-Path $tools 'source'
New-Item -ItemType Directory -Path $source | Out-Null
foreach ($file in @('Cargo.toml','Cargo.lock','LICENSE','src')) {
    Copy-Item -LiteralPath (Join-Path $project ('notify-tools\source\' + $file)) -Destination $source -Recurse
}
$blocked = Get-ChildItem -LiteralPath $stage -Recurse -File | Where-Object {
    $_.Extension -in @('.dll','.bak','.ini','.log','.pdb') -or
    ($_.Extension -eq '.exe' -and $_.Name -ne 'wechat-notify-module.exe') -or
    $_.FullName -match '\\(data|target|\.git)\\'
}
if ($blocked) { throw ('Unexpected files in package: ' + ($blocked.Name -join ', ')) }
$zip = Join-Path $dist ($bundleName + '.zip')
if (Test-Path -LiteralPath $zip) { throw 'Release ZIP already exists; use a new version or a clean build directory.' }
Compress-Archive -LiteralPath $stage -DestinationPath $zip -CompressionLevel Optimal
$hash = (Get-FileHash -LiteralPath $zip).Hash.ToLowerInvariant()
[IO.File]::WriteAllText($zip + '.sha256', $hash + '  ' + [IO.Path]::GetFileName($zip) + [Environment]::NewLine, [Text.Encoding]::ASCII)
Write-Output $zip
Write-Output ($hash + '  ' + [IO.Path]::GetFileName($zip))
