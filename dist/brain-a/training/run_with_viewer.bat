@echo off
cd /d "./"
"./venv_gpu/Scripts/python.exe" train_walk_display.py
echo.
echo 训练结束，按任意键关闭...
pause >nul