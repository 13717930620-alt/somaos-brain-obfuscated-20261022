# ============================================================
#   powershell -ExecutionPolicy Bypass -File scripts\cloud_gpu\tunnel.ps1 `
#       -RemoteHost 123.45.67.89 -Port 22022 -User root
#   powershell -ExecutionPolicy Bypass -File scripts\cloud_gpu\tunnel.ps1 `
#       -RemoteHost 1.2.3.4 -Port 22 -Ports 18080,18081
#   powershell -ExecutionPolicy Bypass -File scripts\cloud_gpu\tunnel.ps1 -SshHost autodl-gpu
[CmdletBinding()]
param(
    [string]$SshHost = '',
    [string]$RemoteHost = '',
    [int]$Port = 22,
    [string]$User = 'root',
    [string]$KeyFile = '',
    [string]$Ports = '18080,18081,18082,18090,18091,18092,5001,8001,8011',
    [switch]$Quiet
)

$ErrorActionPreference = 'Continue'

if (-not $SshHost -and -not $RemoteHost) {
    Write-Host '[FAIL] 必须提供 -RemoteHost <云端IP> 或 -SshHost <ssh配置别名>' -ForegroundColor Red
    Write-Host '       例: -RemoteHost 123.45.67.89 -Port 22022 -User root'
    exit 1
}

$sshCmd = Get-Command ssh -ErrorAction SilentlyContinue
$sshExe = if ($sshCmd) { $sshCmd.Source } else { $null }
if (-not $sshExe) {
    Write-Host '[FAIL] 找不到 ssh 命令。Windows 请启用「OpenSSH 客户端」可选功能。' -ForegroundColor Red
    exit 1
}

$portNames = @{
    18080 = 'LLM'; 18081 = 'VLM'; 18082 = 'ReasoningSmall'
    18090 = 'STT'; 18091 = 'TTS'; 18092 = 'SAM2'
    5001 = 'Cosmos3'; 8001 = 'GR00T'; 8011 = 'GUSH3R'
}

$portList = @($Ports -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' })
if ($portList.Count -eq 0) {
    Write-Host '[FAIL] -Ports 里没有合法端口' -ForegroundColor Red
    exit 1
}

$target = if ($SshHost) { $SshHost } else { "$User@$RemoteHost" }

$sshArgs = @(
    '-N'
    '-T'
    '-o', 'ExitOnForwardFailure=yes'
    '-o', 'ServerAliveInterval=30'
    '-o', 'ServerAliveCountMax=3'
    '-o', 'StrictHostKeyChecking=accept-new'
)
if (-not $SshHost -and $Port -ne 22) { $sshArgs += @('-p', "$Port") }
if ($KeyFile) { $sshArgs += @('-i', $KeyFile) }

$forwarded = @()
foreach ($p in $portList) {
    $sshArgs += @('-L', "127.0.0.1:${p}:127.0.0.1:${p}")
    $label = if ($portNames.ContainsKey([int]$p)) { $portNames[[int]$p] } else { 'unknown' }
    $forwarded += "  $p  $label"
}

Write-Host ''
Write-Host '=== SomaOS 云 GPU 隧道 ===' -ForegroundColor Cyan
Write-Host "  目标 : $target$(if (-not $SshHost -and $Port -ne 22) { " (SSH 端口 $Port)" })"
Write-Host "  本地 : 127.0.0.1（仅本机可访问）"
Write-Host '  转发 :'
$forwarded | ForEach-Object { Write-Host $_ }
Write-Host ''
Write-Host '  按 Ctrl+C 断开隧道' -ForegroundColor DarkGray
Write-Host ''

$logDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir 'cloud_tunnel.log'

$proc = Start-Process -FilePath $sshExe -ArgumentList $sshArgs -PassThru -NoNewWindow `
    -RedirectStandardError $logFile

Start-Sleep -Seconds 4

if ($proc.HasExited) {
    Write-Host '[FAIL] 隧道进程已退出。SSH 日志：' -ForegroundColor Red
    if (Test-Path $logFile) { Get-Content $logFile -Tail 20 | ForEach-Object { Write-Host "  $_" } }
    Write-Host ''
    Write-Host '常见原因：' -ForegroundColor Yellow
    Write-Host '  * 云端 IP / 端口 / 用户名不对'
    Write-Host '  * 未配置免密（需 ssh-keygen + ssh-copy-id），或密钥路径不对（用 -KeyFile 指定）'
    Write-Host '  * 本地某个端口已被占用（先关掉占用的进程）'
    exit 1
}

Write-Host "[ OK ] 隧道已建立 (ssh PID $($proc.Id))，日志: $logFile" -ForegroundColor Green
Write-Host ''

Write-Host '=== 远端服务健康检查 ===' -ForegroundColor Cyan
$okCount = 0
foreach ($p in $portList) {
    $label = if ($portNames.ContainsKey([int]$p)) { $portNames[[int]$p] } else { 'unknown' }
    $code = 'ERR'
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:$p/health" -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
        $code = [string]$r.StatusCode
    } catch {
        if ($_.Exception.Response) { $code = [string][int]$_.Exception.Response.StatusCode } else { $code = 'unreachable' }
    }
    if ($code -eq '200') {
        Write-Host ("  [ OK ] {0,-16} :{1}" -f $label, $p) -ForegroundColor Green
        $okCount++
    } else {
        Write-Host ("  [warn] {0,-16} :{1}  -> {2}" -f $label, $p, $code) -ForegroundColor Yellow
    }
}
Write-Host ''
Write-Host "可用 $okCount / $($portList.Count)" -ForegroundColor Cyan

if ($okCount -eq 0) {
    Write-Host ''
    Write-Host '一个都没通。检查顺序：' -ForegroundColor Yellow
    Write-Host '  1) 云端是否已跑 cloud_start_services.sh？'
    Write-Host '  2) 云端服务是否绑在 127.0.0.1 且端口一致？（ss -ltnp | grep 18080）'
    Write-Host '  3) 隧道日志有没有报错？（' + $logFile + '）'
}

Write-Host ''
Write-Host '下一步：把 .env 的 SOMAOS_INFERENCE_MODE 改成 hybrid 或 remote，然后重启大脑。'
Write-Host "验证：powershell -ExecutionPolicy Bypass -File scripts\cloud_gpu\check_remote.ps1"
