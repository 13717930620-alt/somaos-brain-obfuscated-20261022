@echo off
cd /d ".."
set PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
set PYTHONUNBUFFERED=1
python training\run_t1_v7_full.pyc > training\v7_full_train.log 2>&1