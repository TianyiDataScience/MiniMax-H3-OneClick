[CmdletBinding()]
param(
    [switch]$SkipComfyUI,
    [switch]$SkipModels,
    [switch]$AcceptModelLicense,
    [switch]$SkipShortcuts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$runtimeRoot = Join-Path $packageRoot 'runtime'
$downloadsRoot = Join-Path $runtimeRoot 'downloads'
$portableRoot = Join-Path $runtimeRoot 'ComfyUI_windows_portable'
$comfyRoot = Join-Path $portableRoot 'ComfyUI'
$manifestPath = Join-Path $packageRoot 'models-manifest.json'
$generatedWorkflows = Join-Path $packageRoot 'workflows\generated'

function New-Directory([string]$Path) {
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Test-ComfyUIInstall {
    $requiredFiles = @(
        (Join-Path $comfyRoot 'main.py'),
        (Join-Path $portableRoot 'python_embeded\python.exe'),
        (Join-Path $portableRoot 'python_embeded\Lib\site-packages\transformers\models\audio_spectrogram_transformer\configuration_audio_spectrogram_transformer.py')
    )
    foreach ($requiredFile in $requiredFiles) {
        if (-not (Test-Path -LiteralPath $requiredFile)) { return $false }
    }
    return $true
}

function Invoke-ResumableDownload {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$Destination,
        [Int64]$ExpectedBytes = 0,
        [string]$ExpectedSha256 = ''
    )

    New-Directory (Split-Path -Parent $Destination)

    if (Test-Path $Destination) {
        $existing = Get-Item $Destination
        $sizeOk = ($ExpectedBytes -eq 0 -or $existing.Length -eq $ExpectedBytes)
        if ($sizeOk) {
            if ($ExpectedSha256) {
                Write-Host "Checking existing file: $($existing.Name)" -ForegroundColor DarkGray
                $hash = (Get-FileHash -Algorithm SHA256 -Path $Destination).Hash.ToLowerInvariant()
                if ($hash -eq $ExpectedSha256.ToLowerInvariant()) {
                    Write-Host "[SKIP] Verified: $($existing.Name)" -ForegroundColor Green
                    return
                }
            } else {
                Write-Host "[SKIP] Existing: $($existing.Name)" -ForegroundColor Green
                return
            }
        }
        $badPath = "$Destination.bad-$(Get-Date -Format yyyyMMdd-HHmmss)"
        Move-Item -Path $Destination -Destination $badPath
        Write-Warning "Existing file did not verify and was preserved as $badPath"
    }

    $partial = "$Destination.part"
    Write-Host "`n[DOWNLOAD] $Url" -ForegroundColor Cyan
    $curlArgs = @(
        '--location', '--fail', '--retry', '10', '--retry-delay', '5',
        '--connect-timeout', '30', '--continue-at', '-',
        '--output', $partial, $Url
    )
    & curl.exe @curlArgs
    if ($LASTEXITCODE -ne 0) { throw "Download failed. Run 00-START-HERE.cmd again to resume: $Url" }

    $partialInfo = Get-Item $partial
    if ($ExpectedBytes -gt 0 -and $partialInfo.Length -ne $ExpectedBytes) {
        throw "Size mismatch for $($partialInfo.Name): got $($partialInfo.Length), expected $ExpectedBytes"
    }
    if ($ExpectedSha256) {
        Write-Host "[HASH] SHA-256: $($partialInfo.Name)" -ForegroundColor DarkGray
        $hash = (Get-FileHash -Algorithm SHA256 -Path $partial).Hash.ToLowerInvariant()
        if ($hash -ne $ExpectedSha256.ToLowerInvariant()) {
            $badPath = "$Destination.bad-$(Get-Date -Format yyyyMMdd-HHmmss)"
            Move-Item -Path $partial -Destination $badPath
            throw "SHA-256 mismatch for $($partialInfo.Name). The bad file was preserved as $badPath; the next run will download a clean copy."
        }
    }
    Move-Item -Path $partial -Destination $Destination -Force
    Write-Host "[OK] $Destination" -ForegroundColor Green
}

function Copy-VerifiedAsset {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination,
        [Parameter(Mandatory=$true)][string]$ExpectedSha256
    )
    if (-not (Test-Path $Source)) { throw "Bundled asset is missing: $Source" }
    $actualHash = (Get-FileHash -Algorithm SHA256 -Path $Source).Hash.ToLowerInvariant()
    if ($actualHash -ne $ExpectedSha256.ToLowerInvariant()) {
        throw "Bundled asset failed SHA-256 verification: $Source"
    }
    New-Directory (Split-Path -Parent $Destination)
    Copy-Item -Path $Source -Destination $Destination -Force
    Write-Host "[OK] Bundled asset: $Destination" -ForegroundColor Green
}

