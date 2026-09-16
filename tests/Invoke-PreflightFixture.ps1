param([string]$Repository, [string]$Case)
$ErrorActionPreference = 'Stop'
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$caseRoot = Join-Path $tempBase ('h3-preflight-' + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $caseRoot | Out-Null
foreach ($name in @('01-PREFLIGHT.ps1','installer-common.ps1','models-manifest.json','assets-manifest.json')) {
    Copy-Item -LiteralPath (Join-Path $Repository $name) -Destination $caseRoot
}
function Get-CimInstance {
    param($ClassName, $Filter, $ErrorAction)
    switch ($ClassName) {
        'Win32_OperatingSystem' { [pscustomobject]@{Version='10.0.26200';Caption='Windows test fixture'} }
        'Win32_ComputerSystem' { [pscustomobject]@{TotalPhysicalMemory=$(if ($Case -eq 'nominal16') {15.22GB} elseif ($Case -eq 'ram12') {12GB} else {24GB});AutomaticManagedPagefile=$true} }
        'Win32_PhysicalMemory' { [pscustomobject]@{Capacity=$(if ($Case -eq 'nominal16') {16GB} elseif ($Case -eq 'ram12') {12GB} else {24GB})} }
        'Win32_PageFileUsage' { }
        'Win32_PageFileSetting' { }
        'Win32_VideoController' { [pscustomobject]@{Name='NVIDIA fixture'} }
        'Win32_LogicalDisk' { [pscustomobject]@{FreeSpace=$(if ($Case -eq 'disk40') {40GB} else {100GB})} }
        default { throw "Unexpected CIM query $ClassName" }
    }
}
function Get-Command {
    param($Name, $ErrorAction)
    if ($Name -eq 'nvidia-smi.exe') { [pscustomobject]@{Source='Fixture-Smi'} }
    elseif ($Name -eq 'curl.exe') { [pscustomobject]@{Source='Fixture-Curl'} }
    else { throw "Unexpected command $Name" }
}
function Fixture-Smi {
    $global:LASTEXITCODE=0
    $uuid = 'GPU-11111111-1111-1111-1111-111111111111'
    switch ($Case) {
        'turing' {"0, NVIDIA GeForce RTX 2080, 8192, 592.82, 7.5, $uuid"}
        'ampere' {"0, NVIDIA GeForce RTX 3060, 12288, 592.82, 8.6, $uuid"}
        'ada' {"0, NVIDIA GeForce RTX 4060, 8192, 592.82, 8.9, $uuid"}
        'pascal' {"0, NVIDIA GeForce GTX 1080, 8192, 592.82, 6.1, $uuid"}
        'low-vram' {"0, NVIDIA GeForce RTX 4050 Laptop GPU, 6144, 592.82, 8.9, $uuid"}
        'old-driver' {"0, NVIDIA GeForce RTX 3060, 12288, 576.80, 8.6, $uuid"}
        'multi-gpu' { "0, NVIDIA GeForce RTX 4050 Laptop GPU, 6144, 592.82, 8.9, $uuid"; '1, NVIDIA GeForce RTX 3090, 24576, 592.82, 8.6, GPU-22222222-2222-2222-2222-222222222222' }
        default {"0, NVIDIA GeForce RTX 5050 Laptop GPU, 8151, 592.82, 12.0, $uuid"}
    }
}
function Fixture-Curl { $global:LASTEXITCODE = if ($Case -eq 'network') {7} else {0} }
try {
    & (Join-Path $caseRoot '01-PREFLIGHT.ps1')
    $code = $LASTEXITCODE
    if ($code -eq 0) {
        $selected = (Get-Content -Raw (Join-Path $caseRoot 'runtime\selected-gpu.txt')).Trim()
        $expected = if ($Case -eq 'multi-gpu') {'GPU-22222222-2222-2222-2222-222222222222'} else {'GPU-11111111-1111-1111-1111-111111111111'}
        if ($selected -ne $expected) { throw 'Preflight saved the wrong GPU UUID' }
    }
} finally {
    $resolved = [IO.Path]::GetFullPath($caseRoot)
    if ($resolved.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -and $resolved -ne $tempBase -and (Test-Path -LiteralPath $resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
exit $code
