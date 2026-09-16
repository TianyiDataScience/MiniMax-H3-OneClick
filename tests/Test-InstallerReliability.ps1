Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'installer-common.ps1')
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root '02-INSTALL.ps1'), [ref]$tokens, [ref]$errors)
foreach ($fn in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
    . ([scriptblock]::Create($fn.Extent.Text))
}
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Expect-Error([scriptblock]$Action, [string]$Pattern) {
    try { & $Action } catch { if ($_.Exception.Message -like $Pattern) { return }; throw }
    throw "Expected error: $Pattern"
}

$ram = Get-MemoryCapacity -VisibleBytes ([long](15.22GB)) -Modules @([pscustomobject]@{Capacity=8GB},[pscustomobject]@{Capacity=8GB})
Assert ($ram.MeetsMinimum -and $ram.Reliable -and $ram.InstalledBytes -eq 16GB) 'Nominal 16GB regression'
Assert (Get-MemoryCapacity -VisibleBytes ([long](15.22GB))).MeetsMinimum 'Fallback capacity tolerance'
Assert (-not (Get-MemoryCapacity -VisibleBytes 12GB -Modules @([pscustomobject]@{Capacity=12GB})).MeetsMinimum) 'Genuine 12GB must fail'
Assert (-not (Get-MemoryCapacity -VisibleBytes 8GB).MeetsMinimum) '8GB must fail'

$uuidA = 'GPU-11111111-1111-1111-1111-111111111111'
$uuidB = 'GPU-22222222-2222-2222-2222-222222222222'
$rows = @("0, $uuidA", "1, $uuidB")
Assert ((Resolve-GpuSelection -Selection '1' -Rows $rows) -eq $uuidB) 'Legacy index migration'
Assert ((Resolve-GpuSelection -Selection $uuidB -Rows @("0, $uuidB", "1, $uuidA")) -eq $uuidB) 'UUID must survive reordered devices'
Expect-Error { Resolve-GpuSelection -Selection '9' -Rows $rows } 'The saved GPU*'

$main = 'D:\AI\MiniMax-H3\runtime\ComfyUI_windows_portable\ComfyUI\main.py'
$userPath = 'D:\AI\MiniMax-H3\runtime\ComfyUI_windows_portable\ComfyUI\user'
$stats = [pscustomobject]@{system=[pscustomobject]@{argv=@($main,'--user-directory',$userPath,'--cuda-device',$uuidA)}}
Assert (Test-ComfyServerIdentity $stats $main $userPath $uuidA) 'Matching instance should be reusable'
Assert (-not (Test-ComfyServerIdentity $stats 'E:\Other\main.py' $userPath $uuidA)) 'Other install must not be reused'
Assert (-not (Test-ComfyServerIdentity $stats $main $userPath $uuidB)) 'Other GPU must not be reused'
Assert (-not (Test-ComfyServerIdentity $stats $main 'D:\OtherUser' $uuidA)) 'Other user directory must not be reused'
foreach ($invalid in @($null, [pscustomobject]@{}, [pscustomobject]@{system=$null}, [pscustomobject]@{system=[pscustomobject]@{argv=@($main,'--cuda-device')}})) {
    Assert (-not (Test-ComfyServerIdentity $invalid $main $userPath $uuidA)) 'Malformed/older server should be rejected safely'
}

