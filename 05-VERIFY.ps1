[CmdletBinding()]
param([switch]$FullHash)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
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
    $selectedGpuPath = Join-Path $packageRoot 'runtime\selected-gpu.txt'
    if (Test-Path -LiteralPath $selectedGpuPath) {
        $env:CUDA_VISIBLE_DEVICES = (Get-Content -Raw -LiteralPath $selectedGpuPath).Trim()
        Write-Host "[INFO] Testing selected physical NVIDIA GPU index $env:CUDA_VISIBLE_DEVICES" -ForegroundColor DarkGray
    }
    # Python single-quoted dictionary keys survive Windows PowerShell 5.1's
    # native argument quoting. Double-quoted keys are stripped and cause a
    # misleading NameError even when CUDA is healthy.
    $probeCode = "import json,torch; ok=torch.cuda.is_available(); print(json.dumps({'torch':torch.__version__,'cuda_runtime':torch.version.cuda,'cuda_available':ok,'device':torch.cuda.get_device_name(0) if ok else None,'vram_bytes':torch.cuda.get_device_properties(0).total_memory if ok else 0}))"
    $probeOutput = & $pythonPath -s -c $probeCode 2>&1
    $probeExit = $LASTEXITCODE
    $probeLine = $probeOutput | Where-Object { $_ -match '^\{' } | Select-Object -Last 1
    if ($probeExit -eq 0 -and $probeLine) {
        $probe = $probeLine | ConvertFrom-Json
        if ($probe.cuda_available) {
            $vramGiB = [math]::Round($probe.vram_bytes / 1GB, 2)
            Write-Host "[OK] PyTorch CUDA: $($probe.device), $vramGiB GiB VRAM, torch $($probe.torch), CUDA $($probe.cuda_runtime)" -ForegroundColor Green
        } else {
            Write-Host '[FAIL] Embedded PyTorch cannot access CUDA.' -ForegroundColor Red
            $failed = $true
        }
    } else {
        Write-Host '[FAIL] Embedded Python/PyTorch CUDA probe failed:' -ForegroundColor Red
        $probeOutput | ForEach-Object { Write-Host $_ -ForegroundColor Red }
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

$preset = Join-Path $packageRoot 'workflows\generated\NVIDIA-H3-T2V-480P-5s-Turbo8.json'
if (Test-Path $preset) {
    Write-Host '[OK] Windows NVIDIA low-VRAM workflow preset exists.' -ForegroundColor Green
} else {
    Write-Host '[FAIL] Windows NVIDIA low-VRAM workflow preset is missing.' -ForegroundColor Red
    $failed = $true
}

try {
    $stats = Invoke-RestMethod -Uri 'http://127.0.0.1:8188/system_stats' -TimeoutSec 3
    Write-Host '[OK] ComfyUI server is responding on port 8188.' -ForegroundColor Green
    if ($stats.devices) { $stats.devices | Format-Table name,type,vram_total,vram_free -AutoSize }
} catch {
    Write-Host '[INFO] ComfyUI is not running. Start 03-LAUNCH-STABLE.cmd, then run this check again.' -ForegroundColor Yellow
}

if ($FullHash) {
    Write-Host 'Full SHA-256 verification completed.' -ForegroundColor Green
} else {
    Write-Host 'Quick size verification completed. Use: powershell -File .\05-VERIFY.ps1 -FullHash' -ForegroundColor DarkGray
}

if ($failed) { exit 1 }
Write-Host "`nInstallation, model files and PyTorch CUDA checks passed. A queued 5-second generation is still required for final H3 validation." -ForegroundColor Green
exit 0
