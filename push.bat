@echo off
title RK Traders - push to GitHub
cd /d "%~dp0"
git add -A
git commit -m "Update from %COMPUTERNAME% on %DATE% %TIME%"
git push
echo.
echo Done. Press any key to close.
pause >nul
