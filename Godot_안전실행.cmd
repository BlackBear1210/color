@echo off
setlocal
REM Launch the project through the OpenGL safety wrapper; never invoke the graphical EXE directly.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Godot_Safe_Editor.ps1"
set EXIT_CODE=%ERRORLEVEL%
if not "%EXIT_CODE%"=="0" pause
exit /b %EXIT_CODE%
