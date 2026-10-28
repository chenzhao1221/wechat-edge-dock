$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$registry = if ($env:CARGO_HOME) { $env:CARGO_HOME } else { Join-Path $env:USERPROFILE '.cargo' }
$oldFlags = $env:CARGO_ENCODED_RUSTFLAGS
try {
    $env:CARGO_ENCODED_RUSTFLAGS = '--remap-path-prefix=' + $project + '=/workspace' + [char]31 + '--remap-path-prefix=' + $registry + '=/cargo'
    & cargo build --manifest-path (Join-Path $project 'notify-tools\source\Cargo.toml') --release --locked
    if ($LASTEXITCODE -ne 0) { throw 'Rust build failed.' }
    $buildDir = if ($env:CARGO_TARGET_DIR) { $env:CARGO_TARGET_DIR } else { Join-Path $project 'notify-tools\source\target' }
    Copy-Item -LiteralPath (Join-Path $buildDir 'release\wechat-notify-module.exe') -Destination (Join-Path $project 'notify-tools\wechat-notify-module.exe') -Force
    Get-FileHash -LiteralPath (Join-Path $project 'notify-tools\wechat-notify-module.exe')
    Write-Output 'Update the tool checksum in Manage-Notification.ps1 after reviewing this build.'
} finally { $env:CARGO_ENCODED_RUSTFLAGS = $oldFlags }
