@echo off
cd /d "./"
python true_multitask_train.py > multitask_train_log.txt 2> multitask_train_err.txt
echo DONE >> multitask_train_log.txt