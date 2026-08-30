[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRoot = Join-Path $tempBase ('MiniMax-H3-shortcut-test-' + [guid]::NewGuid().ToString('N'))
$testPackage = Join-Path $testRoot 'Package'
$testLinks = Join-Path $testRoot 'Links'
$expectedLauncher = [System.IO.Path]::GetFullPath((Join-Path $testPackage '03-LAUNCH-STABLE.cmd'))

try {
    New-Item -ItemType Directory -Path $testPackage -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root '03-LAUNCH-STABLE.cmd') -Destination $expectedLauncher
    Copy-Item -LiteralPath (Join-Path $root '10-CREATE-SHORTCUTS.ps1') -Destination (Join-Path $testPackage '10-CREATE-SHORTCUTS.ps1')
    & (Join-Path $testPackage '10-CREATE-SHORTCUTS.ps1') -OutputRoot $testLinks

    $shortcutPaths = @(
        (Join-Path $testLinks 'Desktop\MiniMax H3 ComfyUI.lnk'),
        (Join-Path $testLinks 'StartMenu\MiniMax H3\MiniMax H3 ComfyUI.lnk')
    )
    $shell = New-Object -ComObject WScript.Shell
    foreach ($path in $shortcutPaths) {
        if (-not (Test-Path -LiteralPath $path)) { throw "Shortcut missing: $path" }
        $shortcut = $shell.CreateShortcut($path)
        if ([System.IO.Path]::GetFullPath($shortcut.TargetPath) -ne $expectedLauncher) {
            throw "Shortcut target mismatch: $($shortcut.TargetPath)"
        }
        if ([System.IO.Path]::GetFullPath($shortcut.WorkingDirectory) -ne [System.IO.Path]::GetFullPath($testPackage)) {
            throw "Shortcut working directory mismatch: $($shortcut.WorkingDirectory)"
        }
    }
    Write-Host '[OK] Desktop and Start Menu shortcuts use the actual package location.' -ForegroundColor Green
} finally {
    $resolved = [System.IO.Path]::GetFullPath($testRoot)
    if ($resolved.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase) -and $resolved -ne $tempBase -and (Test-Path -LiteralPath $resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
