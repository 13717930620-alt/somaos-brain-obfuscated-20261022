@echo off
cd /d "./"
"./venv_gpu/Scripts/python.exe" train_walk_display.py > walk_train_bg.log 2> walk_train_bg_err.log