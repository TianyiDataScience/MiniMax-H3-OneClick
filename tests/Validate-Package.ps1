[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure([string]$Message) { $failures.Add($Message) }

$required = @(
    'LICENSE', 'NOTICE', 'README.md', 'MODEL-LICENSE-NOTICE.md',
    'THIRD-PARTY-NOTICES.md', 'COMPATIBILITY.md', 'SECURITY.md',
    'PRIVACY.md', 'CONTRIBUTING.md', 'RELEASING.md',
    '00-START-HERE.cmd', '01-PREFLIGHT.ps1', '02-INSTALL.ps1',
    '03-LAUNCH-STABLE.cmd', '04-LAUNCH-BALANCED.cmd', '05-VERIFY.ps1',
    '10-CREATE-SHORTCUTS.ps1',
    'models-manifest.json', 'assets-manifest.json',
    'workflows\official\OFFICIAL-H3-T2V.json',
    'workflows\official\OFFICIAL-H3-I2V.json',
    'assets\transparent_rgb_gaming_mouse.png'
)
foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relative))) {
        Add-Failure "Missing required file: $relative"
    }
}

$installerText = Get-Content -Raw -LiteralPath (Join-Path $root '02-INSTALL.ps1')
$verifyText = Get-Content -Raw -LiteralPath (Join-Path $root '05-VERIFY.ps1')
$readmeText = Get-Content -Raw -LiteralPath (Join-Path $root 'README.md')
$expectedWorkflowNames = @(
    'H3-T2V-480P-5s-Turbo8.json',
    'H3-T2V-768P-5s-Turbo8.json',
    'H3-I2V-480P-5s-Turbo8.json'
)
foreach ($name in $expectedWorkflowNames) {
    if ($installerText -notmatch [regex]::Escape($name)) {
        Add-Failure "Installer does not generate workflow preset: $name"
    }
}
foreach ($name in $expectedWorkflowNames) {
    if ($verifyText -notmatch [regex]::Escape($name)) {
        Add-Failure "Verification script does not check workflow preset: $name"
    }
    if ($readmeText -notmatch [regex]::Escape($name)) {
        Add-Failure "README does not document workflow preset: $name"
    }
}
$legacyWorkflowPattern = '(RTX5050|NVIDIA)-H3-(T2V|I2V)-[A-Za-z0-9-]+\.json'
foreach ($relative in @('02-INSTALL.ps1','05-VERIFY.ps1','README.md','RTX5050-ACCEPTANCE-CHECKLIST-ZH.md')) {
    $content = Get-Content -Raw -LiteralPath (Join-Path $root $relative)
    if ($content -match $legacyWorkflowPattern) {
        Add-Failure "Legacy device-prefixed workflow filename found in: $relative"
    }
}

Get-ChildItem -LiteralPath $root -Filter '*.ps1' -File -Recurse | ForEach-Object {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
    foreach ($error in $errors) { Add-Failure "PowerShell syntax: $($_.FullName): $($error.Message)" }
}

Get-ChildItem -LiteralPath $root -Filter '*.json' -File -Recurse | ForEach-Object {
    try { $null = Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json }
    catch { Add-Failure "Invalid JSON: $($_.FullName): $($_.Exception.Message)" }
}

$assetManifest = Get-Content -Raw -LiteralPath (Join-Path $root 'assets-manifest.json') | ConvertFrom-Json
foreach ($file in $assetManifest.files) {
    $path = Join-Path $root ($file.relativePath -replace '/', '\')
    if (-not (Test-Path -LiteralPath $path)) {
        Add-Failure "Manifest asset missing: $($file.relativePath)"
        continue
    }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    if ($hash -ne $file.sha256.ToLowerInvariant()) {
        Add-Failure "Manifest asset hash mismatch: $($file.relativePath)"
    }
}

$forbiddenExtensions = @('.safetensors','.ckpt','.pt','.pth','.onnx','.gguf','.mp4','.mkv','.mov','.webm','.wav','.zip','.7z','.exe')
Get-ChildItem -LiteralPath $root -File -Recurse | ForEach-Object {
    if ($forbiddenExtensions -contains $_.Extension.ToLowerInvariant()) {
        Add-Failure "Forbidden release file: $($_.FullName)"
    }
    if ($_.Length -gt 10MB) { Add-Failure "Unexpected file larger than 10 MiB: $($_.FullName)" }
}

$secretPattern = '(?i)(sk-[a-z0-9_-]{16,}|hf_[a-z0-9]{16,}|AKIA[0-9A-Z]{16}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|authorization\s*:\s*bearer\s+[a-z0-9._-]+)'
$textExtensions = @('.ps1','.cmd','.md','.json','.yml','.yaml','.txt','.gitignore','.gitattributes','.editorconfig')
Get-ChildItem -LiteralPath $root -File -Recurse | Where-Object { $textExtensions -contains $_.Extension -or $_.Name.StartsWith('.') } | ForEach-Object {
    $content = Get-Content -Raw -LiteralPath $_.FullName
    if ($content -match $secretPattern) { Add-Failure "Secret-like value found: $($_.FullName)" }
    if ($_.FullName -ne $MyInvocation.MyCommand.Path -and $content -match 'C:\\Users\\islit|/Users/islit') {
        Add-Failure "Personal path found: $($_.FullName)"
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host "[FAIL] $_" -ForegroundColor Red }
    throw "Package validation failed with $($failures.Count) issue(s)."
}

Write-Host '[OK] Required files, PowerShell syntax, JSON, asset hashes, release hygiene and secret patterns passed.' -ForegroundColor Green
