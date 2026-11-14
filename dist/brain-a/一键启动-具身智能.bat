@echo off
chcp 65001 >nul 2>&1
title SomaOS Embodied AI - Full GPU Launch
cd /d "%~dp0"

rem ============================================================
rem  SomaOS One-Click Launcher - Embodied Intelligence v3.5
rem  Simple & reliable: start "title" cmd /c "cmd > log & pause"
rem ============================================================

set "ROOT=%~dp0"
set "PYTHON=python"
set "PORT_LLM=18080"
set "PORT_VLM=18081"
set "PORT_BRAIN=3001"
set "PORT_SIM=8889"
set "PORT_SNN=8002"
set "PORT_STT=18090"
set "PORT_VIEW=8900"
set "PORT_GUSH3R=8011"
set "PORT_GROOT=8001"

if not exist logs md logs

echo ================================ > "_launch_debug.log"
echo SomaOS Launch Debug Log >> "_launch_debug.log"
echo Date: %date% %time% >> "_launch_debug.log"
echo ================================ >> "_launch_debug.log"

where python >nul 2>&1
if %errorlevel% neq 0 (
  if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" (
    set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
  ) else (
    echo [ERROR] Python not found, install from https://www.python.org
    echo [ERROR] Python not found >> "_launch_debug.log"
    goto :error_exit
  )
)
where node >nul 2>&1
if %errorlevel% neq 0 (
  echo [ERROR] Node.js not found, install from https://nodejs.org
  echo [ERROR] Node.js not found >> "_launch_debug.log"
  goto :error_exit
)

echo.
echo ============================================================
echo   SomaOS Embodied AI - Full GPU Launch v3.5
echo ============================================================
echo.

goto :main

:wait_port
  set "wp_port=%~1"
  set "wp_max=%~2"
  set /a wp_el=0
  :wp_loop
    set "wp_found="
    for /f "tokens=*" %%L in ('netstat -ano 2^>nul ^| findstr :%wp_port% ^| findstr LISTENING') do set "wp_found=1"
    if defined wp_found goto :wp_done
    timeout /t 1 /nobreak >nul
    set /a wp_el+=1
    if %wp_el% geq %wp_max% goto :wp_done
  goto :wp_loop
  :wp_done
  if defined wp_found (
    echo     [OK] port %wp_port% listening
    echo     [OK] Port %wp_port% ready >> "_launch_debug.log"
  ) else (
    echo     [TIMEOUT] port %wp_port% not ready after %wp_max%s
    echo     [WARN] Port %wp_port% timeout >> "_launch_debug.log"
  )
  goto :eof

:kill_port
  set "kp_port=%~1"
  for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr :%kp_port% ^| findstr LISTENING') do (
    taskkill /PID %%a /F >nul 2>&1
    echo     killed old PID %%a (port %kp_port%)
  )
  goto :eof

:main
rem ---------- 0) Cleanup: free GPU/RAM from stale processes FIRST ----------
rem  (critical: loading 14B LLM while old VLM/python still hold 12GB VRAM
rem   crashes the Brain process silently -> port 3001 never comes up)
echo [0/7] Cleaning stale processes, freeing GPU memory
echo [0/7] Cleanup stale processes... >> "_launch_debug.log"
taskkill /F /IM llama-server.exe >nul 2>&1
taskkill /F /IM node.exe >nul 2>&1
wmic process where "name='python.exe'" call terminate >nul 2>&1
call :kill_port %PORT_BRAIN%
call :kill_port %PORT_LLM%
call :kill_port %PORT_VLM%
call :kill_port %PORT_SIM%
call :kill_port %PORT_SNN%
call :kill_port %PORT_STT%
call :kill_port %PORT_VIEW%
call :kill_port %PORT_GUSH3R%
timeout /t 5 /nobreak >nul
echo     cleanup done, GPU memory released
echo.

rem ---------- 0b) Pre-start EMBER-SNN (Brain Layer B dependency) ----------
rem  SNN must be up BEFORE Brain, otherwise SomaSNNMemory gets ECONNREFUSED
rem  and neuro_injector Layer B degrades for the whole session
echo [0b] Pre-starting EMBER-SNN (Brain Layer B dependency), port %PORT_SNN%
echo [0b] Pre-starting SNN... >> "_launch_debug.log"
if exist "services\embersnn\ember_snn_service.pyc" (
  start "SomaOS-SNN" cmd /c "%PYTHON% services\embersnn\ember_snn_service.pyc >logs\snn.log 2>&1 & echo. & echo === SNN EXITED === & pause"
  call :wait_port %PORT_SNN% 30
) else (
  echo     [skip] services\embersnn\ember_snn_service.pyc not found
  echo     [SKIP] No ember_snn_service.py >> "_launch_debug.log"
)
echo.

