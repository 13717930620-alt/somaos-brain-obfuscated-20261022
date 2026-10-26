# upgrade_llm_qwen25_to_qwen3.ps1  (100% ASCII SAFE)
#   - No Chinese, no box-drawing chars (avoids PS5 ANSI decode bug)
#   - CJK string replacements delegated to upgrade_llm_references.py
# Run (Admin PS):
#   powershell -ExecutionPolicy Bypass -File scripts\diagnostics\upgrade_llm_qwen25_to_qwen3.ps1
[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$PyExe = "C:\Users\redact\python-sdk\python3.13.2\python.exe"
)
$ErrorActionPreference = 'Stop'

Write-Host "============================================================================================" -ForegroundColor Cyan
Write-Host "  LLM UPGRADE  Qwen2.5-14B  --->  Qwen3-14B   (same Qwen series)" -ForegroundColor Cyan
Write-Host "============================================================================================" -ForegroundColor Cyan
Write-Host ("  PROJECT_ROOT = {0}" -f $ProjectRoot)
Write-Host ""

$LLM_DIR   = Join-Path $ProjectRoot "models\llm"
$NEW_FILE  = Join-Path $LLM_DIR "qwen3-14b-instruct-q4_k_m.gguf"
$PART_FILE = Join-Path $LLM_DIR "qwen3-14b-instruct-q4_k_m.gguf.part"
$BACKUP_DIR= Join-Path $ProjectRoot "scripts\backups"
$LLAMA_EXE = Join-Path $ProjectRoot "llama\llama-server.exe"
$REF_PY    = Join-Path $ProjectRoot "scripts\diagnostics\upgrade_llm_references.pyc"
$TOTAL_EXP = 9276184896

# Step 0 - Preconditions
if (-not (Test-Path $LLM_DIR)) { throw "models/llm missing: $LLM_DIR" }
New-Item -ItemType Directory -Force -Path $BACKUP_DIR | Out-Null

if ((Test-Path $PART_FILE) -and -not (Test-Path $NEW_FILE)) {
    $sz = (Get-Item $PART_FILE).Length
    Write-Host ("[WAIT] Download still in progress {0:N3}GB / {1:N3}GB ({2:P1})" -f ($sz/1GB), ($TOTAL_EXP/1GB), ($sz/$TOTAL_EXP)) -ForegroundColor Yellow
    exit 1
}
if (-not (Test-Path $NEW_FILE)) { throw "Qwen3 GGUF NOT FOUND at: $NEW_FILE" }

# [1/5] Validate size + GGUF header
Write-Host "[1/5] Validate Qwen3 GGUF integrity (size + header)..." -ForegroundColor Cyan
$sz = (Get-Item $NEW_FILE).Length
Write-Host ("   size {0:N3} GB, expected {1:N3} GB" -f ($sz/1GB), ($TOTAL_EXP/1GB))
if ([Math]::Abs($sz - $TOTAL_EXP) -gt 200MB) {
    Write-Host ("   WARN size delta {0:N1} MB (different layer config possible)" -f (($sz - $TOTAL_EXP)/1MB)) -ForegroundColor Yellow
}

