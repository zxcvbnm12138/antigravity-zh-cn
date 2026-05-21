param(
    [string]$InstallDir = "C:\Users\11720\AppData\Local\Programs\antigravity"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3.0

function Resolve-ExistingDirectory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Directory does not exist: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Get-RunningAntigravityProcess {
    param([string]$ResolvedInstallDir)
    Get-CimInstance Win32_Process | Where-Object {
        $exe = $_.ExecutablePath
        $name = $_.Name
        ($name -in @("Antigravity.exe", "Antigravity IDE.exe", "language_server.exe", "language_server_windows_x64.exe")) -or
        ($exe -and $exe.StartsWith($ResolvedInstallDir, [System.StringComparison]::OrdinalIgnoreCase))
    }
}

function ConvertTo-JsonFile {
    param(
        [object]$Value,
        [string]$Path
    )
    $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

$InstallDir = Resolve-ExistingDirectory -Path $InstallDir
$ResourcesDir = Join-Path $InstallDir "resources"
$AsarPath = Join-Path $ResourcesDir "app.asar"
$ManifestPath = Join-Path $ResourcesDir "antigravity-zh-cn\manifest.json"

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Localization manifest not found; cannot uninstall automatically: $ManifestPath"
}
if (-not (Test-Path -LiteralPath $AsarPath -PathType Leaf)) {
    throw "app.asar not found: $AsarPath"
}

$running = @(Get-RunningAntigravityProcess -ResolvedInstallDir $InstallDir)
if ($running.Count -gt 0) {
    $details = ($running | ForEach-Object { "$($_.Name) (PID $($_.ProcessId))" }) -join ", "
    throw "Antigravity is running. Close it and retry. Detected: $details"
}

$manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
if (-not $manifest.backupPath -or -not (Test-Path -LiteralPath $manifest.backupPath -PathType Leaf)) {
    throw "Backup file from manifest does not exist: $($manifest.backupPath)"
}

Copy-Item -LiteralPath $manifest.backupPath -Destination $AsarPath -Force

$restoredHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $AsarPath).Hash
if ($manifest.originalSha256 -and $restoredHash -ne $manifest.originalSha256) {
    throw "Restored app.asar SHA256 mismatch. Expected $($manifest.originalSha256), actual $restoredHash"
}

$manifest | Add-Member -NotePropertyName "uninstalledAt" -NotePropertyValue (Get-Date).ToString("o") -Force
$manifest | Add-Member -NotePropertyName "state" -NotePropertyValue "uninstalled" -Force
ConvertTo-JsonFile -Value $manifest -Path $ManifestPath

Write-Host "Original app.asar restored."
Write-Host "Backup source: $($manifest.backupPath)"
