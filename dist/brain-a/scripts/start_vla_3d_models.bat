@echo off
chcp 65001 >nul 2>&1
REM ============================================================
REM SomaOS VLA + 3D Models Startup Script
REM Starts GR00T N1.5-3B (VLA, port 8001) and GUSH3R (3D, port 8011)

REM ============================================================

set PROJECT_ROOT=%~dp0..
cd /d "%PROJECT_ROOT%"

echo ============================================================
echo  SomaOS VLA + 3D Model Startup
echo  Project: %PROJECT_ROOT%
echo  GPU: RTX 3060 12GB
echo ============================================================
echo.

REM --- Step 1: Check GPU availability ---
echo [1/5] Checking GPU...
python -c "import torch; print('  CUDA available:', torch.cuda.is_available()); print('  Device:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU')" 2>nul
if errorlevel 1 (
    echo  WARNING: PyTorch/CUDA not available, models will run on CPU (slow)
)
echo.

REM --- Step 2: Free GPU memory (stop existing model processes) ---
echo [2/5] Freeing GPU memory...
taskkill /F /IM llama-server.exe >nul 2>&1
echo  Stopped llama-server processes (if any)
echo.

REM --- Step 3: Check GPU memory ---
echo [3/5] GPU memory status:
nvidia-smi --query-gpu=memory.total,memory.used,memory.free --format=csv,noheader 2>nul
echo.

REM --- Step 4: Start GR00T N1.5-3B VLA Server (port 8001) ---
echo [4/5] Starting GR00T N1.5-3B VLA Server (port 8001)...
start "GR00T-VLA" /MIN cmd /c "cd /d %PROJECT_ROOT% && python services\groot_server.pyc --model-path models\vla\groot --port 8001 > logs\groot_server.log 2>&1"

REM Wait for GR00T to load (model loading takes time)
echo  Waiting for GR00T model to load (may take 30-60 seconds)...
set /a WAIT_COUNT=0
:WAIT_GROOT
timeout /t 5 /nobreak >nul
set /a WAIT_COUNT+=5
python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8001/health', timeout=3); print('GR00T READY')" 2>nul
if errorlevel 1 (
    if %WAIT_COUNT% lss 120 (
        goto :WAIT_GROOT
    ) else (
        echo  WARNING: GR00T did not start within 120 seconds
    )
)
echo.

REM --- Step 5: GUSH3R 3D Reconstruction Test ---
echo [5/5] GUSH3R 3D Reconstruction test...
echo  Creating test frames...
python -c "import os, numpy as np; from PIL import Image; d=r'gush3r\test_frames'; os.makedirs(d, exist_ok=True); [Image.fromarray(np.clip(np.random.randint(0,255,(480,640,3),dtype=np.uint8).astype(np.int16)+np.array([100,90,80]),0,255).astype(np.uint8)).save(os.path.join(d,f'frame_{i:04d}.png')) for i in range(5)]; print('  Test frames created')"
echo.
echo  Running GUSH3R inference...
cd gush3r
python infer.py --seq_path test_frames --output_dir outputs/test --max_frames 5 --device cuda --size 512
cd /d "%PROJECT_ROOT%"
echo.

echo ============================================================
echo  Startup Complete!
echo ============================================================
echo.
echo  GR00T N1.5-3B VLA: http://127.0.0.1:8001/health
echo  GUSH3R output: gush3r\outputs\test\merged_render\
echo.
echo  Test commands:
echo    curl http://127.0.0.1:8001/health
echo    curl -X POST http://127.0.0.1:8001/infer -H "Content-Type: application/json" -d "{\"instruction\":\"grasp the red block\",\"robot_state\":[0,0,0,0,0,0,0,0]}"
echo.
pause
