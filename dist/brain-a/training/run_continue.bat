@echo off
cd /d "./"
python train_v2_continue.py > train_v2_continue_out.txt 2>&1
echo DONE >> train_v2_continue_out.txt