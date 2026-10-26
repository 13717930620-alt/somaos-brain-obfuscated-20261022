@echo off
chcp 65001 >nul
cd /d "C:\Users\redactxxxxxxx\Desktop\大脑项目\大脑项目_副本\training"
set PYTHONUTF8=1
set PYTHONIOENCODING=utf-8
start "WalkTraining" /min python train_walk_refpd.py > walk_train_bg.log 2> walk_train_bg_err.log
echo %errorlevel%