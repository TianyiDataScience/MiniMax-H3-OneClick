[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

function Write-Ok([string]$Message) { Write-Host "[OK]   $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Fail([string]$Message) { Write-Host "[FAIL] $Message" -ForegroundColor Red }

function Get-PagefileStatus {
    param($ComputerSystem, [object[]]$Usage = @(), [object[]]$Settings = @())
    # An empty CIM result has no Measure-Object.Sum in Windows PowerShell 5.1.
    [long]$allocatedMiB = 0
    foreach ($entry in $Usage) {
        if ($null -ne $entry) { $allocatedMiB += [long]$entry.AllocatedBaseSize }
    }
    $managed = $ComputerSystem.AutomaticManagedPagefile -eq $true
    foreach ($entry in $Settings) {
        if ($null -ne $entry -and $entry.InitialSize -eq 0 -and $entry.MaximumSize -eq 0) {
            $managed = $true # Per-drive system management, even if global auto is off.
        }
    }
    [pscustomobject]@{ Managed = $managed; AllocatedMiB = $allocatedMiB }
}

$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $packageRoot 'installer-common.ps1')
$critical = New-Object System.Collections.Generic.List[string]

# ComfyUI's embedded Python and some third-party packages still hit the
# traditional Windows MAX_PATH limit.  Check a known long package path before
# downloading tens of gigabytes so a readable but unusable installation is not
# reported as successful.
$longPathProbe = Join-Path $packageRoot 'runtime\ComfyUI_windows_portable\python_embeded\Lib\site-packages\transformers\models\audio_spectrogram_transformer\configuration_audio_spectrogram_transformer.py'
if ($longPathProbe.Length -ge 260) {
    $critical.Add("The installation path is too long ($($longPathProbe.Length) characters for a required file). Move this folder to a short path such as C:\AI\MiniMax-H3, then run the installer again.")
}
if ($packageRoot -match '[^\x00-\x7F]') {
    $critical.Add('The installation path contains non-ASCII characters. Use a short English-only path such as C:\AI\MiniMax-H3 to avoid embedded Python and logging failures.')
}
if ($packageRoot -match '[\[\]%!&^]') {
    $critical.Add('Use a short folder path without brackets or CMD special characters, for example D:\AI\MiniMax-H3.')
}

Write-Host "`n=== MiniMax H3 / Windows NVIDIA preflight ===" -ForegroundColor Cyan

$os = Get-CimInstance Win32_OperatingSystem
if (-not [Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') {
    $critical.Add('This package requires 64-bit Windows.')
} elseif ([version]$os.Version -lt [version]'10.0') {
    $critical.Add("Windows $($os.Version) is too old. Windows 10 or 11 x64 is required.")
} else {
    Write-Ok "64-bit Windows: $($os.Caption)"
}

$computer = Get-CimInstance Win32_ComputerSystem
$modules = @()
try { $modules = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop) }
catch { Write-Warn 'Installed RAM capacity could not be read; using OS-visible memory with a hardware-reservation allowance.' }
$memory = Get-MemoryCapacity -VisibleBytes $computer.TotalPhysicalMemory -Modules $modules
$ramGiB = [math]::Round($memory.VisibleBytes / 1GB, 2)
if ($memory.Reliable) { Write-Host "[RAM] Installed: $([math]::Round($memory.InstalledBytes / 1GB, 2)) GiB; OS-visible: $ramGiB GiB (not current free memory)." }
if ($ramGiB -ge 22) {
    Write-Ok "Physical memory: $ramGiB GiB (24 GB class)"
} elseif ($memory.MeetsMinimum) {
    Write-Warn "Physical memory: $ramGiB GiB. H3 may page heavily; 24 GB or more is preferred."
} else {
    $critical.Add("Only $ramGiB GiB OS-visible RAM detected and no confirmed 16 GB installed capacity. At least a 16 GB class system is required; 24 GB or more is recommended.")
}

try {
    $paging = Get-PagefileStatus -ComputerSystem (Get-CimInstance Win32_ComputerSystem) `
        -Usage @(Get-CimInstance Win32_PageFileUsage -ErrorAction Stop) `
        -Settings @(Get-CimInstance Win32_PageFileSetting -ErrorAction Stop)
    if ($paging.Managed) {
        Write-Ok "Windows virtual memory is system-managed (currently allocated: $($paging.AllocatedMiB) MiB)."
    } elseif ($paging.AllocatedMiB -ge 32768) {
        Write-Ok "Manual page file is at least 32 GiB (currently allocated: $($paging.AllocatedMiB) MiB)."
    } else {
        Write-Warn "Only $($paging.AllocatedMiB) MiB of active page file detected. Installation can continue, but video generation may run out of memory."
        Write-Warn 'Before generation, open 07-OPEN-PAGEFILE-SETTINGS.cmd, enable system-managed paging on a drive with enough free space, apply and restart Windows. No script editing is needed.'
    }
} catch {
    Write-Warn "Could not query Windows virtual memory: $($_.Exception.Message)"
    Write-Warn 'Installation can continue. Check system-managed paging using 07-OPEN-PAGEFILE-SETTINGS.cmd before generating video; restart after changing it.'
}

$nvidiaSmiCommand = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
$nvidiaSmiPath = if ($nvidiaSmiCommand) { $nvidiaSmiCommand.Source } else { '' }
if (-not $nvidiaSmiPath) {
    $candidate = Join-Path $env:ProgramFiles 'NVIDIA Corporation\NVSMI\nvidia-smi.exe'
    if (Test-Path $candidate) { $nvidiaSmiPath = $candidate }
}

if (-not $nvidiaSmiPath) {
    $critical.Add('nvidia-smi was not found. Install/update the NVIDIA driver first.')
} else {
    $gpuRows = & $nvidiaSmiPath --query-gpu=index,name,memory.total,driver_version,compute_cap,uuid --format=csv,noheader,nounits
    if ($LASTEXITCODE -ne 0) {
        $critical.Add('nvidia-smi could not query the GPU. Reinstall the NVIDIA driver.')
    } else {
        $gpus = foreach ($row in $gpuRows) {
            Write-Host "[GPU]  $row" -ForegroundColor Cyan
            $parts = $row -split ','
            if ($parts.Count -lt 6) { continue }
            if ($parts[2].Trim() -notmatch '^\d+$' -or $parts[4].Trim() -notmatch '^\d+\.\d+$' -or $parts[5].Trim() -notmatch '^GPU-[0-9a-fA-F-]{36}$') {
                Write-Warn 'Skipped a GPU with unavailable memory, compute capability or UUID.'
                continue
            }
            [pscustomobject]@{
                Index = [int]$parts[0].Trim()
                Uuid = $parts[5].Trim()
                Name = $parts[1].Trim()
                MemoryMiB = [int]$parts[2].Trim()
                Driver = $parts[3].Trim()
                ComputeCapability = [double]::Parse($parts[4].Trim(), [Globalization.CultureInfo]::InvariantCulture)
            }
        }
        $selectedGpu = $gpus |
            Where-Object { $_.MemoryMiB -ge 7500 -and $_.ComputeCapability -ge 7.5 } |
            Sort-Object MemoryMiB -Descending |
            Select-Object -First 1
        if (-not $selectedGpu) {
            $critical.Add('No NVIDIA GPU meets both requirements: compute capability 7.5+ (Turing or newer) and at least 7,500 MiB VRAM.')
        } else {
            Write-Ok "Selected GPU $($selectedGpu.Index): $($selectedGpu.Name), $($selectedGpu.MemoryMiB) MiB, compute capability $($selectedGpu.ComputeCapability)"
            if ($selectedGpu.Name -match 'RTX 5050 Laptop') {
                Write-Ok 'Verified baseline detected: RTX 5050 Laptop GPU.'
            } else {
                Write-Ok 'This GPU meets the architecture and VRAM floor. It is a compatibility candidate, not an independently verified device; see COMPATIBILITY.md.'
            }
            $driverMajorMatch = [regex]::Match($selectedGpu.Driver, '^(\d+)')
            if (-not $driverMajorMatch.Success) {
                $critical.Add("Could not parse NVIDIA driver version: $($selectedGpu.Driver)")
            } elseif ([int]$driverMajorMatch.Groups[1].Value -lt 580) {
                $critical.Add("NVIDIA driver $($selectedGpu.Driver) is too old for the CUDA 13 portable build. Install an R580 or newer driver.")
            } else {
                Write-Ok "NVIDIA driver branch is compatible with CUDA 13: $($selectedGpu.Driver)"
            }
        }
    }
}

$videoNames = (Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name) -join ' | '
Write-Host "[VIDEO] $videoNames"
if ($videoNames -match 'Radeon') {
    Write-Ok 'AMD Radeon integrated graphics detected for OBS offload.'
} else {
    Write-Warn 'No Radeon adapter was detected. OBS may use the RTX GPU unless configured manually.'
}

$root = [System.IO.Path]::GetPathRoot($packageRoot)
$drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($root.TrimEnd('\'))'"
$freeGiB = [math]::Round($drive.FreeSpace / 1GB, 1)
$spacePlan = Get-InstallSpacePlan -PackageRoot $packageRoot
$neededGiB = [math]::Ceiling($spacePlan.RequiredBytes / 1GB)
Write-Host "[DISK] Estimated additional space: $neededGiB GiB, including extraction and 8 GiB headroom. Existing downloads are counted by size and will still be hash-verified."
if ($drive.FreeSpace -lt $spacePlan.RequiredBytes) {
    $critical.Add("Only $freeGiB GiB free on $root; this installation/resume needs approximately $neededGiB GiB more. Free space or move the complete folder to another drive.")
} elseif ($freeGiB -ge 90) {
    Write-Ok "Free space on ${root}: $freeGiB GiB"
} else {
    Write-Warn "Free space on ${root}: $freeGiB GiB; enough for the remaining installation estimate. Leave additional room for page-file growth and video generation."
}

$curlCommand = Get-Command curl.exe -ErrorAction SilentlyContinue
if (-not $curlCommand) {
    $critical.Add('Windows curl.exe was not found; the resumable downloader cannot run.')
} else {
    $assets = Get-Content -Raw -LiteralPath (Join-Path $packageRoot 'assets-manifest.json') | ConvertFrom-Json
    $models = Get-Content -Raw -LiteralPath (Join-Path $packageRoot 'models-manifest.json') | ConvertFrom-Json
    $networkChecks = @($assets.remoteFiles[0].url, $models.files[0].url)
    foreach ($url in $networkChecks) {
        & $curlCommand.Source --silent --show-error --head --location --fail --max-time 30 --output NUL $url
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Network access: $(([uri]$url).Host)"
        } else {
            $critical.Add("Cannot reach required download host: $(([uri]$url).Host). This is separate from RAM/GPU checks. Check connectivity, proxy/firewall settings and retry; do not edit out verification checks.")
        }
    }
}

if ($critical.Count -gt 0) {
    Write-Host "`nCritical problems:" -ForegroundColor Red
    foreach ($item in $critical) { Write-Fail $item }
    exit 1
}

$runtimeRoot = Join-Path $packageRoot 'runtime'
if (-not (Test-Path -LiteralPath $runtimeRoot)) {
    New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
}
Set-Content -LiteralPath (Join-Path $runtimeRoot 'selected-gpu.txt') -Value $selectedGpu.Uuid -Encoding ASCII
Write-Ok "GPU selection saved for launchers: $($selectedGpu.Uuid)"

Write-Host "`nPreflight passed. Keep AC power connected and close heavy apps before generation." -ForegroundColor Green
exit 0
