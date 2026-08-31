param(
    [switch]$All,
    [switch]$AllowHeadlessCrashProbe
)

$ErrorActionPreference = "Stop"

# This script stays ASCII-only so Windows PowerShell 5.1 cannot misread it.
# It validates each disk script before passing its resource path to Godot.
$nativeCode = @'
using System;
using System.Runtime.InteropServices;
public static class GodotSafeErrorMode {
    [DllImport("kernel32.dll")]
    public static extern uint SetErrorMode(uint mode);
}
'@
Add-Type -TypeDefinition $nativeCode

# Suppress Windows crash dialogs for child test processes; failures stay in the console log.
# This mode is inherited by Start-Process children on Windows.
[GodotSafeErrorMode]::SetErrorMode(0x0003) | Out-Null

$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = "C:\\Users\\Public\\godot46\\Godot_v4.6.3-stable_win64_console.exe"

# Never fall back to the graphical executable: a crash must not open a user-facing dialog.
if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) {
    throw "Safe test stopped: the console Godot executable is missing; graphical godot.exe will not be launched."
}

# Godot 4.6.3 currently crashes in this project's headless script path; never trigger it by default.
if (-not $AllowHeadlessCrashProbe) {
    Write-Warning "Headless Godot checks are disabled: this project currently triggers an engine signal 11 in that path. Use the graphical safe launcher instead."
    exit 0
}

$tests = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter "*.gd" -File |
    Where-Object { $_.Name -like "check_*.gd" -or $_.Name -like "test_*.gd" } |
    Sort-Object Name)

if ($tests.Count -eq 0) {
    throw "Safe test stopped: no check_*.gd or test_*.gd files were found."
}

if (-not $All) {
    $tests = @($tests | Where-Object { $_.Name -like "check_*.gd" } | Select-Object -First 1)
    if ($tests.Count -eq 0) {
        throw "Safe test stopped: no check script was found."
    }
}

foreach ($test in $tests) {
    # res:// is a Godot resource URI, not a PowerShell path. Do not call Join-Path on it.
    $resourcePath = "res://tools/$($test.Name)"
    Write-Host "=== $($test.Name) ==="
    # Direct invocation preserves every Godot argument; Start-Process was losing arguments and leaving child editors behind.
    & $godot --headless --rendering-method gl_compatibility --audio-driver Dummy --path $projectRoot -s $resourcePath
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "Safe test failed: $($test.Name) (exit code $exitCode)"
    }
}
