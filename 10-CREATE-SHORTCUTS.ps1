[CmdletBinding()]
param(
    [string]$OutputRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $packageRoot '03-LAUNCH-STABLE.cmd'
if (-not (Test-Path -LiteralPath $launcher)) {
    throw "Launcher is missing: $launcher"
}

if ($OutputRoot) {
    $desktop = Join-Path $OutputRoot 'Desktop'
    $programs = Join-Path $OutputRoot 'StartMenu'
} else {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $programs = [Environment]::GetFolderPath('Programs')
}

if (-not $desktop -or -not $programs) {
    throw 'Windows could not resolve the current user Desktop or Start Menu folder.'
}

$startMenuFolder = Join-Path $programs 'MiniMax H3'
$destinations = @(
    (Join-Path $desktop 'MiniMax H3 ComfyUI.lnk'),
    (Join-Path $startMenuFolder 'MiniMax H3 ComfyUI.lnk')
)

$shell = New-Object -ComObject WScript.Shell
foreach ($destination in $destinations) {
    $parent = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $shortcut = $shell.CreateShortcut($destination)
    $shortcut.TargetPath = $launcher
    $shortcut.WorkingDirectory = $packageRoot
    $shortcut.Description = 'Open the MiniMax H3 ComfyUI installed in this folder'
    $shortcut.Save()
    if (-not (Test-Path -LiteralPath $destination)) {
        throw "Shortcut could not be created: $destination"
    }
    Write-Host "[OK] Shortcut: $destination" -ForegroundColor Green
}

Write-Host "Shortcuts point to this installation: $packageRoot" -ForegroundColor Cyan
Write-Host 'If the complete installation folder is moved, rerun this script from the new location.' -ForegroundColor Yellow
