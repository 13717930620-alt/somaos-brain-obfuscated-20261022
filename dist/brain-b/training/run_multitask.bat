@echo off
cd /d "C:\Users\redactxxxxxxx\Desktop\大脑项目\大脑项目_副本\training"
python true_multitask_train.py > multitask_train_log.txt 2> multitask_train_err.txt
echo DONE >> multitask_train_log.txt