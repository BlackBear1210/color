param([string]$Script, [string]$Label, [switch]$Headless)
$ErrorActionPreference='Stop'
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class WaterCheckErrorMode { [DllImport("kernel32.dll")] public static extern uint SetErrorMode(uint mode); }'
[WaterCheckErrorMode]::SetErrorMode(3) | Out-Null
$rootDir=Split-Path -Parent $PSScriptRoot
$engine='C:/Users/아버지/Desktop/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe'
$log=Join-Path $rootDir ('docs/visual_review/water_reference_20261008/'+$Label+'.log')
$argsList=@('--path',('"'+$rootDir+'"'),'--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution','1920x1080','--log-file',('"'+$log+'"'),'-s',$Script)
if($Script -in @('res://tools/capture_water_reference.gd','res://tools/capture_water_stage25.gd')){$argsList += @('--',$Label)}
if($Headless){$argsList=@('--headless')+$argsList}
$taskProcess=Start-Process -FilePath $engine -ArgumentList $argsList -WindowStyle Hidden -PassThru
if(-not $taskProcess.WaitForExit(55000)){Stop-Process -Id $taskProcess.Id; Write-Output 'CHECK TIMEOUT';exit 1}
Write-Output ('CHECK EXIT '+$taskProcess.ExitCode)
Get-Content -LiteralPath $log -Tail 8
