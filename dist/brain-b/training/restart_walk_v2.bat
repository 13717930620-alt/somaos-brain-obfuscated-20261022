@echo off
cd /d "C:\Users\redactxxxxxxx\Desktop\大脑项目\大脑项目_副本\training"
python train_deepmimic.py walk_forward 1000000 ppo_checkpoints_walk_forward/ppo_walk_forward_100000_steps.zip > walk_train_log_v2.txt 2> walk_train_err_v2.txt