# 1a) Fast header check directly in PS (no external deps)
try {
    $fs = [IO.File]::OpenRead($NEW_FILE)
    $buf = New-Object byte[] 24
    $rd = $fs.Read($buf, 0, 24)
    $fs.Close()
    if ($rd -ge 24) {
        $magic = [Text.Encoding]::ASCII.GetString($buf, 0, 4)
        $ver   = [BitConverter]::ToUInt32($buf, 4)
        $tens  = [BitConverter]::ToUInt64($buf, 8)
        $kv    = [BitConverter]::ToUInt64($buf, 16)
        if ($magic -ne 'GGUF') { throw ("BAD MAGIC = $magic (not a GGUF)") }
        Write-Host ("   OK GGUF magic={0} v{1} tensors={2} kv_count={3}" -f $magic, $ver, $tens, $kv) -ForegroundColor Green
        if ($ver -lt 3 -or $tens -lt 500) {
            Write-Host ("   WARN low version/tensors (expected v3 + ~579 tensors). May still load fine." ) -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host ("   FAIL header check: {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 2
}

# 1b) Run inspect_gguf.py if present for verbose fields (NON-FATAL: skip on error)
$inspector = Join-Path $ProjectRoot 'scripts\diagnostics\inspect_gguf.pyc'
if (Test-Path $inspector) {
    Write-Host ("   Running {0} for deep header info..." -f (Split-Path $inspector -Leaf))
    try {
        $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        & $PyExe $inspector $NEW_FILE 2>&1 | Select-Object -First 12 | ForEach-Object { Write-Host ("     {0}" -f $_) }
        $ErrorActionPreference = $prev
    } catch {
        Write-Host ("     (inspector skipped: {0})" -f $_.Exception.Message.Substring(0,[Math]::Min(80,$_.Exception.Message.Length))) -ForegroundColor DarkGray
    }
}
Write-Host "   [OK] Step 1 passed" -ForegroundColor Green
Write-Host ""

# [2/5] Backup files
Write-Host "[2/5] Backing up 15 core files to scripts/backups/ ..." -ForegroundColor Cyan
$TARGETS = @(
    '.env.example',
    'scripts\launch.js',
    'scripts\start_llm.bat',
    'start_local_services.bat',
    'switch_llm_mode.ps1',
    'link_verify.pyc',
    'full_check.pyc',
    'brain\BrainBoot.js',
    'brain\BrainAssembly.js',
    'language_cortex\LLMClient.js',
    'fix_runtime.js',
    'llm_launcher.js',
    'start_llm_keep.js',
    'test_llm_real.js',
    'robot\robot_start.sh'
)
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$n = 0
foreach ($rel in $TARGETS) {
    $abs = Join-Path $ProjectRoot $rel
    if (Test-Path $abs) {
        $bak = Join-Path $BACKUP_DIR ("qwen_upgrade_{0}_{1}.bak" -f $ts, ($rel -replace '[\\/]','_'))
        Copy-Item $abs $bak -Force
        $n++
    }
}
Write-Host ("   [OK] Backups: {0} files with tag {1}" -f $n, $ts) -ForegroundColor Green
Write-Host ""

# [3/5] Replace references via Python (safe for CJK strings)
Write-Host "[3/5] Replacing qwen2.5 -> qwen3 references via Python..." -ForegroundColor Cyan
if (-not (Test-Path $REF_PY)) {
    throw "Missing Python helper: $REF_PY"
}
& $PyExe $REF_PY $ProjectRoot 2>&1 | ForEach-Object { Write-Host ("   {0}" -f $_) }
$rc = $LASTEXITCODE
if ($rc -ne 0) { throw "Python reference upgrader FAILED exit=$rc" }
Write-Host "   [OK] Step 3 replacements done" -ForegroundColor Green
Write-Host ""

# [4/5] Kill :18080 + subst B: + start llama-server (minimized)
Write-Host "[4/5] Restarting llama-server on :18080..." -ForegroundColor Cyan
$listeners = @(netstat -ano | Select-String ':18080\s+.*LISTENING')
foreach ($line in $listeners) {
    if ($line -match '(\d+)\s*$') {
        $pid = $matches[1]
        Write-Host ("   kill :18080 PID {0}" -f $pid)
        Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
    }
}
Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process -Name 'llama' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

# ---- Find actual llama runtime: new layout is llama.exe serve; legacy is llama-server.exe ----
$LLAMADIR    = Split-Path $LLAMA_EXE -Parent
$LLAMASRV_LEGACY = Join-Path $LLAMADIR 'llama-server.exe'
$LLAMACLI_NEW    = Join-Path $LLAMADIR 'llama.exe'
$RUNTIME = $null
$CMDARGS = @()
if (Test-Path $LLAMASRV_LEGACY) {
    $RUNTIME = $LLAMASRV_LEGACY
    $CMDARGS = @()   # standalone
} elseif (Test-Path $LLAMACLI_NEW) {
    $RUNTIME = $LLAMACLI_NEW
    $CMDARGS = @('serve')   # new layout: llama.exe serve
}
if (-not $RUNTIME) {
    Write-Host ("   WARN neither llama-server.exe nor llama.exe found in {0}, SKIP server startup." -f $LLAMADIR) -ForegroundColor Yellow
} else {
    $ENG_PATH = $NEW_FILE
    try {
        $null = subst B: /d 2>&1
        subst B: $ProjectRoot 2>&1 | Out-Null
        $ENG_PATH = "B:\models\llm\qwen3-14b-instruct-q4_k_m.gguf"
        Write-Host ("   subst B: -> {0} OK" -f $ProjectRoot)
    } catch {
        Write-Host ("   WARN subst B: failed, use real path. {0}" -f $_.Exception.Message.Substring(0,[Math]::Min(60,$_.Exception.Message.Length))) -ForegroundColor Yellow
    }
    $a = $CMDARGS + @(
        '-m', $ENG_PATH,
        '--port','18080','--host','127.0.0.1',
        '-ngl','99','-c','16384','-t','6','-b','2048','--mlock'
    )
    Write-Host ("   {0} {1}" -f [IO.Path]::GetFileName($RUNTIME), ($a -join ' '))
    $proc = Start-Process -FilePath $RUNTIME -ArgumentList $a `
        -WindowStyle Minimized -PassThru -WorkingDirectory (Split-Path $RUNTIME)
    Write-Host ("   [LAUNCHED] PID {0}  -- GPU loading qwen3-14b (30-90 sec)" -f $proc.Id)
}
Write-Host ""

# [5/5] /health up to 180s + smoke chat request
Write-Host "[5/5] Wait :18080/health (max 180 sec)..." -ForegroundColor Cyan
$endT = (Get-Date).AddSeconds(180)
$READY = $false
while ((Get-Date) -lt $endT) {
    try {
        $h = Invoke-WebRequest -Uri 'http://127.0.0.1:18080/health' -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($h.StatusCode -eq 200) {
            $READY = $true
            $bd = if ($h.Content) { [string]$h.Content } else { '' }; $bd = $bd.Trim()
            if ($bd.Length -gt 180) { $bd = $bd.Substring(0,180) + '...' }
            Write-Host ("   [OK] /health HTTP 200: {0}" -f $bd) -ForegroundColor Green
            # smoke POST
            try {
                $pl = @{
                    model='qwen'; temperature=0.1; max_tokens=16
                    messages=@(@{role='user'; content='Hello. Please reply with just two letters: OK.'})
                } | ConvertTo-Json -Depth 4
                $r = Invoke-RestMethod -Uri 'http://127.0.0.1:18080/v1/chat/completions' `
                    -Method POST -Body $pl -ContentType 'application/json' -TimeoutSec 120
                if ($r.choices -and $r.choices.Count -gt 0) {
                    $ans = if ($r.choices[0].message.content) { [string]$r.choices[0].message.content } else { '' }; $ans = $ans.Trim()
                    Write-Host ("   [OK] /v1/chat/completions smoke answer = [{0}]" -f $ans) -ForegroundColor Green
                }
            } catch {
                Write-Host ("   WARN smoke request fail: {0}" -f $_.Exception.Message.Substring(0,[Math]::Min(120,$_.Exception.Message.Length))) -ForegroundColor Yellow
            }
            break
        }
    } catch {
        # expected during load
    }
    $elapsed = [int](180 - ($endT - (Get-Date)).TotalSeconds)
    Write-Host ("     waiting... {0,3}s (GPU loading)" -f $elapsed)
    Start-Sleep -Seconds 4
}
if (-not $READY) {
    Write-Host "   WARN /health not OK in 180s. Visit http://127.0.0.1:18080/health later." -ForegroundColor Yellow
}

