function Get-MemoryCapacity {
    param([long]$VisibleBytes, [object[]]$Modules = @())
    [long]$installed = 0
    foreach ($module in $Modules) {
        if ($null -ne $module -and $module.Capacity -gt 0) { $installed += [long]$module.Capacity }
    }
    $reliable = $installed -ge $VisibleBytes -and $installed -gt 0
    # Fall back to visible memory with a small hardware-reservation allowance.
    $meetsMinimum = if ($reliable) { $installed -ge 16GB } else { $VisibleBytes -ge 15GB }
    [pscustomobject]@{ InstalledBytes=$installed; VisibleBytes=$VisibleBytes; Reliable=$reliable; MeetsMinimum=$meetsMinimum }
}

function Get-RemainingDownloadBytes {
    param([string]$Path, [long]$ExpectedBytes)
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        if ((Get-Item -LiteralPath $Path).Length -eq $ExpectedBytes) { return [long]0 }
    }
    $partial = "$Path.part"
    if (Test-Path -LiteralPath $partial -PathType Leaf) {
        $length = (Get-Item -LiteralPath $partial).Length
        if ($length -gt 0 -and $length -le $ExpectedBytes) { return [long]($ExpectedBytes - $length) }
    }
    return $ExpectedBytes
}

function Get-InstallSpacePlan {
    param([string]$PackageRoot)
    $portable = Join-Path $PackageRoot 'runtime\ComfyUI_windows_portable'
    $models = Get-Content -Raw -LiteralPath (Join-Path $PackageRoot 'models-manifest.json') | ConvertFrom-Json
    [long]$remaining = 0
    foreach ($file in $models.files) {
        $remaining += Get-RemainingDownloadBytes -Path (Join-Path "$portable\ComfyUI" $file.relativePath) -ExpectedBytes $file.sizeBytes
    }
    $runtimeReady = (Test-Path -LiteralPath "$portable\ComfyUI\main.py") -and
        (Test-Path -LiteralPath "$portable\python_embeded\python.exe") -and
        (Test-Path -LiteralPath "$portable\python_embeded\Lib\site-packages\transformers\models\audio_spectrogram_transformer\configuration_audio_spectrogram_transformer.py")
    [long]$extraction = 0
    if (-not $runtimeReady) {
        $assets = Get-Content -Raw -LiteralPath (Join-Path $PackageRoot 'assets-manifest.json') | ConvertFrom-Json
        $archive = $assets.remoteFiles | Where-Object name -eq 'ComfyUI_windows_portable_nvidia.7z'
        $remaining += Get-RemainingDownloadBytes -Path (Join-Path $PackageRoot 'runtime\downloads\ComfyUI_windows_portable_nvidia.7z') -ExpectedBytes $archive.sizeBytes
        $extraction = 12GB
    }
    # Includes space for generated files; page-file growth may need more.
    [pscustomobject]@{ RequiredBytes=($remaining + $extraction + 8GB); DownloadBytes=$remaining; ExtractionBytes=$extraction }
}

function Resolve-GpuSelection {
    param([string]$Selection, [string[]]$Rows)
    foreach ($row in $Rows) {
        $parts = $row -split ','
        if ($parts.Count -ne 2) { continue }
        $index = $parts[0].Trim()
        $uuid = $parts[1].Trim()
        if ($uuid -match '^GPU-[0-9a-fA-F-]{36}$' -and ($Selection -eq $uuid -or $Selection -eq $index)) { return $uuid }
    }
    throw 'The saved GPU is missing or invalid. Run 00-START-HERE.cmd again to select an available NVIDIA GPU.'
}

function Get-SelectedGpuUuid {
    param([string]$PackageRoot)
    $selectionPath = Join-Path $PackageRoot 'runtime\selected-gpu.txt'
    if (-not (Test-Path -LiteralPath $selectionPath)) { throw 'GPU selection is missing. Run 00-START-HERE.cmd first.' }
    $selection = (Get-Content -Raw -LiteralPath $selectionPath).Trim()
    $command = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
    $smi = if ($command) { $command.Source } else { Join-Path $env:ProgramFiles 'NVIDIA Corporation\NVSMI\nvidia-smi.exe' }
    $rows = & $smi --query-gpu=index,uuid --format=csv,noheader
    if ($LASTEXITCODE -ne 0) { throw 'Cannot query NVIDIA GPU identifiers. Check the NVIDIA driver.' }
    Resolve-GpuSelection -Selection $selection -Rows @($rows)
}

function Test-ComfyServerIdentity {
    param($Stats, [string]$MainPath, [string]$UserPath, [string]$GpuUuid)
    if ($null -eq $Stats -or -not $Stats.PSObject.Properties['system'] -or $null -eq $Stats.system -or -not $Stats.system.PSObject.Properties['argv']) { return $false }
    $arguments = @($Stats.system.argv)
    if ($arguments.Count -lt 1 -or $arguments[0] -ine $MainPath) { return $false }
    $userIndex = [array]::IndexOf($arguments, '--user-directory')
    $gpuIndex = [array]::IndexOf($arguments, '--cuda-device')
    return $userIndex -ge 0 -and $userIndex + 1 -lt $arguments.Count -and
        $gpuIndex -ge 0 -and $gpuIndex + 1 -lt $arguments.Count -and
        $arguments[$userIndex + 1] -ieq $UserPath -and $arguments[$gpuIndex + 1] -eq $GpuUuid
}
