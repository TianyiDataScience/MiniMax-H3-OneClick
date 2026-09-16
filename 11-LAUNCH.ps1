[CmdletBinding()]
param([ValidateSet('Stable', 'Balanced')][string]$Mode = 'Stable')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$packageRoot = $PSScriptRoot
. (Join-Path $packageRoot 'installer-common.ps1')
try {
    $portable = Join-Path $packageRoot 'runtime\ComfyUI_windows_portable'
    $python = Join-Path $portable 'python_embeded\python.exe'
    $main = Join-Path $portable 'ComfyUI\main.py'
    $userDirectory = Join-Path $portable 'ComfyUI\user'
    if (-not (Test-Path -LiteralPath $python) -or -not (Test-Path -LiteralPath $main)) {
        throw 'ComfyUI is incomplete. Run 00-START-HERE.cmd first.'
    }
    $gpuUuid = Get-SelectedGpuUuid -PackageRoot $packageRoot
    $stats = $null
    try { $stats = Invoke-RestMethod -Uri 'http://127.0.0.1:8188/system_stats' -TimeoutSec 2 } catch { }
    if ($null -ne $stats) {
        if (Test-ComfyServerIdentity -Stats $stats -MainPath $main -UserPath $userDirectory -GpuUuid $gpuUuid) {
            Write-Host 'This installation is already running. Reusing its current mode.'
            Start-Process 'http://127.0.0.1:8188'
            exit 0
        }
        throw 'Port 8188 belongs to another or older ComfyUI instance. Close its console before starting this installation. No process was stopped automatically.'
    }
    $client = New-Object Net.Sockets.TcpClient
    $occupied = $false
    try { $occupied = $client.ConnectAsync('127.0.0.1', 8188).Wait(1000) -and $client.Connected } catch { }
    finally { $client.Dispose() }
    if ($occupied) { throw 'Port 8188 is occupied by an unrecognized service. Close that service and retry.' }

    $logDirectory = Join-Path $packageRoot 'runtime\logs'
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path $userDirectory -Force | Out-Null
    # Set before Python starts: initialization can precede argument parsing.
    $env:CUDA_VISIBLE_DEVICES = $gpuUuid
    $arguments = @('-s', $main, '--windows-standalone-build', '--auto-launch',
        '--cuda-device', $gpuUuid, '--user-directory', $userDirectory,
        '--preview-method', 'none')
    if ($Mode -eq 'Stable') {
        $arguments += @('--lowvram', '--reserve-vram', '1.5', '--disable-pinned-memory')
    } else { $arguments += @('--reserve-vram', '0.8') }
    $arguments += @('--verbose', 'INFO', (Join-Path $logDirectory "comfyui-$($Mode.ToLowerInvariant()).log"))
    Write-Host "Mode: $Mode; NVIDIA GPU: $gpuUuid. Keep this window open."
    Push-Location -LiteralPath $portable
    try { & $python @arguments; $code = $LASTEXITCODE } finally { Pop-Location }
    exit $code
} catch {
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
