@echo off
setlocal
where godot >nul 2>nul
if not errorlevel 1 goto run_godot
where godot4 >nul 2>nul
if not errorlevel 1 goto run_godot4
echo Khong tim thay lenh godot hoac godot4 trong PATH.
echo Hay mo project.godot bang Godot 4.7 tro len, sau do nhan F5.
pause
goto end
:run_godot
godot --path "%~dp0"
goto end
:run_godot4
godot4 --path "%~dp0"
:end