rem ---------- 1) Brain + LLM ----------
echo [1/7] Brain + 19 regions + LLM engine, port %PORT_BRAIN% / %PORT_LLM%
echo [1/7] Starting Brain+LLM... >> "_launch_debug.log"
if not exist "node_modules" (
  echo     node_modules missing, installing deps...
  call npm --prefix "%ROOT%" install --no-audit --no-fund
)
start "SomaOS-Brain" cmd /c "node _launch.js >logs\brain.log 2>&1 & echo. & echo === BRAIN EXITED === & echo See logs\brain.log & pause"
echo     Brain starting, waiting for LLM (up to 120s)...
call :wait_port %PORT_LLM% 120
call :wait_port %PORT_BRAIN% 30
echo.

rem ---------- 2) VLM ----------
echo [2/7] VLM vision-language model, port %PORT_VLM%
echo [2/7] Starting VLM... >> "_launch_debug.log"
subst B: /d >nul 2>&1
subst B: "%ROOT%" >nul 2>&1
set "VLM_MODEL="
if exist "models\vlm\qwen3-vl-8b-instruct-q4_k_m.gguf" set "VLM_MODEL=models\vlm\qwen3-vl-8b-instruct-q4_k_m.gguf"
if exist "models\vlm\qwen3-vl-8b-instruct-q5_k_m.gguf" if not defined VLM_MODEL set "VLM_MODEL=models\vlm\qwen3-vl-8b-instruct-q5_k_m.gguf"
if defined VLM_MODEL (
  echo     model: %VLM_MODEL%
  if exist "models\vlm\mmproj-F16.gguf" (
    start "SomaOS-VLM" /MIN cmd /c "llama\llama.exe serve -m B:/%VLM_MODEL% --mmproj B:/models/vlm/mmproj-F16.gguf --port %PORT_VLM% --host 127.0.0.1 -ngl 12 -c 4096 -t 4 -b 1024 >logs\vlm.log 2>&1 & echo. & echo === VLM EXITED === & pause"
  ) else (
    start "SomaOS-VLM" /MIN cmd /c "llama\llama.exe serve -m B:/%VLM_MODEL% --port %PORT_VLM% --host 127.0.0.1 -ngl 12 -c 4096 -t 4 -b 1024 >logs\vlm.log 2>&1 & echo. & echo === VLM EXITED === & pause"
  )
  call :wait_port %PORT_VLM% 90
) else (
  echo     [skip] VLM model not found
  echo     [SKIP] No VLM model >> "_launch_debug.log"
)
echo.

rem ---------- 3) MuJoCo ----------
echo [3/7] MuJoCo GPU simulation, port %PORT_SIM%
echo [3/7] Starting MuJoCo... >> "_launch_debug.log"
if exist "simulation\mujoco_server.pyc" (
  start "SomaOS-MuJoCo" cmd /c "%PYTHON% simulation\mujoco_server.pyc >logs\mujoco.log 2>&1 & echo. & echo === MUJOCO EXITED === & pause"
  call :wait_port %PORT_SIM% 30
) else (
  echo     [skip] simulation\mujoco_server.pyc not found
  echo     [SKIP] No mujoco_server.py >> "_launch_debug.log"
)
echo.

rem ---------- 4) EMBER-SNN (pre-started in step 0b) ----------
echo [4/7] EMBER-SNN spiking network (pre-started in step 0b), port %PORT_SNN%
echo [4/7] Verify SNN... >> "_launch_debug.log"
call :wait_port %PORT_SNN% 10
echo     EMBER-SNN listening on %PORT_SNN%
echo.

rem ---------- 5) STT ----------
echo [5/7] STT speech recognition, port %PORT_STT%
echo [5/7] Starting STT... >> "_launch_debug.log"
if exist "models\speech\ggml-large-v3.bin" (
  if exist "services\stt_server.pyc" (
    start "SomaOS-STT" cmd /c "%PYTHON% services\stt_server.pyc >logs\stt.log 2>&1 & echo. & echo === STT EXITED === & pause"
    call :wait_port %PORT_STT% 60
    echo     STT started
  ) else (
    echo     [skip] services\stt_server.pyc not found
    echo     [SKIP] No stt_server.py >> "_launch_debug.log"
  )
) else (
  echo     [skip] STT model not found
  echo     [SKIP] No STT model >> "_launch_debug.log"
)
echo.

