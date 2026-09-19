@echo off
setlocal

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0compiler\Compile.ps1"
if errorlevel 1 (
    echo.
    echo WinUtil could not be compiled.
    pause
    exit /b 1
)

start "" "%~dp0compiled\WinUtilLauncher.exe"
