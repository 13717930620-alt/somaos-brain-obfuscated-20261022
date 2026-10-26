@echo off
setlocal
set PROJECT_ROOT=%~dp0..
set LLAMA_EXE=%PROJECT_ROOT%\llama\llama.exe
set MODEL_PATH=%PROJECT_ROOT%\models\llm\qwen3-14b-instruct-q4_k_m.gguf

if not exist "%LLAMA_EXE%" (
    echo [ERROR] llama.exe not found: %LLAMA_EXE%
    exit /b 1
)
if not exist "%MODEL_PATH%" (
    echo [ERROR] model not found: %MODEL_PATH%
    exit /b 1
)

echo [LLM] Starting Qwen3-14B llama-server on port 18080...
echo [LLM] Model: %MODEL_PATH%
echo [LLM] GPU layers: 35, Context: 8192
"%LLAMA_EXE%" serve -m "%MODEL_PATH%" --host 127.0.0.1 --port 18080 -ngl 35 -c 8192 -b 1024 -t 8 -ub 1024 --parallel 1 --no-mmap
