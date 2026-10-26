@echo off
rem ============================================================
rem  编码说明（重要）: 本文件为 GBK / CP936 编码，且刻意 **不使用 chcp 65001**。
rem    原因: 实测在 chcp 65001 下，cmd.exe 读取含较多中文的 UTF-8 批处理会出现
rem    「分块读取偏移错位」，把行尾残片当命令执行（本文件曾因此报
rem    '动重启请改用:' is not recognized 之类错误，而同样的中文放在 UTF-8 参考
rem    脚本里却正常 —— 属 cmd.exe 的已知缺陷，与内容字节位置相关，不可靠）。
rem    GBK 是简体中文 Windows 的原生代码页，cmd 可直接正确解析，无需 chcp。
rem    **编辑本文件时请保持 GBK 编码**，否则会再次触发上述缺陷。
rem ============================================================
title SomaOS Embodied Robot Stack - RobotBrain + robot_driver + robot_rt_loop
cd /d "%~dp0"

rem ============================================================
rem  启动-具身机器人.bat
rem  Windows 版 robot/robot_start.sh —— 具身机器人电机栈
rem
rem  [!] 状态（2026-10-07 新增）:
rem    本脚本按 robot/robot_start.sh 的启动顺序编写，结构已对齐，
rem    但 **尚未实机验证**（当前无机器人硬件）。首次运行请逐个窗口核对日志。
rem
rem  启动顺序:
rem    [1/6] LLM    : llama\llama.exe serve   端口 18080 (Qwen3-14B Q4_K_M)
rem    [2/6] Brain  : node scripts\start_robot.js  ->  new RobotBrain()  端口 3001
rem    [3/6] 等待 Brain /health 就绪
rem    [4/6] 相机   : robot\camera_capture.py  30fps 640x480 -> GR00T /frame
rem    [5/6] 驱动   : robot\robot_driver.py    --brain-url --groot-url
rem    [6/6] 实时环 : robot\robot_rt_loop.py   1kHz
rem
rem  说明:
rem    - robot_start.sh 用 node scripts/daemon.js 做进程守护；本脚本直接跑
rem      scripts\start_robot.js，避免守护层在调试期掩盖真实崩溃。
rem      需要自动重启请改用:  node scripts\daemon.js scripts\start_robot.js
rem    - robot_start.sh 找的是 llama-server(.exe)，但本机 llama\ 下只有 llama.exe，
rem      故此处改用 `llama.exe serve`（与 一键启动-具身智能.bat 一致）。
rem
rem  可选环境变量: ROBOT_TYPE(默认 franka_droid) / RT_FREQ(默认 1000)
rem               GROOT_HOST(127.0.0.1) / GROOT_PORT(8001)
rem               BRAIN_PORT(3001) / LLM_PORT(18080) / SKIP_LLM(true 跳过 LLM)
rem ============================================================

set "ROOT=%~dp0"
if not defined ROBOT_TYPE set "ROBOT_TYPE=franka_droid"
if not defined RT_FREQ    set "RT_FREQ=1000"
if not defined GROOT_HOST set "GROOT_HOST=127.0.0.1"
if not defined GROOT_PORT set "GROOT_PORT=8001"
if not defined BRAIN_PORT set "BRAIN_PORT=3001"
if not defined LLM_PORT   set "LLM_PORT=18080"
set "LLM_MODEL=models\llm\qwen3-14b-instruct-q4_k_m.gguf"

if not exist logs md logs

rem ---------- 环境检查 ----------
where node >nul 2>&1
if %errorlevel% neq 0 (
  echo [ERROR] Node.js not found, install from https://nodejs.org
  goto :error_exit
)

set "PYTHON="
if exist "training\venv_gpu\Scripts\python.exe" set "PYTHON=%ROOT%training\venv_gpu\Scripts\python.exe"
if defined PYTHON goto :python_ok
where python >nul 2>&1
if %errorlevel% equ 0 set "PYTHON=python"
if defined PYTHON goto :python_ok
if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
if defined PYTHON goto :python_ok
echo [ERROR] Python not found. Expected training\venv_gpu\Scripts\python.exe
echo         或 PATH 上的 python，或 %%LOCALAPPDATA%%\Programs\Python\Python311\python.exe
goto :error_exit

:python_ok
rem ---------- 前置文件检查 ----------
if not exist "scripts\start_robot.js" (
  echo [ERROR] scripts\start_robot.js not found
  goto :error_exit
)
if not exist "robot\robot_driver.py" (
  echo [ERROR] robot\robot_driver.py not found
  goto :error_exit
)

echo.
echo ============================================================
echo   SomaOS Embodied Robot Stack
echo ============================================================
echo   ROOT       : %ROOT%
echo   PYTHON     : %PYTHON%
echo   ROBOT_TYPE : %ROBOT_TYPE%
echo   RT_FREQ    : %RT_FREQ% Hz
echo   Brain      : http://127.0.0.1:%BRAIN_PORT%
echo   GR00T      : http://%GROOT_HOST%:%GROOT_PORT%
echo   LLM        : http://127.0.0.1:%LLM_PORT%
echo ============================================================
echo.

