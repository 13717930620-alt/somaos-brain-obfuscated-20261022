@echo off
chcp 65001 > nul
title Brain Project Environment Setup
cd /d "%~dp0"
echo.
echo ============================================================
echo   Brain Project - Environment Auto Setup Launcher
echo ============================================================
echo.
echo This script will:
echo   1. Install Miniconda3
echo   2. Create conda env 'groot' (Python 3.12)
echo   3. Install PyTorch + diffusers + transformers + deps
echo   4. Clone and install Isaac-GR00T framework
echo   5. Configure .env file
echo   6. Configure HuggingFace mirror (China)
echo.
echo Duration: ~15-30 minutes (depends on network)
echo.
echo Press any key to start (or close window to cancel)...
pause > nul

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_env.ps1"

echo.
echo ============================================================
echo   Script finished
echo ============================================================
pause
