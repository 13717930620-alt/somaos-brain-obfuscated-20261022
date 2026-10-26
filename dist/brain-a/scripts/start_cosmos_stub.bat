@echo off
cd /d ..
set COSMOS_STUB=1
python ../services/cosmos_server.pyc --model-path C:/Users/redact/Desktop/大脑项目最新无权重版/大脑项目_副本/models/world_model/cosmos3-edge-policy-droid --port 5001 --device cpu