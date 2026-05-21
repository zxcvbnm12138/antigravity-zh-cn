param(
    [string]$InstallDir = "C:\Users\11720\AppData\Local\Programs\antigravity"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3.0

$PatchVersion = "0.1.0"
$PatchMarker = "antigravity-zh-cn"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$TranslationPath = Join-Path $ProjectRoot "translations\zh-CN.json"
$RuntimePath = Join-Path $ProjectRoot "src\ag-zh-cn-runtime.js"
$NativeMenuPath = Join-Path $ProjectRoot "src\ag-zh-cn-native-menu.js"

function Resolve-ExistingDirectory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Directory does not exist: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Assert-Tool {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Command not found: $Name"
    }
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

function Invoke-Asar {
    param([string[]]$Arguments)
    $candidates = @(
        @("npx.cmd", "--yes", "@electron/asar"),
        @("npx.cmd", "--yes", "asar")
    )

    $lastOutput = $null
    foreach ($candidate in $candidates) {
        $exe = $candidate[0]
        $prefix = @()
        if ($candidate.Count -gt 1) {
            $prefix = $candidate[1..($candidate.Count - 1)]
        }
        $output = & $exe @prefix @Arguments 2>&1
        if ($LASTEXITCODE -eq 0) {
            return
        }
        $lastOutput = $output
    }

    throw "asar command failed: $($Arguments -join ' ')`n$lastOutput"
}

function ConvertTo-JsonFile {
    param(
        [object]$Value,
        [string]$Path
    )
    $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Test-TextFileContains {
    param(
        [string]$Path,
        [string]$Needle
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }
    return (Get-Content -Raw -LiteralPath $Path).Contains($Needle)
}

function Remove-PatchBlock {
    param(
        [string]$Content,
        [string]$StartMarker,
        [string]$EndMarker
    )
    $pattern = "(?s)\r?\n?// <$([regex]::Escape($StartMarker))>.*?// </$([regex]::Escape($EndMarker))>\r?\n?"
    return [regex]::Replace($Content, $pattern, "`r`n")
}

function Add-PreloadPatch {
    param(
        [string]$PreloadPath,
        [string]$TranslationPath,
        [string]$RuntimePath
    )
    $content = Get-Content -Raw -LiteralPath $PreloadPath
    $content = Remove-PatchBlock -Content $content -StartMarker "antigravity-zh-cn" -EndMarker "antigravity-zh-cn"
    $translationJson = Get-Content -Raw -Encoding UTF8 -LiteralPath $TranslationPath
    $runtimeSource = Get-Content -Raw -Encoding UTF8 -LiteralPath $RuntimePath
    $block = @'

// <antigravity-zh-cn>
try {
    globalThis.__ANTIGRAVITY_ZH_CN_TRANSLATIONS__ =
'@ + "`r`n" + $translationJson.Trim() + @'
;

'@ + $runtimeSource.Trim() + @'

} catch (error) {
    console.warn("[antigravity-zh-cn] inline preload runtime failed", error);
}
// </antigravity-zh-cn>
'@
    Set-Content -LiteralPath $PreloadPath -Value ($content.TrimEnd() + $block + "`r`n") -Encoding UTF8
}

function Add-NativeMenuPatch {
    param([string]$MenuPath)
    $content = Get-Content -Raw -LiteralPath $MenuPath
    $content = Remove-PatchBlock -Content $content -StartMarker "antigravity-zh-cn-native-menu" -EndMarker "antigravity-zh-cn-native-menu"
    $needle = "    electron_1.Menu.setApplicationMenu(menu);"
    if (-not $content.Contains($needle)) {
        throw "Cannot locate Menu.setApplicationMenu(menu); menu.js was not patched"
    }
    $block = @'
    // <antigravity-zh-cn-native-menu>
    try {
        require("./ag-zh-cn-native-menu.js").translateApplicationMenu(menu);
    } catch (error) {
        console.warn("[antigravity-zh-cn] native menu translation failed", error);
    }
    // </antigravity-zh-cn-native-menu>
'@
    $content = $content.Replace($needle, $block + "`r`n" + $needle)
    Set-Content -LiteralPath $MenuPath -Value $content -Encoding UTF8
}

if (-not (Test-Path -LiteralPath $TranslationPath -PathType Leaf)) {
    throw "Missing translation file: $TranslationPath"
}
if (-not (Test-Path -LiteralPath $RuntimePath -PathType Leaf)) {
    throw "Missing runtime file: $RuntimePath"
}
if (-not (Test-Path -LiteralPath $NativeMenuPath -PathType Leaf)) {
    throw "Missing native menu runtime file: $NativeMenuPath"
}

Assert-Tool -Name "node"
Assert-Tool -Name "npx.cmd"
& node --check $RuntimePath | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Runtime syntax check failed: $RuntimePath"
}
& node --check $NativeMenuPath | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Native menu syntax check failed: $NativeMenuPath"
}

