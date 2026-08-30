[CmdletBinding()]
param([string]$ObsPath = '')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$videoNames = (Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name) -join ' | '
Write-Host "Detected adapters: $videoNames" -ForegroundColor Cyan
if ($videoNames -notmatch 'Radeon') {
    Write-Warning 'No AMD Radeon integrated GPU was detected. Do not assume OBS is off the RTX GPU.'
}

if (-not $ObsPath) {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'obs-studio\bin\64bit\obs64.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'obs-studio\bin\64bit\obs64.exe')
    )
    $ObsPath = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

if (-not $ObsPath -or -not (Test-Path $ObsPath)) {
    Write-Warning 'OBS was not found. Install OBS, then rerun with: .\06-CONFIGURE-OBS-IGPU.ps1 -ObsPath "C:\path\obs64.exe"'
    Start-Process 'ms-settings:display-advancedgraphics'
    exit 1
}

$registryPath = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
if (-not (Test-Path $registryPath)) { New-Item -Path $registryPath -Force | Out-Null }
New-ItemProperty -Path $registryPath -Name $ObsPath -Value 'GpuPreference=1;' -PropertyType String -Force | Out-Null

Write-Host "[OK] Windows power-saving GPU preference set for: $ObsPath" -ForegroundColor Green
Write-Host 'Restart OBS, then choose AMD HW H.264 (AVC) or AMD HW AV1 as the recording encoder.' -ForegroundColor Yellow
Write-Host 'Recommended first recording: 1920x1080, 30 fps, CQP/CQ 18-22. Verify in Task Manager that GPU 0 Video Encode is active.'
