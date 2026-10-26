@echo off
REM
cd /d "%~dp0"

set "PY=training\venv_gpu\Scripts\python.exe"
if not exist "%PY%" set "PY=python"

echo 启动 EMBER SNN 服务 (%PY%) ...
"%PY%" services/embersnn/ember_snn_service.pyc --port 8002 --n-sensory 2000 --n-concept 1500 --n-category 1000 --n-meta 500
pause
