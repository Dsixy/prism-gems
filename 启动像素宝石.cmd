@echo off
setlocal
if exist "%~dp0build\PRISM.exe" (
    start "" "%~dp0build\PRISM.exe"
    exit /b 0
)
set "PRISM_GODOT=C:\Users\Doney\Desktop\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe"
if exist "%PRISM_GODOT%" (
    start "" "%PRISM_GODOT%" --path "%~dp0."
    exit /b 0
)
echo Please open project.godot with Godot 4.6 or later.
pause
