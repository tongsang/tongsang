@echo off
setlocal

:: Always ask for elevation, so double-clicking this file is enough to install.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0configure-desktop-idle-shutdown.ps1\"' -Verb RunAs"

endlocal
