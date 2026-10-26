@echo off
cd /d "C:\Users\redact\Desktop\大脑项目\大脑项目_副本"
"D:\DreamDojo\python311\python.exe" "scripts\download_cosmos.pyc" > "logs\cosmos_download.log" 2>&1
echo EXIT_CODE=%ERRORLEVEL% >> "logs\cosmos_download.log"
