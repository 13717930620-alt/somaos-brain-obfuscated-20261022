# launch_auto_next_stage.ps1
$ErrorActionPreference = 'Continue'

$root       = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $PSScriptRoot 'auto_next_stage.pyc'
$log        = Join-Path $PSScriptRoot 'auto_next_stage.log'
$err        = Join-Path $PSScriptRoot 'auto_next_stage_err.log'
$pidFile    = Join-Path $PSScriptRoot 'auto_next_stage_pid.txt'

if (-not (Test-Path -LiteralPath $scriptPath)) {
    Write-Host "[FAIL] auto_next_stage.py not found: $scriptPath"
    exit 1
}

$python = 'python'
foreach ($c in @(
    (Join-Path $root 'training\venv_gpu\Scripts\python.exe'),
    (Join-Path $root 'training\venv_gpu\Scripts\python')
)) {
    if (Test-Path -LiteralPath $c) { $python = $c; break }
}

$proc = Start-Process -FilePath $python -ArgumentList '-u', $scriptPath `
    -RedirectStandardOutput $log -RedirectStandardError $err `
    -WorkingDirectory $root `
    -WindowStyle Hidden -PassThru

$proc.Id | Out-File -FilePath $pidFile -Encoding ASCII
Write-Host "auto_next_stage.pyc 已启动, PID=$($proc.Id)"
Write-Host "日志: $log"
Write-Host "错误: $err"
Write-Host "停止: Stop-Process -Id $($proc.Id)"
