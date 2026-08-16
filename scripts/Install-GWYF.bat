@echo off
setlocal
set "DIR=%~dp0"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Restarting as Administrator...
    powershell -NoProfile -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%Install-GWYF.ps1"
echo.
pause