$InstallDir = Resolve-ExistingDirectory -Path $InstallDir
$ResourcesDir = Join-Path $InstallDir "resources"
$AsarPath = Join-Path $ResourcesDir "app.asar"
$PatchDir = Join-Path $ResourcesDir "antigravity-zh-cn"
$BackupDir = Join-Path $PatchDir "backups"
$ManifestPath = Join-Path $PatchDir "manifest.json"

if (-not (Test-Path -LiteralPath $AsarPath -PathType Leaf)) {
    throw "app.asar not found: $AsarPath"
}

$running = @(Get-RunningAntigravityProcess -ResolvedInstallDir $InstallDir)
if ($running.Count -gt 0) {
    $details = ($running | ForEach-Object { "$($_.Name) (PID $($_.ProcessId))" }) -join ", "
    throw "Antigravity is running. Close it and retry. Detected: $details"
}

New-Item -ItemType Directory -Force -Path $PatchDir, $BackupDir | Out-Null

$currentHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $AsarPath).Hash
$manifest = $null
if (Test-Path -LiteralPath $ManifestPath -PathType Leaf) {
    try {
        $manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
    } catch {
        $manifest = $null
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("antigravity-zh-cn-" + [guid]::NewGuid().ToString("N"))
$extractDir = Join-Path $tempRoot "app"
$newAsar = Join-Path $tempRoot "app.asar"
New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

try {
    Write-Host "Extracting app.asar..."
    Invoke-Asar -Arguments @("extract", $AsarPath, $extractDir)

    $preloadPath = Join-Path $extractDir "dist\preload.js"
    $menuPath = Join-Path $extractDir "dist\menu.js"
    if (-not (Test-Path -LiteralPath $preloadPath -PathType Leaf)) {
        throw "preload.js not found: $preloadPath"
    }
    if (-not (Test-Path -LiteralPath $menuPath -PathType Leaf)) {
        throw "menu.js not found: $menuPath"
    }

    $wasAlreadyPatched = Test-TextFileContains -Path $preloadPath -Needle $PatchMarker
    $backupPath = $null
    if ($manifest -and $manifest.backupPath -and (Test-Path -LiteralPath $manifest.backupPath -PathType Leaf) -and $wasAlreadyPatched) {
        $backupPath = $manifest.backupPath
    } else {
        $backupName = "app.asar.$currentHash.bak"
        $backupPath = Join-Path $BackupDir $backupName
        if (-not (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
            Copy-Item -LiteralPath $AsarPath -Destination $backupPath
        }
    }

    Write-Host "Writing translation resources..."
    New-Item -ItemType Directory -Force -Path (Join-Path $extractDir "translations") | Out-Null
    Copy-Item -LiteralPath $TranslationPath -Destination (Join-Path $extractDir "translations\zh-CN.json") -Force
    Copy-Item -LiteralPath $RuntimePath -Destination (Join-Path $extractDir "dist\ag-zh-cn-runtime.js") -Force
    Copy-Item -LiteralPath $NativeMenuPath -Destination (Join-Path $extractDir "dist\ag-zh-cn-native-menu.js") -Force

    Add-PreloadPatch -PreloadPath $preloadPath -TranslationPath $TranslationPath -RuntimePath $RuntimePath
    Add-NativeMenuPatch -MenuPath $menuPath

    Write-Host "Repacking app.asar..."
    Invoke-Asar -Arguments @("pack", $extractDir, $newAsar)
    if (-not (Test-Path -LiteralPath $newAsar -PathType Leaf)) {
        throw "Repack failed; output was not created: $newAsar"
    }

    $tmpAsar = "$AsarPath.zh-cn.tmp"
    Copy-Item -LiteralPath $newAsar -Destination $tmpAsar -Force
    Move-Item -LiteralPath $tmpAsar -Destination $AsarPath -Force

    $patchedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $AsarPath).Hash
    $translationHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $TranslationPath).Hash
    $packageJsonPath = Join-Path $extractDir "package.json"
    $appVersion = $null
    if (Test-Path -LiteralPath $packageJsonPath -PathType Leaf) {
        $appVersion = (Get-Content -Raw -LiteralPath $packageJsonPath | ConvertFrom-Json).version
    }

    $newManifest = [ordered]@{
        patchName = "antigravity-zh-cn"
        patchVersion = $PatchVersion
        installedAt = (Get-Date).ToString("o")
        installDir = $InstallDir
        appVersion = $appVersion
        asarPath = $AsarPath
        backupPath = $backupPath
        originalSha256 = if ($manifest -and $manifest.originalSha256 -and $wasAlreadyPatched) { $manifest.originalSha256 } else { $currentHash }
        patchedSha256 = $patchedHash
        translationSha256 = $translationHash
        state = "installed"
    }
    ConvertTo-JsonFile -Value $newManifest -Path $ManifestPath

    Write-Host "Install complete."
    Write-Host "Backup: $backupPath"
    Write-Host "Manifest: $ManifestPath"
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
