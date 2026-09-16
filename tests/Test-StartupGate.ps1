Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
$comfyRoot = Join-Path $packageRoot 'fixture-comfy'
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $packageRoot '05-VERIFY.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Verification script syntax error' }
$blocks = @($ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.IfStatementAst] -and
    $node.Extent.Text.StartsWith('if (-not $failed)') -and $node.Extent.Text.Contains('runtime-probe.py')
}, $true))
if ($blocks.Count -ne 1) { throw 'Expected exactly one startup verification gate' }
# Execute the real gate, replacing only the native Python invocation with fixtures.
$gateText = $blocks[0].Extent.Text
if (-not $gateText.Contains('& $pythonPath -s')) { throw 'Native invocation pattern changed; update the test fixture' }
$gate = [scriptblock]::Create($gateText.Replace('& $pythonPath -s', 'Invoke-StartupProbeFixture -s'))
function Invoke-StartupProbeFixture {
    if ($script:mode -eq 'throws') { throw 'Fixture executable failed to start' }
    $global:LASTEXITCODE = if ($script:mode -eq 'nonzero') {7} else {0}
    if ($script:mode -eq 'malformed') { return 'not-json' }
    if ($script:mode -eq 'missing-field') { return '{"reason":"fixture"}' }
    $ok = $script:mode -in @('success','nonzero')
    return (@{startup_ok=$ok; reason='fixture'; details='fixture dependency failure'} | ConvertTo-Json -Compress)
}
foreach ($script:mode in @('success','nonzero','reported-failure','malformed','missing-field','throws')) {
    $failed = $false
    . $gate 6>$null
    if ($failed -ne ($script:mode -ne 'success')) { throw "Incorrect startup readiness result: $script:mode" }
}
Write-Host '[OK] Real PowerShell startup gate rejects nonzero exit, reported failure, malformed/missing JSON and launch exceptions.'
exit 0
