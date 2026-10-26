@echo off
cd /d "%~dp0"
echo 启动 EMBER SNN 服务...
python services/embersnn/ember_snn_service.pyc --port 8002 --n-sensory 2000 --n-concept 1500 --n-category 1000 --n-meta 500 --autonomous-threshold 0.3
pause
