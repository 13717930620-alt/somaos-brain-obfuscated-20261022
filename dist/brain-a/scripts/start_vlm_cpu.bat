@echo off
cd /d ..
set VLM_DEVICE=cpu
set VLM_4BIT=0
python ../services/vlm_transformers_server.pyc