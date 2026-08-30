[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

function Write-Ok([string]$Message) { Write-Host "[OK]   $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Fail([string]$Message) { Write-Host "[FAIL] $Message" -ForegroundColor Red }

$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
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

Write-Host "`n=== MiniMax H3 / Windows NVIDIA preflight ===" -ForegroundColor Cyan

$os = Get-CimInstance Win32_OperatingSystem
if (-not [Environment]::Is64BitOperatingSystem) {
    $critical.Add('This package requires 64-bit Windows.')
} elseif ([version]$os.Version -lt [version]'10.0') {
    $critical.Add("Windows $($os.Version) is too old. Windows 10 or 11 x64 is required.")
} else {
    Write-Ok "64-bit Windows: $($os.Caption)"
}

$ramGiB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
if ($ramGiB -ge 22) {
    Write-Ok "Physical memory: $ramGiB GiB (24 GB class)"
} elseif ($ramGiB -ge 16) {
    Write-Warn "Physical memory: $ramGiB GiB. H3 may page heavily; 24 GB or more is preferred."
} else {
    $critical.Add("Only $ramGiB GiB RAM detected; this package is not intended for that configuration.")
}

$automaticPagefile = (Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile
$pagefileMiB = [int](Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue | Measure-Object -Property AllocatedBaseSize -Sum).Sum
if ($automaticPagefile) {
    Write-Ok "Windows virtual memory is system-managed (currently allocated: $pagefileMiB MiB)."
} elseif ($pagefileMiB -ge 32768) {
    Write-Ok "Manual page file is at least 32 GiB (currently allocated: $pagefileMiB MiB)."
} else {
    $critical.Add("Virtual memory is not system-managed and only $pagefileMiB MiB is allocated. Enable system-managed paging and restart Windows.")
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
    $gpuRows = & $nvidiaSmiPath --query-gpu=index,name,memory.total,driver_version,compute_cap --format=csv,noheader,nounits
    if ($LASTEXITCODE -ne 0) {
        $critical.Add('nvidia-smi could not query the GPU. Reinstall the NVIDIA driver.')
    } else {
        $gpus = foreach ($row in $gpuRows) {
            Write-Host "[GPU]  $row" -ForegroundColor Cyan
            $parts = $row -split ','
            if ($parts.Count -lt 5) { continue }
            [pscustomobject]@{
                Index = [int]$parts[0].Trim()
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
                Write-Ok 'This GPU meets the installer architecture and VRAM floor. Compare its RTX model tier with the RTX 5050 Laptop baseline in COMPATIBILITY.md.'
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
if ($freeGiB -ge 90) {
    Write-Ok "Free space on ${root}: $freeGiB GiB"
} elseif ($freeGiB -ge 65) {
    Write-Warn "Free space on ${root}: $freeGiB GiB. This is workable but tight; 90+ GiB is recommended."
} else {
    $critical.Add("Only $freeGiB GiB free on $root; at least 65 GiB is required and 90+ GiB is recommended.")
}

$curlCommand = Get-Command curl.exe -ErrorAction SilentlyContinue
if (-not $curlCommand) {
    $critical.Add('Windows curl.exe was not found; the resumable downloader cannot run.')
} else {
    $networkChecks = @(
        'https://github.com/Comfy-Org/ComfyUI/releases/download/v0.34.0/ComfyUI_windows_portable_nvidia.7z',
        'https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_audio_vae_fp32.safetensors?download=true'
    )
    foreach ($url in $networkChecks) {
        & $curlCommand.Source --silent --show-error --head --location --fail --max-time 30 --output NUL $url
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Network access: $(([uri]$url).Host)"
        } else {
            $critical.Add("Cannot reach required download host: $(([uri]$url).Host)")
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
Set-Content -LiteralPath (Join-Path $runtimeRoot 'selected-gpu.txt') -Value $selectedGpu.Index -Encoding ASCII
Write-Ok "GPU selection saved for launchers: physical NVIDIA index $($selectedGpu.Index)"

Write-Host "`nPreflight passed. Keep AC power connected and close heavy apps before generation." -ForegroundColor Green
exit 0
