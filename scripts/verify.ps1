param(
    [string]$InstallDir = "C:\Users\11720\AppData\Local\Programs\antigravity"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3.0

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$TranslationPath = Join-Path $ProjectRoot "translations\zh-CN.json"
$RuntimePath = Join-Path $ProjectRoot "src\ag-zh-cn-runtime.js"
$NativeMenuPath = Join-Path $ProjectRoot "src\ag-zh-cn-native-menu.js"
$PatchMarker = "antigravity-zh-cn"

function Assert-Ok {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
    Write-Host "[OK] $Message"
}

function Test-BinaryContainsText {
    param(
        [string]$Path,
        [string]$Needle
    )
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    return $text.Contains($Needle)
}

Assert-Ok (Test-Path -LiteralPath $TranslationPath -PathType Leaf) "Translation file exists: $TranslationPath"
Assert-Ok (Test-Path -LiteralPath $RuntimePath -PathType Leaf) "Runtime script exists: $RuntimePath"
Assert-Ok (Test-Path -LiteralPath $NativeMenuPath -PathType Leaf) "Native menu script exists: $NativeMenuPath"

$translations = Get-Content -Raw -Encoding UTF8 -LiteralPath $TranslationPath | ConvertFrom-Json
$expectedNewConversation = $translations.exact.PSObject.Properties["New Conversation"].Value
$exactCount = ($translations.exact.PSObject.Properties | Measure-Object).Count
$menuCount = ($translations.nativeMenus.PSObject.Properties | Measure-Object).Count
Assert-Ok ($exactCount -gt 20) "exact translation count is valid: $exactCount"
Assert-Ok ($menuCount -gt 5) "nativeMenus translation count is valid: $menuCount"

node --check $RuntimePath | Out-Null
Assert-Ok ($LASTEXITCODE -eq 0) "Runtime script syntax check passed"
node --check $NativeMenuPath | Out-Null
Assert-Ok ($LASTEXITCODE -eq 0) "Native menu script syntax check passed"

if (-not (Test-Path -LiteralPath $InstallDir -PathType Container)) {
    Write-Host "[SKIP] Install directory does not exist: $InstallDir"
    exit 0
}

$InstallDir = (Resolve-Path -LiteralPath $InstallDir).Path
$ResourcesDir = Join-Path $InstallDir "resources"
$AsarPath = Join-Path $ResourcesDir "app.asar"
$ManifestPath = Join-Path $ResourcesDir "antigravity-zh-cn\manifest.json"

Assert-Ok (Test-Path -LiteralPath $AsarPath -PathType Leaf) "Target app.asar exists: $AsarPath"

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    Write-Host "[INFO] Localization is not installed; manifest not found: $ManifestPath"
    exit 0
}

$manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
Assert-Ok ($manifest.patchName -eq "antigravity-zh-cn") "Manifest patchName is correct"
Assert-Ok ($manifest.backupPath -and (Test-Path -LiteralPath $manifest.backupPath -PathType Leaf)) "Backup file exists: $($manifest.backupPath)"

$currentHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $AsarPath).Hash
if ($manifest.state -eq "installed") {
    Assert-Ok (Test-BinaryContainsText -Path $AsarPath -Needle $PatchMarker) "app.asar contains localization marker"
    Assert-Ok (Test-BinaryContainsText -Path $AsarPath -Needle $expectedNewConversation) "app.asar contains Chinese translation resources"
    Assert-Ok ($currentHash -eq $manifest.patchedSha256) "Current app.asar matches manifest patchedSha256"
} else {
    if ($manifest.originalSha256) {
        Assert-Ok ($currentHash -eq $manifest.originalSha256) "Current app.asar matches manifest originalSha256"
    }
    Write-Host "[INFO] Manifest state is $($manifest.state); current SHA256: $currentHash"
}
