[CmdletBinding()]
param([int]$IntervalSeconds = 2)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

if (-not (Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue)) {
    throw 'nvidia-smi.exe was not found. Install/update the NVIDIA driver.'
}

$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$logRoot = Join-Path $packageRoot 'runtime\benchmarks'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$logPath = Join-Path $logRoot "h3-gpu-$(Get-Date -Format yyyyMMdd-HHmmss).csv"
$header = 'timestamp,name,utilization_gpu_percent,memory_used_mib,memory_total_mib,temperature_c,power_w'
Set-Content -Path $logPath -Value $header -Encoding UTF8

Write-Host "GPU monitor started. Queue the H3 workflow now; press Ctrl+C after the MP4 is saved." -ForegroundColor Cyan
Write-Host "CSV: $logPath"

try {
    while ($true) {
        $line = & nvidia-smi.exe --query-gpu=timestamp,name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits
        if ($LASTEXITCODE -ne 0) { throw 'nvidia-smi query failed.' }
        $line | Add-Content -Path $logPath -Encoding UTF8
        Write-Host $line
        Start-Sleep -Seconds $IntervalSeconds
    }
} finally {
    Write-Host "GPU monitor stopped. Keep this file as performance evidence: $logPath" -ForegroundColor Green
}