$manifest = Get-Content -Raw (Join-Path $root 'models-manifest.json') | ConvertFrom-Json
Assert ($manifest.revision -match '^[0-9a-f]{40}$') 'Model revision must be immutable'
foreach ($file in $manifest.files) { Assert ($file.url.Contains('/resolve/' + $manifest.revision + '/')) 'All model URLs must pin the revision' }

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $tempBase ('h3-reliability-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$script:curlCalls = 0
$script:downloadMode = 'ok'
$payload = [byte[]]@(1,2,3,4)
$hasher = [Security.Cryptography.SHA256]::Create()
try { $hash = ([BitConverter]::ToString($hasher.ComputeHash($payload))).Replace('-','').ToLowerInvariant() } finally { $hasher.Dispose() }
function curl.exe {
    $script:curlCalls++
    $outputIndex = [array]::IndexOf($args, '--output')
    $path = $args[$outputIndex+1]
    if ($script:downloadMode -eq 'network') { $global:LASTEXITCODE = 7; return '000' }
    if ($script:downloadMode -in @('range33','range416') -and $script:curlCalls -eq 1) {
        $global:LASTEXITCODE = if ($script:downloadMode -eq 'range33') { 33 } else { 22 }
        return '416'
    }
    if ($script:downloadMode -like 'range*' -and $script:curlCalls -eq 2) {
        Assert (-not ($args -contains '--continue-at')) 'Range fallback must start from byte zero'
    }
    $bytes = if ($script:downloadMode -eq 'badhash') { [byte[]]@(9,9,9,9) } else { $payload }
    [IO.File]::WriteAllBytes($path, $bytes)
    $global:LASTEXITCODE = 0
    return '200'
}
try {
    $target = Join-Path $testRoot 'complete.bin'
    [IO.File]::WriteAllBytes("$target.part", $payload)
    Invoke-ResumableDownload 'https://example.invalid/test' $target 4 $hash
    Assert ($script:curlCalls -eq 0 -and (Test-Path $target)) 'Complete valid partial should not redownload'
    Invoke-ResumableDownload 'https://example.invalid/test' $target 4 $hash
    Assert ($script:curlCalls -eq 0) 'Verified destination should be skipped'

    foreach ($mode in @('oversize','complete-corrupt','range33','range416','network','badhash')) {
        $target = Join-Path $testRoot "$mode.bin"
        $script:curlCalls = 0
        $script:downloadMode = $mode
        if ($mode -eq 'oversize') { [IO.File]::WriteAllBytes("$target.part", [byte[]]@(1,2,3,4,5)) }
        elseif ($mode -eq 'complete-corrupt') { [IO.File]::WriteAllBytes("$target.part", [byte[]]@(9,9,9,9)) }
        elseif ($mode -ne 'badhash') { [IO.File]::WriteAllBytes("$target.part", [byte[]]@(1,2)) }
        if ($mode -eq 'network') {
            Expect-Error { Invoke-ResumableDownload 'https://example.invalid/test' $target 4 $hash } 'Download failed*'
            Assert ((Get-Item "$target.part").Length -eq 2 -and $script:curlCalls -eq 1) 'Ordinary network error must preserve progress without clean retry'
        } elseif ($mode -eq 'badhash') {
            Expect-Error { Invoke-ResumableDownload 'https://example.invalid/test' $target 4 $hash } 'SHA-256 mismatch*'
            Assert (-not (Test-Path "$target.part")) 'Bad hash must be quarantined'
        } else {
            Invoke-ResumableDownload 'https://example.invalid/test' $target 4 $hash
            Assert ((Get-FileHash $target).Hash -ieq $hash) "Recovery failed: $mode"
            if ($mode -like 'range*') { Assert ($script:curlCalls -eq 2) 'Exactly one clean fallback required' }
            Assert (@(Get-ChildItem $testRoot -Filter "$mode.bin.bad-*").Count -eq 1) "Preservation failed: $mode"
        }
    }

    $sizePath = Join-Path $testRoot 'size.bin'
    Assert ((Get-RemainingDownloadBytes $sizePath 100) -eq 100) 'Missing file space'
    [IO.File]::WriteAllBytes("$sizePath.part", [byte[]]@(1,2,3,4))
    Assert ((Get-RemainingDownloadBytes $sizePath 100) -eq 96) 'Resume should count only remaining bytes'
    Assert ((Get-RemainingDownloadBytes $sizePath 3) -eq 3) 'Oversized partial cannot count as valid data'

    $fresh = Get-InstallSpacePlan -PackageRoot $root
    Assert ($fresh.RequiredBytes -gt 60GB -and $fresh.RequiredBytes -lt 65GB) 'Fresh installation space estimate'
    $fixtureModels = @{files=@(@{relativePath='models/test.bin';sizeBytes=4})}
    $fixtureModels | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $testRoot 'models-manifest.json')
    Copy-Item (Join-Path $root 'assets-manifest.json') $testRoot
    $portable = Join-Path $testRoot 'runtime\ComfyUI_windows_portable'
    foreach ($relative in @('ComfyUI\main.py','python_embeded\python.exe','python_embeded\Lib\site-packages\transformers\models\audio_spectrogram_transformer\configuration_audio_spectrogram_transformer.py','ComfyUI\models\test.bin')) {
        $path = Join-Path $portable $relative
        New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
        [IO.File]::WriteAllBytes($path, $payload)
    }
    $resume = Get-InstallSpacePlan -PackageRoot $testRoot
    Assert ($resume.DownloadBytes -eq 0 -and $resume.ExtractionBytes -eq 0 -and $resume.RequiredBytes -eq 8GB) 'Complete resume must not require another 65GiB'
    Expect-Error { Assert-DownloadSpace -Destination (Join-Path $testRoot 'huge.bin') -ExpectedBytes ([long]::MaxValue / 2) } 'Not enough free space*'

    foreach ($case in @('nominal16','ram12','turing','ampere','ada','blackwell','pascal','low-vram','old-driver','multi-gpu','network','disk40')) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Invoke-PreflightFixture.ps1') -Repository $root -Case $case
        $expected = if ($case -in @('ram12','pascal','low-vram','old-driver','network','disk40')) { 1 } else { 0 }
        Assert ($LASTEXITCODE -eq $expected) "Preflight scenario $case exit code $LASTEXITCODE; expected $expected"
    }
    Write-Host '[OK] RAM capacity, GPU UUID, instance identity, immutable URLs, download recovery, disk estimates and 12 full preflight scenarios.'
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    if ($resolved.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -and $resolved -ne $tempBase -and (Test-Path -LiteralPath $resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
