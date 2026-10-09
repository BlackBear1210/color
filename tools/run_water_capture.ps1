param([string]$Label = 'before')
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class WaterCaptureErrorMode { [DllImport("kernel32.dll")] public static extern uint SetErrorMode(uint mode); }'
[WaterCaptureErrorMode]::SetErrorMode(3) | Out-Null
$rootDir = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $rootDir 'docs/visual_review/water_reference_20261008'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$enginePath = 'C:/Users/아버지/Desktop/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe'
$engineArgs = @('--path', ('"' + $rootDir + '"'), '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--resolution', '1920x1080', '--position','0,0','--log-file', ('"' + (Join-Path $logDir ($Label + '.log')) + '"'), '-s', 'res://tools/capture_water_reference.gd', '--', $Label)
$taskProcess = Start-Process -FilePath $enginePath -ArgumentList $engineArgs -WindowStyle Hidden -PassThru
$taskProcess.Id | Set-Content (Join-Path $logDir 'capture.pid')
Write-Output ('Capture PID ' + $taskProcess.Id)