# FINAL
Write-Host ""
Write-Host "============================================================================================" -ForegroundColor Cyan
Write-Host "  UPGRADE FINISHED  Qwen2.5-14B  --->  Qwen3-14B" -ForegroundColor Green
Write-Host "============================================================================================" -ForegroundColor Cyan
Write-Host ("   New model   : {0}" -f $NEW_FILE)
Write-Host ("   Size        : {0:N3} GB" -f ($sz/1GB))
Write-Host ("   Backups dir : {0}" -f $BACKUP_DIR)
Write-Host ("   Backup tag  : qwen_upgrade_{0}_*.bak" -f $ts)
Write-Host ("   Service     : http://127.0.0.1:18080  /health = {0}" -f $(if($READY){'OK'}else{'PENDING'}))
Write-Host ("   API         : POST http://127.0.0.1:18080/v1/chat/completions")
Write-Host ""
Write-Host "   NEXT  Verify: powershell -ExecutionPolicy Bypass -File scripts\diagnostics\verify_llm_upgrade.ps1" -ForegroundColor Yellow
Write-Host ("   ROLLBACK    : copy {0}\qwen_upgrade_{1}_*.bak -> overwrite originals, restart llama-server" -f $BACKUP_DIR,$ts)
Write-Host "============================================================================================" -ForegroundColor Cyan
exit 0
