@echo off
cd /d ".."
"../training/venv_gpu/Scripts/python.exe" "scripts\download_cosmos.pyc" > "logs\cosmos_download.log" 2>&1
echo EXIT_CODE=%ERRORLEVEL% >> "logs\cosmos_download.log"
