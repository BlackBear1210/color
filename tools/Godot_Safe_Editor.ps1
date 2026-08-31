param()

$ErrorActionPreference = "Stop"

# Keep this launcher ASCII-only because Windows PowerShell 5.1 may misread UTF-8 text.
$nativeCode = @'
using System;
using System.Runtime.InteropServices;
public static class GodotEditorSafeMode {
    [DllImport("kernel32.dll")]
    public static extern uint SetErrorMode(uint mode);
}
'@
Add-Type -TypeDefinition $nativeCode

# Child Godot processes inherit this: report failures in the console instead of a modal crash dialog.
[GodotEditorSafeMode]::SetErrorMode(0x0003) | Out-Null

$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = "C:\\Users\\Public\\godot46\\Godot_v4.6.3-stable_win64_console.exe"
$logPath = Join-Path $projectRoot ".godot\\godot_editor_safe.log"

if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) {
    throw "Safe editor stopped: the console Godot executable is missing. It will not fall back to the graphical executable."
}

# Force the stable 2D OpenGL path even if a machine-level editor setting requests D3D12.
& $godot --editor --rendering-method gl_compatibility --audio-driver Dummy --path $projectRoot --log-file $logPath
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    Write-Host "Godot stopped with exit code $exitCode. Log: $logPath" -ForegroundColor Red
    exit $exitCode
}
