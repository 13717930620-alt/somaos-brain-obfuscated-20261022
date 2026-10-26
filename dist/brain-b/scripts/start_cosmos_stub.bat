@echo off
cd /d C:\brain_root
set COSMOS_STUB=1
python C:\brain_root\services\cosmos_server.pyc --model-path C:\brain_root\models\world_model\cosmos3-edge-policy-droid --port 5001 --device cpu