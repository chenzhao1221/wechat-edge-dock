param(
    [ValidateSet('Status','Verify','Install','Restore')][string]$Action = 'Status',
    [Parameter(Mandatory=$true)][string]$TargetFile,
    [Parameter(Mandatory=$true)][string]$ResultFile
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$original = '89FC940377A779BABBD64C9CD4ABE6256663681D92F12802AA2DF97A8DB18494'
$antiRevoke = '2ABDBCD647AAC934662022885C397A7F1C48D9B3D80F0DB3C2370E0EE74E2EE0'
$patchedOriginal = 'DB83B719C0A6691528AD3A69E6C0ED00EA035ACAD5FC8FBB31F5A53FBE6CB441'
$patchedAntiRevoke = '4145C6F802DFB44ECE447A173C51424DCBD09C67AABFF6D996CB394ABCDCBE70'
$legacyOriginal = '199091D2AB8F082D71DF1374FB1389878BF25A2DAAA6290ECFE7E91D86C0A204'
$legacyAntiRevoke = '18F4AF9488095B989F91E0D569D390AFE4EE1CADB632DEBA11A03CBC63F1F556'
$toolExpectedHash = 'FAE73E2E535CDD0F95462C422D4618BE5634FA14A3CDFA18695E1747D51EBF5F'
$baseHashes = @($original, $antiRevoke)
$installedHashes = @($patchedOriginal, $patchedAntiRevoke, $legacyOriginal, $legacyAntiRevoke)
$result = @{ State='Error'; Message='Operation failed'; Hash=''; Backup=''; Version='' }
$stagingFile = $null
$swapBackup = $null
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Find-Backup([string]$Dll) {
    $candidates = @($Dll + '.before-notify.bak')
    $candidates += @(Get-ChildItem -LiteralPath (Split-Path -Parent $Dll) -Filter 'Weixin.dll.before-notify-*.bak' -File | Select-Object -ExpandProperty FullName)
    foreach ($candidate in $candidates) {
        if ((Test-Path -LiteralPath $candidate -PathType Leaf) -and ((Hash $candidate) -in $baseHashes)) {
            return $candidate
        }
    }
    return ''
}
try {
    $TargetFile = (Resolve-Path -LiteralPath $TargetFile).Path
    if ([IO.Path]::GetFileName($TargetFile) -ine 'Weixin.dll') { throw 'Please select Weixin.dll.' }
    $currentHash = Hash $TargetFile
    $result.Version = [Diagnostics.FileVersionInfo]::GetVersionInfo($TargetFile).FileVersion
    $result.Hash = $currentHash
    $backup = Find-Backup $TargetFile
    $result.Backup = $backup
    if ($Action -eq 'Verify' -and $currentHash -notin $installedHashes) {
        $tool = Join-Path $PSScriptRoot 'wechat-notify-module.exe'
        if (!(Test-Path -LiteralPath $tool -PathType Leaf) -or (Hash $tool) -ne $toolExpectedHash) {
            throw 'Notification patch tool verification failed.'
        }
        # Work on a separate copy in the result directory. No write to the selected DLL.
        $probeInput = Join-Path (Split-Path -Parent $ResultFile) ('probe-' + [guid]::NewGuid().ToString('N') + '.dll')
        $stagingFile = $probeInput + '.patched'
        try {
            Copy-Item -LiteralPath $TargetFile -Destination $probeInput
            if ((Hash $probeInput) -ne $currentHash) { throw 'DLL changed while preparing compatibility check.' }
            $toolOutput = & $tool patch-copy $probeInput $stagingFile 2>&1
            if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $stagingFile)) {
                $result.State = 'Incompatible'
                $result.Message = 'Required functions, code patterns or patch regions did not match.'
            } elseif ($currentHash -in $baseHashes) {
                $expectedHash = if ($currentHash -eq $original) { $patchedOriginal } else { $patchedAntiRevoke }
                if ((Hash $stagingFile) -ne $expectedHash) { throw 'Structural scan produced an unexpected patch.' }
                $result.State = 'Compatible'
                $result.Message = 'Code scan and expected output hash both verified. Installation is supported.'
            } else {
                $result.State = 'ScanOnly'
                $result.Message = 'Patch structure matched, but this DLL is not a tested build. One-click installation remains unavailable.'
            }
        } finally {
            if (Test-Path -LiteralPath $probeInput) { Remove-Item -LiteralPath $probeInput }
        }
    } elseif ($currentHash -notin ($baseHashes + $installedHashes)) {
        $result.State = 'Unsupported'
        $result.Message = 'DLL fingerprint does not match a verified patch profile. Directory version names are not used for compatibility.'
        if ($Action -ne 'Status') { throw $result.Message }
    } elseif ($Action -in @('Status','Verify')) {
        $result.State = if ($currentHash -in $installedHashes) { 'Installed' } else { 'NotInstalled' }
        if ($currentHash -in @($legacyOriginal, $legacyAntiRevoke)) { $result.State = 'UpdateAvailable' }
        $result.Message = 'Status checked.'
    } else {
        if (Get-Process Weixin,WeChat -ErrorAction SilentlyContinue) {
            throw 'Exit WeChat normally before installing or restoring. No process was stopped.'
        }
        if ($Action -eq 'Install' -and $currentHash -in @($patchedOriginal, $patchedAntiRevoke)) {
            $result.State = 'Installed'
            $result.Message = 'Already installed.'
        } elseif ($Action -eq 'Restore' -and $currentHash -in $baseHashes) {
            $result.State = 'NotInstalled'
            $result.Message = 'Already restored.'
        } else {
            $directory = Split-Path -Parent $TargetFile
            $stagingFile = Join-Path $directory ('Weixin.notify-' + [guid]::NewGuid().ToString('N') + '.tmp')
            $swapBackup = $stagingFile + '.previous'
            if ($Action -eq 'Install') {
                $baseSource = $TargetFile
                $baselineHash = $currentHash
                if ($currentHash -in @($legacyOriginal, $legacyAntiRevoke)) {
                    $requiredHash = if ($currentHash -eq $legacyAntiRevoke) { $antiRevoke } else { $original }
                    if (!$backup -or (Hash $backup) -ne $requiredHash) { throw 'A verified original backup is required to upgrade the legacy module.' }
                    $baseSource = $backup
                    $baselineHash = $requiredHash
                }
                if (!$backup -or (Hash $backup) -ne $baselineHash) {
                    $backup = $TargetFile + '.before-notify.bak'
                    if (Test-Path -LiteralPath $backup) {
                        if ((Hash $backup) -ne $baselineHash) { throw 'Existing backup differs. It will not be overwritten.' }
                    } else {
                        Copy-Item -LiteralPath $TargetFile -Destination $backup
                    }
                }
                if ((Hash $backup) -ne $baselineHash) { throw 'Backup verification failed.' }
                $result.Backup = $backup
                $tool = Join-Path $PSScriptRoot 'wechat-notify-module.exe'
                if (!(Test-Path -LiteralPath $tool -PathType Leaf)) { throw 'Notification patch tool is missing.' }
                $toolHash = Hash $tool
                if ($toolHash -ne $toolExpectedHash) { throw 'Notification patch tool verification failed.' }
                $toolOutput = & $tool patch-copy $baseSource $stagingFile 2>&1
                if ($LASTEXITCODE -ne 0) { throw 'Patch generation failed. The original DLL was not replaced.' }
                $expectedHash = if ($baselineHash -eq $original) { $patchedOriginal } else { $patchedAntiRevoke }
            } else {
                if (!$backup) { throw 'A verified original backup is missing. Restore was refused.' }
                $expectedHash = Hash $backup
                # The two installed variants must restore their own original, never drop anti-revoke.
                $requiredHash = if ($currentHash -in @($patchedAntiRevoke, $legacyAntiRevoke)) { $antiRevoke } else { $original }
                if ($expectedHash -ne $requiredHash) { throw 'Backup does not match this installed notification variant.' }
                Copy-Item -LiteralPath $backup -Destination $stagingFile
            }
            if ((Hash $stagingFile) -ne $expectedHash) { throw 'Generated DLL verification failed. The original DLL was not replaced.' }
            # Recheck after generation in case WeChat started or another patcher changed the file.
            if (Get-Process Weixin,WeChat -ErrorAction SilentlyContinue) { throw 'WeChat started during the operation. Replacement cancelled.' }
            if ((Hash $TargetFile) -ne $currentHash) { throw 'DLL changed during the operation. Replacement cancelled.' }
            [IO.File]::Replace($stagingFile, $TargetFile, $swapBackup)
            if ((Hash $TargetFile) -ne $expectedHash -or (Hash $swapBackup) -ne $currentHash) {
                throw 'Replacement verification failed. Keep all backups for recovery.'
            }
            Remove-Item -LiteralPath $swapBackup
            $swapBackup = $null
            $result.Hash = $expectedHash
            $result.State = if ($Action -eq 'Install') { 'Installed' } else { 'NotInstalled' }
            $result.Message = 'Operation completed and verified.'
        }
    }
} catch {
    if ($result.State -ne 'Unsupported') { $result.State = 'Error' }
    $result.Message = $_.Exception.Message
} finally {
    if ($stagingFile -and (Test-Path -LiteralPath $stagingFile)) { Remove-Item -LiteralPath $stagingFile -ErrorAction SilentlyContinue }
    $lines = @('[Result]')
    foreach ($key in @('State','Message','Hash','Backup','Version')) {
        $lines += $key + '=' + ([string]$result[$key] -replace '[\r\n]', ' ')
    }
    $resultTemp = $ResultFile + '.tmp'
    [IO.File]::WriteAllLines($resultTemp, $lines, [Text.Encoding]::Unicode)
    Move-Item -LiteralPath $resultTemp -Destination $ResultFile -Force
}
if ($result.State -in @('Error','Unsupported','Incompatible')) { exit 1 }