function Get-SevenZip {
    $candidates = @(
        (Join-Path $env:ProgramFiles '7-Zip\7z.exe'),
        (Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.exe')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    $downloaded = Join-Path $downloadsRoot '7zr.exe'
    Invoke-ResumableDownload -Url 'https://www.7-zip.org/a/7zr.exe' -Destination $downloaded -ExpectedBytes 602112 -ExpectedSha256 '56b8cc9f4971cef253644fafe54063ed7fdca551d4dee0f8c6baa81b855acd72'
    return $downloaded
}

function Set-H3WorkflowPreset {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination,
        [Parameter(Mandatory=$true)][string]$Aspect,
        [double]$Megapixels = 0.4,
        [int]$LandscapeWidth = 864,
        [int]$LandscapeHeight = 480
    )
    $workflow = Get-Content -Raw -Encoding UTF8 -Path $Source | ConvertFrom-Json
    foreach ($node in $workflow.nodes) {
        $hasWidgets = $null -ne $node.PSObject.Properties['widgets_values']
        if ($node.type -eq 'ResolutionSelector') {
            $node.widgets_values[0] = $Aspect
            $node.widgets_values[1] = $Megapixels
            $node.widgets_values[2] = 32
        }
        if ($node.type -eq 'SaveVideo') { $node.widgets_values[0] = 'video/MiniMax_H3_WindowsNVIDIA' }
        if ($hasWidgets -and $node.widgets_values -and $node.widgets_values.Count -ge 13 -and $node.widgets_values[5] -eq 'minimax_h3_fl2va_pruned_int8_convrot.safetensors') {
            if ($Aspect -like '16:9*') {
                $node.widgets_values[1] = $LandscapeWidth
                $node.widgets_values[2] = $LandscapeHeight
            } else {
                $node.widgets_values[1] = $LandscapeHeight
                $node.widgets_values[2] = $LandscapeWidth
            }
            $node.widgets_values[3] = 5
            # Current native H3 subgraph widget order:
            # 8=audio VAE, 9=turbo enabled, 11=LoRA strength, 12=turbo steps.
            $node.widgets_values[9] = $true
            $node.widgets_values[12] = 8
        }
    }
    if ($workflow.definitions -and $workflow.definitions.subgraphs) {
        foreach ($subgraph in $workflow.definitions.subgraphs) {
            foreach ($node in $subgraph.nodes) {
                if ($node.type -eq 'PrimitiveBoolean' -and $node.title -eq 'Boolean (Enable Lightning LoRA)') { $node.widgets_values[0] = $true }
                if ($node.type -eq 'ComfySwitchNode' -and $node.title -like 'If/Else Switch*') { $node.widgets_values[0] = $true }
                if ($node.type -eq 'PrimitiveFloat' -and $node.title -eq 'Float (duration)') { $node.widgets_values[0] = 5 }
                if ($node.type -eq 'PrimitiveInt' -and $node.widgets_values[0] -lt 20) { $node.widgets_values[0] = 8 }
            }
        }
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $json = $workflow | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($Destination, $json, $utf8NoBom)
}

New-Directory $runtimeRoot
New-Directory $downloadsRoot
New-Directory $generatedWorkflows

Write-Host "=== Installing ComfyUI + MiniMax H3 ===" -ForegroundColor Cyan

if (-not $SkipModels -and -not $AcceptModelLicense) {
    throw 'Model download was not authorized. Read MODEL-LICENSE-NOTICE.md and rerun through 00-START-HERE.cmd, or pass -AcceptModelLicense only after confirming you have the necessary rights.'
}

if (-not $SkipComfyUI -and -not (Test-ComfyUIInstall)) {
    $archive = Join-Path $downloadsRoot 'ComfyUI_windows_portable_nvidia.7z'
    Invoke-ResumableDownload -Url 'https://github.com/Comfy-Org/ComfyUI/releases/download/v0.34.0/ComfyUI_windows_portable_nvidia.7z' -Destination $archive -ExpectedBytes 2146721943 -ExpectedSha256 'ed57cc6b19ae3d83add1ecebfdd56b25e04e0008cf0fe9af43a4ad8797e2a24c'
    $sevenZip = Get-SevenZip
    Write-Host "`n[EXTRACT] ComfyUI Windows Portable" -ForegroundColor Cyan
    & $sevenZip x $archive "-o$runtimeRoot" -y
    if ($LASTEXITCODE -ne 0) { throw '7-Zip could not extract ComfyUI.' }
}

if (-not (Test-ComfyUIInstall)) {
    throw "ComfyUI is incomplete at $comfyRoot. Move the package to a short English-only path and run the installer again."
}
$versionFile = Join-Path $comfyRoot 'comfyui_version.py'
if (-not (Test-Path $versionFile)) { throw 'ComfyUI version file is missing.' }
$versionText = Get-Content -Raw -Path $versionFile
$versionMatch = [regex]::Match($versionText, '__version__\s*=\s*["'']([^"'']+)["'']')
if (-not $versionMatch.Success) { throw 'Could not read the ComfyUI version.' }
$comfyVersion = [version]$versionMatch.Groups[1].Value
if ($comfyVersion -lt [version]'0.30.0') { throw "ComfyUI $comfyVersion is too old for native MiniMax H3 support." }
Write-Host "[OK] ComfyUI ${comfyVersion}: $comfyRoot" -ForegroundColor Green

$manifest = Get-Content -Raw -Path $manifestPath | ConvertFrom-Json
if (-not $SkipModels) {
    foreach ($file in $manifest.files) {
        $destination = Join-Path $comfyRoot ($file.relativePath -replace '/', '\')
        Invoke-ResumableDownload -Url $file.url -Destination $destination -ExpectedBytes $file.sizeBytes -ExpectedSha256 $file.sha256
    }
}

$officialT2V = Join-Path $generatedWorkflows 'OFFICIAL-H3-T2V.json'
$officialI2V = Join-Path $generatedWorkflows 'OFFICIAL-H3-I2V.json'
Copy-VerifiedAsset -Source (Join-Path $packageRoot 'workflows\official\OFFICIAL-H3-T2V.json') -Destination $officialT2V -ExpectedSha256 '2400b01a7c8acae3fed038c0372f08bacb90d2cdf915febadbe7e3f9802506ea'
Copy-VerifiedAsset -Source (Join-Path $packageRoot 'workflows\official\OFFICIAL-H3-I2V.json') -Destination $officialI2V -ExpectedSha256 '4dc94e9ea308c1d60409e7f55dba5e2788dab4659c2dbb90f1e9481498767540'

$presetT2V = Join-Path $generatedWorkflows 'H3-T2V-480P-5s-Turbo8.json'
$presetT2V768 = Join-Path $generatedWorkflows 'H3-T2V-768P-5s-Turbo8.json'
$presetI2V = Join-Path $generatedWorkflows 'H3-I2V-480P-5s-Turbo8.json'
Set-H3WorkflowPreset -Source $officialT2V -Destination $presetT2V -Aspect '16:9 (Widescreen)'
Set-H3WorkflowPreset -Source $officialT2V -Destination $presetT2V768 -Aspect '16:9 (Widescreen)' -Megapixels 0.98 -LandscapeWidth 1344 -LandscapeHeight 768
Set-H3WorkflowPreset -Source $officialI2V -Destination $presetI2V -Aspect '16:9 (Widescreen)'

$userWorkflows = Join-Path $comfyRoot 'user\default\workflows'
New-Directory $userWorkflows
Copy-Item -Path $officialT2V,$officialI2V,$presetT2V,$presetT2V768,$presetI2V -Destination $userWorkflows -Force

$defaultInput = Join-Path $comfyRoot 'input\transparent_rgb_gaming_mouse.png'
Copy-VerifiedAsset -Source (Join-Path $packageRoot 'assets\transparent_rgb_gaming_mouse.png') -Destination $defaultInput -ExpectedSha256 '49696748d2fff0e8c9b63c7173c6d6282b70eac0195def5b39402f9564410e75'

$state = [ordered]@{
    installedAt = (Get-Date).ToString('o')
    comfyRoot = $comfyRoot
    manifestUpdatedAt = $manifest.updatedAt
    workflowPreset = $presetT2V
}
$stateJson = $state | ConvertTo-Json
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $runtimeRoot 'install-state.json'), $stateJson, $utf8NoBom)

if (-not $SkipShortcuts) {
    try {
        & (Join-Path $packageRoot '10-CREATE-SHORTCUTS.ps1')
    } catch {
        Write-Warning "Installation succeeded, but user shortcuts could not be created: $($_.Exception.Message)"
        Write-Warning 'Run 10-CREATE-SHORTCUTS.ps1 manually from the installed folder.'
    }
}

Write-Host "`n=== Installation complete ===" -ForegroundColor Green
Write-Host "First launch: $packageRoot\03-LAUNCH-STABLE.cmd"
Write-Host "First workflow: $presetT2V"
Write-Host 'The downloaded ComfyUI archive is kept in runtime\downloads so a failed extraction can be recovered.'
