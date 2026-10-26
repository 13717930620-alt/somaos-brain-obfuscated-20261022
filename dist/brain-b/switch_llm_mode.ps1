# SomaOS BrainAgent LLM Mode Switcher
# Usage: .\switch_llm_mode.ps1 -mode auto|local|api|status
param(
    [ValidateSet("local","api","auto","status")]
    [string]$mode = "status"
)

$envFile = ".env"
if (-not (Test-Path $envFile)) { Write-Host "ERROR: .env not found" -ForegroundColor Red; exit 1 }

# Hardware detection
function Get-HW {
    $hw = @{ gpu = ""; vramGB = 0; ramGB = 0; cores = 0 }
    try {
        $n = & nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>$null
        if ($n) { $p = $n -split ','; $hw.gpu = $p[0].Trim(); $hw.vramGB = [math]::Round([int]($p[1] -replace '[^\d]','')/1024,1) }
    } catch {}
    try { $os = Get-CimInstance Win32_OperatingSystem; $hw.ramGB = [math]::Round($os.TotalVisibleMemorySize*1KB/1GB,1) } catch {}
    try { $hw.cores = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors } catch {}
    return $hw
}

function Get-Rec($hw) {
    if ($hw.vramGB -ge 16) { return @{m="local"; r="GPU $($hw.gpu) VRAM $($hw.vramGB)GB >= 16GB"} }
    elseif ($hw.ramGB -ge 32) { return @{m="local"; r="RAM $($hw.ramGB)GB >= 32GB (CPU inference)"} }
    else { return @{m="api"; r="HW insufficient (VRAM $($hw.vramGB)GB / RAM $($hw.ramGB)GB)"} }
}

function Set-Env($key, $val) {
    $c = Get-Content $envFile -Raw -Encoding UTF8
    $c = $c -replace "(?m)^(\s*$key\s*=\s*)(.*)$", "`${1}${val}"
    Set-Content $envFile -Value $c -Encoding UTF8 -NoNewline
}
function Get-Env($key) {
    $c = Get-Content $envFile -Raw -Encoding UTF8
    if ($c -match "(?m)^\s*$key\s*=\s*(.*)$") { return $matches[1].Trim() }
    return $null
}

Write-Host ""
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "  SomaOS BrainAgent LLM Mode Switcher" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""

$cm = Get-Env "LLM_MODE"
$ca = Get-Env "LLM_AUTOSTART"
Write-Host "Current: LLM_MODE=$cm  LLM_AUTOSTART=$ca" -ForegroundColor Yellow
Write-Host ""

$hw = Get-HW
Write-Host "Hardware:" -ForegroundColor Yellow
Write-Host "  GPU   : $(if($hw.gpu){$hw.gpu}else{'None'})"
Write-Host "  VRAM  : $($hw.vramGB) GB"
Write-Host "  RAM   : $($hw.ramGB) GB"
Write-Host "  Cores : $($hw.cores)"
Write-Host ""

if ($mode -eq "status") {
    $rec = Get-Rec $hw
    Write-Host "Recommended: $($rec.m)" -ForegroundColor Cyan
    Write-Host "Reason     : $($rec.r)"
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Gray
    Write-Host "  .\switch_llm_mode.ps1 -mode auto    # Auto detect"
    Write-Host "  .\switch_llm_mode.ps1 -mode local   # Force local Qwen3-14B"
    Write-Host "  .\switch_llm_mode.ps1 -mode api     # Force external API"
    Write-Host ""
    exit 0
}

if ($mode -eq "auto") {
    $rec = Get-Rec $hw
    $mode = $rec.m
    Write-Host "Auto selected: $mode" -ForegroundColor Cyan
    Write-Host "Reason       : $($rec.r)"
    Write-Host ""
}

if ($mode -eq "local") {
    Set-Env "LLM_MODE" "local"
    Set-Env "LLM_AUTOSTART" "true"
    Write-Host "[OK] Switched to LOCAL Qwen3-14B" -ForegroundColor Green
    Write-Host "     LLM_MODE=local"
    Write-Host "     LLM_AUTOSTART=true"
    Write-Host ""
    Write-Host "Next:" -ForegroundColor Yellow
    Write-Host "  1. Restart: node scripts/start_web_fast.js"
    Write-Host "  2. Auto loads Qwen3-14B (~30-60s)"
    Write-Host "  3. Works offline"
} elseif ($mode -eq "api") {
    Set-Env "LLM_MODE" "api"
    Set-Env "LLM_AUTOSTART" "false"
    Write-Host "[OK] Switched to EXTERNAL API" -ForegroundColor Green
    Write-Host "     LLM_MODE=api"
    Write-Host "     LLM_AUTOSTART=false"
    Write-Host ""
    Write-Host "Next:" -ForegroundColor Yellow
    Write-Host "  1. Restart: node scripts/start_web_fast.js"
    Write-Host "  2. Requires network for DeepSeek API"
    Write-Host "  3. Good for low-spec PC"
}
Write-Host ""
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host ""
