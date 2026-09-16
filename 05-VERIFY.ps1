[CmdletBinding()]
param([switch]$FullHash)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $packageRoot 'installer-common.ps1')
$gpuUuid = ''
$comfyRoot = Join-Path $packageRoot 'runtime\ComfyUI_windows_portable\ComfyUI'
$manifest = Get-Content -Raw -Path (Join-Path $packageRoot 'models-manifest.json') | ConvertFrom-Json
$failed = $false

Write-Host '=== MiniMax H3 installation verification ===' -ForegroundColor Cyan

if (Test-Path (Join-Path $comfyRoot 'main.py')) {
    Write-Host "[OK] ComfyUI: $comfyRoot" -ForegroundColor Green
} else {
    Write-Host '[FAIL] ComfyUI main.py is missing.' -ForegroundColor Red
    $failed = $true
}

$versionFile = Join-Path $comfyRoot 'comfyui_version.py'
if (Test-Path $versionFile) {
    $versionText = Get-Content -Raw -Path $versionFile
    $versionMatch = [regex]::Match($versionText, '__version__\s*=\s*["'']([^"'']+)["'']')
    if ($versionMatch.Success -and [version]$versionMatch.Groups[1].Value -ge [version]'0.30.0') {
        Write-Host "[OK] ComfyUI version: $($versionMatch.Groups[1].Value)" -ForegroundColor Green
    } else {
        Write-Host '[FAIL] ComfyUI is older than 0.30.0 or its version could not be read.' -ForegroundColor Red
        $failed = $true
    }
} else {
    Write-Host '[FAIL] ComfyUI version file is missing.' -ForegroundColor Red
    $failed = $true
}

$pythonPath = Join-Path $packageRoot 'runtime\ComfyUI_windows_portable\python_embeded\python.exe'
if (Test-Path $pythonPath) {
    try {
    $gpuUuid = Get-SelectedGpuUuid -PackageRoot $packageRoot
    $env:CUDA_VISIBLE_DEVICES = $gpuUuid
    Write-Host "[INFO] Testing selected NVIDIA GPU $gpuUuid" -ForegroundColor DarkGray
    $probeOutput = & $pythonPath -s (Join-Path $packageRoot 'cuda-probe.py')
    $probeExit = $LASTEXITCODE
    $probeLine = $probeOutput | Where-Object { $_ -match '^\{' } | Select-Object -Last 1
    if ($probeExit -eq 0 -and $probeLine) {
        $probe = $probeLine | ConvertFrom-Json
        if ($probe.cuda_available -and $probe.kernel_ok) {
            $vramGiB = [math]::Round($probe.vram_bytes / 1GB, 2)
            Write-Host "[OK] PyTorch CUDA: $($probe.device), $vramGiB GiB VRAM, torch $($probe.torch), CUDA $($probe.cuda_runtime)" -ForegroundColor Green
            Write-Host "[OK] Real CUDA operations: $($probe.tested_dtypes -join ', '); GPU UUID matched." -ForegroundColor Green
        } else {
            Write-Host '[FAIL] Embedded PyTorch cannot access CUDA.' -ForegroundColor Red
            $failed = $true
        }
    } else {
        Write-Host '[FAIL] Embedded Python/PyTorch CUDA probe failed:' -ForegroundColor Red
        $probeOutput | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        $failed = $true
    }
    } catch {
        Write-Host "[FAIL] CUDA verification: $($_.Exception.Message)" -ForegroundColor Red
        $failed = $true
    }
} else {
    Write-Host '[FAIL] ComfyUI embedded Python is missing.' -ForegroundColor Red
    $failed = $true
}

