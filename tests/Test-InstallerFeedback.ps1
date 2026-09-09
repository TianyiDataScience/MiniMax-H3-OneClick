Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# Load only function definitions; never run installation, preflight, or downloads.
foreach ($script in @('01-PREFLIGHT.ps1', '02-INSTALL.ps1')) {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $script), [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw 'Syntax error' }
    foreach ($fn in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
        . ([scriptblock]::Create($fn.Extent.Text))
    }
}

$manual = [pscustomobject]@{ AutomaticManagedPagefile = $false }
$auto = [pscustomobject]@{ AutomaticManagedPagefile = $true }
$empty = Get-PagefileStatus -ComputerSystem $manual
if ($empty.Managed -or $empty.AllocatedMiB -ne 0) { throw 'Empty query regression' }
$global = Get-PagefileStatus -ComputerSystem $auto
if (-not $global.Managed) { throw 'Global system management regression' }
$drive = Get-PagefileStatus -ComputerSystem $manual -Settings @([pscustomobject]@{ InitialSize = 0; MaximumSize = 0 })
if (-not $drive.Managed) { throw 'Per-drive system management regression' }
$multiple = Get-PagefileStatus -ComputerSystem $manual -Usage @([pscustomobject]@{ AllocatedBaseSize = 16384 }, [pscustomobject]@{ AllocatedBaseSize = 16384 })
if ($multiple.Managed -or $multiple.AllocatedMiB -ne 32768) { throw 'Multiple page files regression' }

$manifest = Get-Content -Raw (Join-Path $root 'assets-manifest.json') | ConvertFrom-Json
$asset = @($manifest.remoteFiles | Where-Object name -eq '7zr.exe')[0]
if ($asset.url -ne "https://github.com/ip7z/7zip/releases/download/$($asset.version)/7zr.exe") { throw 'Extractor URL must pin the declared official version' }

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('h3-feedback-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$target = Join-Path $testRoot 'download.bin'
# Simulate a server returning the wrong complete file; the second call is clean.
function curl.exe {
    $outputIndex = [array]::IndexOf($args, '--output')
    [IO.File]::WriteAllBytes($args[$outputIndex + 1], [byte[]]@(1, 2, 3))
    $global:LASTEXITCODE = 0
}
try {
    Invoke-ResumableDownload -Url 'https://example.invalid/test' -Destination $target -ExpectedBytes 4
    throw 'Expected size rejection'
} catch {
    if ($_.Exception.Message -notlike 'Size mismatch*') { throw }
}
if (Test-Path "$target.part") { throw 'Invalid completed partial was not quarantined' }
if (@(Get-ChildItem $testRoot -Filter '*.bad-*').Count -ne 1) { throw 'Invalid file was not preserved' }
Invoke-ResumableDownload -Url 'https://example.invalid/test' -Destination $target -ExpectedBytes 3
if ((Get-Item $target).Length -ne 3) { throw 'Clean retry failed' }
Write-Host '[OK] Empty/global/per-drive/multiple paging, pinned extractor, invalid download preservation and clean retry.'