rem ---------- 6) GPU Display ----------
echo [6/7] Browser real-time GPU display, port %PORT_VIEW%
echo [6/7] Starting GPU View... >> "_launch_debug.log"
if exist "simulation\full_gpu_visual_web.pyc" (
  start "SomaOS-GPUView" cmd /c "%PYTHON% simulation\full_gpu_visual_web.pyc >logs\gpuview.log 2>&1 & echo. & echo === GPUVIEW EXITED === & pause"
  call :wait_port %PORT_VIEW% 30
  echo     live view: http://127.0.0.1:%PORT_VIEW%/
  start "" "http://127.0.0.1:%PORT_VIEW%/"
  start "" "http://127.0.0.1:%PORT_BRAIN%/"
) else (
  echo     [skip] simulation\full_gpu_visual_web.pyc not found
  echo     [SKIP] No full_gpu_visual_web.py >> "_launch_debug.log"
)
echo.

rem ---------- 7) GUSH3R 3D reconstruction ----------
echo [7/7] GUSH3R 3D scene reconstruction (managed by Brain WorldCentricLoop)
echo [7/7] GUSH3R managed by Brain internally >> "_launch_debug.log"
echo.

rem ---------- 7b) GR00T N1.5-3B VLA ----------
echo [7b] Starting GR00T N1.5-3B VLA server, port %PORT_GROOT%
echo [7b] Starting GR00T VLA... >> "_launch_debug.log"
if exist "services\groot_server.pyc" (
  if exist "models\vla\groot\model-00001-of-00003.safetensors" (
    start "SomaOS-GROOT" cmd /c "%PYTHON% services\groot_server.pyc --model-path models\vla\groot --port %PORT_GROOT% >logs\groot_server.log 2>&1"
    call :wait_port %PORT_GROOT% 20
    echo     GR00T VLA ready on %PORT_GROOT%
  ) else (
    echo     [skip] GR00T weights not found in models\vla\groot
    echo     [SKIP] No GR00T weights >> "_launch_debug.log"
  )
) else (
  echo     [skip] services\groot_server.pyc not found
  echo     [SKIP] No groot_server.py >> "_launch_debug.log"
)
echo.

echo ============================================================
echo   All modules launched - each independent
echo   Brain panel : http://localhost:%PORT_BRAIN%
echo   LLM engine  : http://127.0.0.1:%PORT_LLM%
echo   VLM engine  : http://127.0.0.1:%PORT_VLM%
echo   MuJoCo sim  : http://127.0.0.1:%PORT_SIM%
echo   EMBER-SNN   : http://127.0.0.1:%PORT_SNN%
echo   STT voice   : http://127.0.0.1:%PORT_STT%
echo   GPU display : http://127.0.0.1:%PORT_VIEW%
echo   GUSH3R 3D   : http://127.0.0.1:%PORT_GUSH3R%/health
echo   GR00T VLA   : http://127.0.0.1:%PORT_GROOT%/health
echo   Close a module: end its titled cmd window
echo ============================================================
echo.

echo === LAUNCH COMPLETE at %time% === >> "_launch_debug.log"

echo.
echo ============================================================
echo   Health Verification
echo ============================================================
set "hr_ok=0"
set "hr_total=0"
for %%P in ("%PORT_BRAIN%:Brain" "%PORT_LLM%:LLM" "%PORT_VLM%:VLM" "%PORT_SNN%:SNN" "%PORT_SIM%:MuJoCo" "%PORT_STT%:STT" "%PORT_VIEW%:GPUView" "%PORT_GROOT%:GR00T") do (
  for /f "tokens=1,2 delims=:" %%a in (%%P) do (
    set /a hr_total+=1
    set "hr_found="
    for /f "tokens=*" %%L in ('netstat -ano 2^>nul ^| findstr :%%a ^| findstr LISTENING') do set "hr_found=1"
    if defined hr_found (
      echo   [OK]   %%b  (port %%a)
      set /a hr_ok+=1
    ) else (
      echo   [FAIL] %%b  (port %%a)
    )
  )
)
echo.
echo   Result: %hr_ok%/%hr_total% services online
echo ============================================================
echo.

echo   Brain panel : http://localhost:%PORT_BRAIN%
echo   GPU display : http://127.0.0.1:%PORT_VIEW%/
echo   Close a module: end its titled cmd window
echo ============================================================
echo.

echo Press any key to close this window (services keep running)...
pause >nul
exit /b 0

:error_exit
echo.
echo ============================================================
echo   [FATAL ERROR] Launch failed!
echo   Check _launch_debug.log for details
echo ============================================================
echo.
echo Press any key to exit...
pause >nul
exit /b 1