foreach ($file in $manifest.files) {
    $path = Join-Path $comfyRoot ($file.relativePath -replace '/', '\')
    if (-not (Test-Path $path)) {
        Write-Host "[FAIL] Missing: $($file.name)" -ForegroundColor Red
        $failed = $true
        continue
    }
    $actualSize = (Get-Item $path).Length
    if ($actualSize -ne $file.sizeBytes) {
        Write-Host "[FAIL] Wrong size: $($file.name)" -ForegroundColor Red
        $failed = $true
        continue
    }
    if ($FullHash) {
        $actualHash = (Get-FileHash -Algorithm SHA256 -Path $path).Hash.ToLowerInvariant()
        if ($actualHash -ne $file.sha256.ToLowerInvariant()) {
            Write-Host "[FAIL] Wrong SHA-256: $($file.name)" -ForegroundColor Red
            $failed = $true
            continue
        }
    }
    Write-Host "[OK] $($file.name)" -ForegroundColor Green
}

$workflowPresets = @(
    'H3-T2V-480P-5s-Turbo8.json',
    'H3-T2V-768P-5s-Turbo8.json',
    'H3-I2V-480P-5s-Turbo8.json'
)
foreach ($workflowPreset in $workflowPresets) {
    $preset = Join-Path $packageRoot (Join-Path 'workflows\generated' $workflowPreset)
    if (Test-Path -LiteralPath $preset) {
        Write-Host "[OK] Workflow preset: $workflowPreset" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Workflow preset is missing: $workflowPreset" -ForegroundColor Red
        $failed = $true
    }
}

if (-not $failed) {
    Write-Host '[INFO] Checking actual ComfyUI startup (up to 180 seconds; isolated temporary directories, no video generation).' -ForegroundColor Cyan
    try {
        $startupOutput = & $pythonPath -s (Join-Path $packageRoot 'runtime-probe.py') --comfy-root $comfyRoot --timeout 180
        $startupExit = $LASTEXITCODE
        $startup = ($startupOutput -join "`n") | ConvertFrom-Json
        if ($startupExit -ne 0 -or -not $startup.startup_ok) {
            Write-Host "[FAIL] ComfyUI startup did not pass: $($startup.reason)" -ForegroundColor Red
            Write-Host $startup.details -ForegroundColor Red
            Write-Host 'If Windows application control blocked a DLL, review Windows protection events or contact the device administrator. Do not disable security or remove verification checks.' -ForegroundColor Yellow
            $failed = $true
        } else {
            Write-Host '[OK] ComfyUI built-in startup/dependency check passed. Custom nodes and video generation are not covered by this check.' -ForegroundColor Green
        }
    } catch {
        Write-Host "[FAIL] ComfyUI startup verification failed: $($_.Exception.Message)" -ForegroundColor Red
        $failed = $true
    }
}

try {
    $stats = Invoke-RestMethod -Uri 'http://127.0.0.1:8188/system_stats' -TimeoutSec 3
    if (Test-ComfyServerIdentity -Stats $stats -MainPath (Join-Path $comfyRoot 'main.py') -UserPath (Join-Path $comfyRoot 'user') -GpuUuid $gpuUuid) {
        Write-Host '[OK] This ComfyUI installation is responding on port 8188.' -ForegroundColor Green
        if ($stats.devices) { $stats.devices | Format-Table name,type,vram_total,vram_free -AutoSize }
    } else {
        Write-Host '[WARN] Port 8188 responds, but its installation/GPU identity does not match. Close the other/older instance before launching this package.' -ForegroundColor Yellow
    }
} catch {
    Write-Host '[INFO] ComfyUI is not running. Start 03-LAUNCH-STABLE.cmd, then run this check again.' -ForegroundColor Yellow
}

if ($FullHash) {
    Write-Host 'Full SHA-256 verification completed.' -ForegroundColor Green
} else {
    Write-Host 'Quick size verification completed. Use: powershell -File .\05-VERIFY.ps1 -FullHash' -ForegroundColor DarkGray
}

if ($failed) { exit 1 }
Write-Host "`nInstallation, model files, PyTorch CUDA and ComfyUI startup checks passed. A queued 5-second generation is still required for final H3 validation." -ForegroundColor Green
exit 0
