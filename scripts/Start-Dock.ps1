param([switch]$PrepareOnly)
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$runtime = Join-Path $project 'AutoHotkey64.exe'
$runtimeHash = '5073EE85DA091653C7C6CE32CACDA3A0B4BFB51649823C10015BA0BD71ACB73C'
try {
    if (!(Test-Path -LiteralPath $runtime)) {
        Write-Host 'Downloading official AutoHotkey v2.0.31 (first launch only)...'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $data = Join-Path $project 'data'
        New-Item -ItemType Directory -Path $data -Force | Out-Null
        $scratch = Join-Path $data ('runtime-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $scratch | Out-Null
        try {
            $archive = Join-Path $scratch 'AutoHotkey.zip'
            Invoke-WebRequest -UseBasicParsing 'https://github.com/AutoHotkey/AutoHotkey/releases/download/v2.0.31/AutoHotkey_2.0.31.zip' -OutFile $archive
            if ((Get-FileHash -LiteralPath $archive).Hash -ne 'CA1A595ACA4528755D8D4CD7FED23D497A37BD9A0B6892072612D68DEE1BD00A') { throw 'AutoHotkey archive checksum mismatch.' }
            Expand-Archive -LiteralPath $archive -DestinationPath $scratch
            $extracted = Join-Path $scratch 'AutoHotkey64.exe'
            if ((Get-FileHash -LiteralPath $extracted).Hash -ne $runtimeHash) { throw 'AutoHotkey executable checksum mismatch.' }
            Copy-Item -LiteralPath $extracted -Destination $runtime
        } finally {
            $resolved = [IO.Path]::GetFullPath($scratch)
            if ($resolved.StartsWith([IO.Path]::GetFullPath($data) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                Remove-Item -LiteralPath $resolved -Recurse -Force
            }
        }
    }
    if ((Get-FileHash -LiteralPath $runtime).Hash -ne $runtimeHash) { throw 'AutoHotkey64.exe must be the official v2.0.31 x64 runtime.' }
    if (!$PrepareOnly) {
        Start-Process -FilePath $runtime -ArgumentList ('"' + (Join-Path $project 'Open-Panel.ahk') + '"') -WorkingDirectory $project -WindowStyle Hidden
    }
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
