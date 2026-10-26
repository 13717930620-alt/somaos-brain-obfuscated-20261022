# ============================================================
#   powershell -ExecutionPolicy Bypass -File scripts\cloud_gpu\check_remote.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\cloud_gpu\check_remote.ps1 -RemoteHost 10.0.0.5
[CmdletBinding()]
param(
    [string]$RemoteHost = '127.0.0.1',
    [int]$TimeoutSec = 5,
    [switch]$SkipInference
)

$ErrorActionPreference = 'Continue'

$endpoints = @(
    @{ Key = 'LLM';             Port = 18080; Kind = 'llama' }
    @{ Key = 'VLM';             Port = 18081; Kind = 'llama' }
    @{ Key = 'REASONING_SMALL'; Port = 18082; Kind = 'llama' }
    @{ Key = 'STT';             Port = 18090; Kind = 'http' }
    @{ Key = 'TTS';             Port = 18091; Kind = 'http' }
    @{ Key = 'SAM2';            Port = 18092; Kind = 'http' }
    @{ Key = 'COSMOS';          Port = 5001;  Kind = 'http' }
    @{ Key = 'GR00T';           Port = 8001;  Kind = 'http' }
    @{ Key = 'GUSH3R';          Port = 8011;  Kind = 'http' }
)

function Probe([string]$h, [int]$p) {
    try {
        $r = Invoke-WebRequest -Uri "http://${h}:$p/health" -TimeoutSec $TimeoutSec -UseBasicParsing -ErrorAction Stop
        return @{ ok = $true; code = [int]$r.StatusCode; body = $r.Content }
    } catch {
        $code = 0
        if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        return @{ ok = $false; code = $code; body = $_.Exception.Message }
    }
}

Write-Host ''
Write-Host '=== 云 GPU 端点检查 ===' -ForegroundColor Cyan
Write-Host "  目标主机 : $RemoteHost"
Write-Host "  超时     : ${TimeoutSec}s"
Write-Host ''
Write-Host ('  {0,-18} {1,-7} {2,-8} {3}' -f '模型', '端口', '状态', '说明')
Write-Host ('  ' + ('-' * 66))

$okList = @()
$badList = @()
foreach ($ep in $endpoints) {
    $r = Probe $RemoteHost $ep.Port
    if ($r.ok -and $r.code -eq 200) {
        Write-Host ('  {0,-18} {1,-7} {2,-8} {3}' -f $ep.Key, $ep.Port, 'OK', '') -ForegroundColor Green
        $okList += $ep.Key
    } else {
        $why = if ($r.code -gt 0) { "HTTP $($r.code)" } else { '不可达' }
        Write-Host ('  {0,-18} {1,-7} {2,-8} {3}' -f $ep.Key, $ep.Port, 'FAIL', $why) -ForegroundColor Red
        $badList += "$($ep.Key):$($ep.Port) ($why)"
    }
}

Write-Host ''
Write-Host "  可用 $($okList.Count) / $($endpoints.Count)" -ForegroundColor Cyan

if (-not $SkipInference -and $okList -contains 'LLM') {
    Write-Host ''
    Write-Host '=== LLM 真实推理自检 ===' -ForegroundColor Cyan
    $body = @{
        model    = 'default'
        messages = @(@{ role = 'user'; content = '只回复两个字：在线' })
        max_tokens = 16
        temperature = 0
    } | ConvertTo-Json -Depth 5 -Compress
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $r = Invoke-WebRequest -Uri "http://${Host}:18080/v1/chat/completions" -Method POST `
            -ContentType 'application/json' -Body $body -TimeoutSec 60 -UseBasicParsing -ErrorAction Stop
        $sw.Stop()
        $j = $r.Content | ConvertFrom-Json
        $text = $j.choices[0].message.content
        Write-Host ("  [ OK ] 回复: {0}  ({1} ms)" -f $text, $sw.ElapsedMilliseconds) -ForegroundColor Green
    } catch {
        Write-Host "  [warn] 推理请求失败: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host '         端口通但推理失败 —— 多半是模型还在加载，等 30~60s 再试' -ForegroundColor Yellow
        $badList += 'LLM:inference'
    }
}

Write-Host ''
if ($badList.Count -eq 0) {
    Write-Host '全部就绪。可以把 .env 的 SOMAOS_INFERENCE_MODE 改成 hybrid 或 remote 了。' -ForegroundColor Green
    exit 0
} else {
    Write-Host '未就绪端点：' -ForegroundColor Yellow
    $badList | ForEach-Object { Write-Host "  - $_" }
    Write-Host ''
    Write-Host '排查顺序：' -ForegroundColor Yellow
    Write-Host '  1) 隧道还在吗？看 logs/cloud_tunnel.log'
    Write-Host '  2) 云端服务起了吗？在云端执行 bash scripts/cloud_gpu/cloud_start_services.sh --status'
    Write-Host '  3) 云端端口对吗？在云端执行 ss -ltnp | grep -E "18080|18081|18090"'
    exit 1
}
