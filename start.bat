@echo off
title RK Traders
cd /d "%~dp0"
echo Starting RK Traders ...
start "" http://localhost:5000
python app.py
pause
