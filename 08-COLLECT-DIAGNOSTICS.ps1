[CmdletBinding()]
param(
    [switch]$IncludeHashes,
    [switch]$IncludeLogs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$runtimeRoot = Join-Path $packageRoot 'runtime'
$comfyRoot = Join-Path $runtimeRoot 'ComfyUI_windows_portable\ComfyUI'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$diagnosticsRoot = Join-Path $runtimeRoot "diagnostics\$stamp"
New-Item -ItemType Directory -Path $diagnosticsRoot -Force | Out-Null
$reportPath = Join-Path $diagnosticsRoot 'system-report.txt'
$manifestPath = Join-Path $packageRoot 'models-manifest.json'

function Add-Section([string]$Title, [scriptblock]$Body) {
    Add-Content -Path $reportPath -Value "`r`n===== $Title =====" -Encoding UTF8
    try {
        $value = & $Body | Out-String -Width 240
        Add-Content -Path $reportPath -Value $value -Encoding UTF8
    } catch {
        Add-Content -Path $reportPath -Value "ERROR: $($_.Exception.Message)" -Encoding UTF8
    }
}

Set-Content -Path $reportPath -Value "MiniMax H3 diagnostics`r`nCreated: $(Get-Date -Format o)" -Encoding UTF8

Add-Section 'Windows' { Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,OSArchitecture,FreePhysicalMemory,TotalVisibleMemorySize }
Add-Section 'Computer' { Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer,Model,TotalPhysicalMemory,AutomaticManagedPagefile }
Add-Section 'CPU' { Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors }
Add-Section 'Video adapters' { Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,AdapterRAM,VideoProcessor }
Add-Section 'NVIDIA SMI' { & nvidia-smi.exe }
Add-Section 'NVIDIA query' { & nvidia-smi.exe --query-gpu=name,driver_version,memory.total,memory.used,memory.free,temperature.gpu,power.draw --format=csv }
Add-Section 'Page file' { Get-CimInstance Win32_PageFileUsage | Select-Object AllocatedBaseSize,CurrentUsage,PeakUsage }
Add-Section 'Disks' { Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID,FileSystem,Size,FreeSpace }

Add-Section 'ComfyUI version' {
    $versionFile = Join-Path $comfyRoot 'comfyui_version.py'
    if (Test-Path $versionFile) { Get-Content $versionFile } else { 'ComfyUI version file missing' }
}

Add-Section 'Model files' {
    if (-not (Test-Path $manifestPath)) { return 'Model manifest missing' }
    $manifest = Get-Content -Raw -Path $manifestPath | ConvertFrom-Json
    foreach ($file in $manifest.files) {
        $path = Join-Path $comfyRoot ($file.relativePath -replace '/', '\')
        if (Test-Path $path) {
            $item = Get-Item $path
            $result = [ordered]@{ Name=$file.name; Bytes=$item.Length; ExpectedBytes=$file.sizeBytes; SizeOK=($item.Length -eq $file.sizeBytes) }
            if ($IncludeHashes) {
                $actualHash = (Get-FileHash -Algorithm SHA256 -Path $path).Hash.ToLowerInvariant()
                $result['SHA256'] = $actualHash
                $result['HashOK'] = ($actualHash -eq $file.sha256.ToLowerInvariant())
            }
            [pscustomobject]$result
        } else {
            [pscustomobject]@{ Name=$file.name; Missing=$true }
        }
    }
}

try {
    $stats = Invoke-RestMethod -Uri 'http://127.0.0.1:8188/system_stats' -TimeoutSec 3
    $stats | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $diagnosticsRoot 'comfyui-system-stats.json') -Encoding UTF8
} catch {
    Add-Content -Path $reportPath -Value "`r`nComfyUI API unavailable: $($_.Exception.Message)" -Encoding UTF8
}

if ($IncludeLogs) {
    $logsRoot = Join-Path $runtimeRoot 'logs'
    if (Test-Path $logsRoot) {
        Copy-Item -Path (Join-Path $logsRoot '*.log') -Destination $diagnosticsRoot -Force -ErrorAction SilentlyContinue
    }
    Set-Content -Path (Join-Path $diagnosticsRoot 'LOGS-INCLUDED.txt') -Value 'Logs were included by explicit request and may contain prompts, paths, filenames or other private information.' -Encoding UTF8
}

$outputRoot = Join-Path $comfyRoot 'output'
if (Test-Path $outputRoot) {
    Get-ChildItem -Path $outputRoot -Recurse -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 20 Name,Length,LastWriteTime |
        Format-Table -AutoSize |
        Out-String -Width 240 |
        Set-Content -Path (Join-Path $diagnosticsRoot 'recent-outputs.txt') -Encoding UTF8
}

$zipPath = Join-Path $runtimeRoot "diagnostics-$stamp.zip"
Compress-Archive -Path (Join-Path $diagnosticsRoot '*') -DestinationPath $zipPath -Force
Write-Host "Diagnostics created: $zipPath" -ForegroundColor Green
Write-Host 'Privacy warning: this ZIP contains hardware/configuration information and output filenames.' -ForegroundColor Yellow
if ($IncludeLogs) {
    Write-Host 'Logs were included and may contain prompts or local paths. Inspect every file before sharing.' -ForegroundColor Red
} else {
    Write-Host 'Logs, model weights and generated media were not included. Inspect every file before sharing anyway.' -ForegroundColor Yellow
}