rem ---------- [1/6] LLM (llama.cpp server) ----------
if /i "%SKIP_LLM%"=="true" (
  echo [1/6] [skip] SKIP_LLM=true
  goto :after_llm
)
if not exist "llama\llama.exe" (
  echo [1/6] [skip] llama\llama.exe not found
  goto :after_llm
)
if not exist "%LLM_MODEL%" (
  echo [1/6] [skip] LLM weights not found: %LLM_MODEL%
  goto :after_llm
)
echo [1/6] LLM llama.cpp server, port %LLM_PORT%
rem 中文路径修复: llama.cpp 读不了含中文的路径 -> 映射英文盘符 B:
subst B: /d >nul 2>&1
subst B: "%ROOT%" >nul 2>&1
start "SomaOS-RobotLLM" /MIN cmd /c "llama\llama.exe serve -m B:/%LLM_MODEL% --port %LLM_PORT% --host 127.0.0.1 -ngl 32 -c 8192 >logs\robot_llm.log 2>&1 & echo. & echo === LLM EXITED === & pause"
call :wait_port %LLM_PORT% 120
:after_llm
echo.

rem ---------- [2/6] Brain (RobotBrain via scripts/start_robot.js) ----------
echo [2/6] RobotBrain + Web panel, port %BRAIN_PORT%
start "SomaOS-RobotBrain" cmd /c "node scripts\start_robot.js >logs\robot_brain.log 2>&1 & echo. & echo === ROBOTBRAIN EXITED === & echo See logs\robot_brain.log & pause"
echo.

rem ---------- [3/6] 等待 Brain 就绪 ----------
echo [3/6] Waiting for Brain /health on %BRAIN_PORT% ...
call :wait_port %BRAIN_PORT% 60
echo.

rem ---------- [4/6] 相机采集 ----------
echo [4/6] Camera capture -^> GR00T /frame
if not exist "robot\camera_capture.py" (
  echo     [skip] robot\camera_capture.py not found
) else (
  start "SomaOS-RobotCam" cmd /c "%PYTHON% robot\camera_capture.py --fps 30 --resolution 640x480 --output http://%GROOT_HOST%:%GROOT_PORT%/frame >logs\robot_cam.log 2>&1 & echo. & echo === CAMERA EXITED === & pause"
  echo     camera started ^(logs\robot_cam.log^)
)
echo.

rem ---------- [5/6] 机器人驱动 ----------
echo [5/6] Robot driver (%ROBOT_TYPE%)
start "SomaOS-RobotDriver" cmd /c "%PYTHON% robot\robot_driver.py --robot-type %ROBOT_TYPE% --brain-url http://127.0.0.1:%BRAIN_PORT% --groot-url http://%GROOT_HOST%:%GROOT_PORT% >logs\robot_driver.log 2>&1 & echo. & echo === DRIVER EXITED === & pause"
echo     driver started ^(logs\robot_driver.log^)
echo.

rem ---------- [6/6] 1kHz 实时控制循环 ----------
echo [6/6] Real-time control loop @ %RT_FREQ% Hz
start "SomaOS-RobotRT" cmd /c "%PYTHON% robot\robot_rt_loop.py --brain-url http://127.0.0.1:%BRAIN_PORT% --frequency %RT_FREQ% >logs\robot_rt.log 2>&1 & echo. & echo === RT LOOP EXITED === & pause"
echo     realtime loop started ^(logs\robot_rt.log^)
echo.

rem ---------- 自检 ----------
echo ============================================================
echo   Health Verification
echo ============================================================
set "hr_ok=0"
set "hr_total=0"
for %%P in ("%BRAIN_PORT%:RobotBrain" "%LLM_PORT%:LLM" "%GROOT_PORT%:GR00T") do (
  for /f "tokens=1,2 delims=:" %%a in (%%P) do (
    set /a hr_total+=1
    set "hr_found="
    for /f "tokens=*" %%L in ('netstat -ano 2^>nul ^| findstr :%%a ^| findstr LISTENING') do set "hr_found=1"
    if defined hr_found (
      echo   [OK]   %%b  ^(port %%a^)
      set /a hr_ok+=1
    ) else (
      echo   [FAIL] %%b  ^(port %%a^)
    )
  )
)
echo.
echo   Result: %hr_ok%/%hr_total% ports online
echo   Logs   : logs\robot_brain.log / robot_llm.log / robot_cam.log / robot_driver.log / robot_rt.log
echo ============================================================
echo.
echo   Brain panel : http://localhost:%BRAIN_PORT%
echo   Close a module: end its titled cmd window
echo.
echo Press any key to close this window (services keep running)...
pause >nul
exit /b 0

rem ============================================================
:wait_port
  set "wp_port=%~1"
  set "wp_max=%~2"
  set /a wp_el=0
  :wp_loop
    set "wp_found="
    for /f "tokens=*" %%L in ('netstat -ano 2^>nul ^| findstr :%wp_port% ^| findstr LISTENING') do set "wp_found=1"
    if defined wp_found goto :wp_done
    rem 用绝对路径调用 Windows 的 timeout.exe，避免被 PATH 上其它同名程序（如 Git-Bash 的
    rem coreutils timeout）抢先解析，后者不支持 /t 参数。
    "%SystemRoot%\System32\timeout.exe" /t 1 /nobreak >nul 2>&1
    set /a wp_el+=1
    if %wp_el% geq %wp_max% goto :wp_done
  goto :wp_loop
  :wp_done
  if defined wp_found (
    echo     [OK] port %wp_port% listening
  ) else (
    echo     [TIMEOUT] port %wp_port% not ready after %wp_max%s
  )
  goto :eof

:error_exit
echo.
echo ============================================================
echo   [FATAL ERROR] Launch aborted
echo ============================================================
echo.
pause >nul
exit /b 1
