@echo off
cd /d "C:\Users\redactxxxxxxx\Desktop\大脑项目\大脑项目_副本\training"
python train_v2_continue.py > train_v2_continue_out.txt 2>&1
echo DONE >> train_v2_continue_out.txt