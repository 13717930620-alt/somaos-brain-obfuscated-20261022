# verify_llm_upgrade.ps1  (100% ASCII SAFE)
#   - No Chinese, no emoji, no box-drawing chars (avoids PS5 parser bug)
#   - Final output: PASS / WARN / FAIL count + one-line verdict
# Run (Admin PS):
#   powershell -ExecutionPolicy Bypass -File scripts\diagnostics\verify_llm_upgrade.ps1
[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$PyExe = ""
)
$ErrorActionPreference = 'Continue'

# Resolve a Python interpreter portably (env override -> in-repo venv -> common installs).
if (-not $PyExe) {
    $cands = @(
        $env:SOMAOS_PYTHON,
        $env:PYTHON_PATH,
        (Join-Path $ProjectRoot 'training\venv_gpu\Scripts\python.exe'),
        (Join-Path $env:USERPROFILE 'python-sdk\python3.13.2\python.exe'),
        (Join-Path $env:USERPROFILE 'AppData\Local\Programs\Python\Python311\python.exe'),
        (Join-Path $env:USERPROFILE 'AppData\Local\Programs\Python\Python312\python.exe'),
        (Join-Path $env:USERPROFILE 'AppData\Local\Programs\Python\Python313\python.exe')
    )
    foreach ($c in $cands) { if ($c -and (Test-Path -LiteralPath $c)) { $PyExe = $c; break } }
    if (-not $PyExe) { $PyExe = 'python' }
}

$LLM_DIR    = Join-Path $ProjectRoot "models\llm"
$NEW_FILE   = Join-Path $LLM_DIR "qwen3-14b-instruct-q4_k_m.gguf"
$OLD_FILE   = Join-Path $LLM_DIR "qwen2.5-14b-instruct-q4_k_m.gguf"
$MON_LOG    = "$env:USERPROFILE\Desktop\qwen3_monitor.log"
$DL_LOG     = "$env:USERPROFILE\Desktop\qwen3_14b_download_progress.log"
$BACKUP_DIR = Join-Path $ProjectRoot "scripts\backups"
$TOTAL_EXP  = 9276184896

Write-Host ""
Write-Host ("=" * 100) -ForegroundColor Cyan
Write-Host "  LLM UPGRADE VERIFICATION  (Qwen2.5-14B -> Qwen3-14B, same Qwen series)" -ForegroundColor Cyan
Write-Host ("=" * 100) -ForegroundColor Cyan
Write-Host ("  PROJECT_ROOT = {0}" -f $ProjectRoot)
Write-Host ""

$PASS = 0
$WARN = 0
$FAIL = 0

function Check([string]$name, $ok, [string]$detailIfFail='', [string]$detailIfOK='') {
    if ($ok -eq $true) {
        $script:PASS += 1
        Write-Host ("  [PASS] [{0}]  {1}" -f $name, $(if($detailIfOK){$detailIfOK}else{""})) -ForegroundColor Green
        return $true
    } elseif ($ok -eq $false -or $ok -eq 0) {
        $script:FAIL += 1
        Write-Host ("  [FAIL] [{0}]  {1}" -f $name, $detailIfFail) -ForegroundColor Red
        return $false
    } else {
        $script:WARN += 1
        Write-Host ("  [WARN] [{0}]  {1}" -f $name, $detailIfFail) -ForegroundColor Yellow
        return $false
    }
}

# GROUP 1 - CRITICAL (FAIL -> upgrade definitely broken)
Write-Host "[ GROUP 1 ] Critical: file existence + integrity + server health" -ForegroundColor Cyan
Write-Host ("-" * 100)

# 1.1 new GGUF exists and size in range
if (Test-Path $NEW_FILE) {
    $sz = (Get-Item $NEW_FILE).Length
    $ok11 = $sz -ge (0.99 * $TOTAL_EXP) -and $sz -le ($TOTAL_EXP + 200MB)
    Check '1.1 new GGUF exists & size in [99pct Exp, Exp+200MB]' $ok11 `
        ("actual {0:N3} GB, expected {1:N3} GB" -f ($sz/1GB), ($TOTAL_EXP/1GB)) `
        ("size {0:N3} GB OK" -f ($sz/1GB))
} else {
    Check '1.1 new GGUF exists' $false "NOT FOUND: $NEW_FILE (download rename step may have failed)"
}

# 1.2 GGUF header valid (magic + version + tensor count)
if (Test-Path $NEW_FILE) {
    $py12 = @"
import sys, struct
try:
    with open(r"$NEW_FILE",'rb') as f:
        mg = f.read(4)
        if mg != b'GGUF':
            print('FAIL bad magic', mg.hex()); sys.exit(2)
        ver = struct.unpack('<I', f.read(4))[0]
        tens = struct.unpack('<Q', f.read(8))[0]
        kv = struct.unpack('<Q', f.read(8))[0]
        print(f'OK GGUF v{ver} tensor_count={tens} kv_count={kv}')
        sys.exit(0 if (ver>=3 and tens>=500) else 1)
except Exception as e:
    print('EXCEPTION', type(e).__name__, e); sys.exit(3)
"@
    $t12 = Join-Path $env:TEMP "vfy_gguf_head.py"
    Set-Content $t12 -Value $py12 -Encoding UTF8
    $out = & $PyExe $t12 2>&1
    $ok12 = ($LASTEXITCODE -eq 0)
    Check '1.2 GGUF header valid (magic=GGUF, v>=3, tensors>=500)' $ok12 `
        ("exit=$LASTEXITCODE  " + ($out -join ' | ')) ($out -join ' ')
} else {
    Check '1.2 GGUF header' $null 'SKIP (no file)'
}

# 1.3 .part file cleaned
$partPath = Join-Path $LLM_DIR 'qwen3-14b-instruct-q4_k_m.gguf.part'
$partExists = Test-Path $partPath
Check '1.3 .part file removed (rename OK)' (-not $partExists) `
    ".part still exists at $partPath -> manually rename to final name" `
    ".part cleaned OK"

# 1.4 /health returns 200
try {
    $h = Invoke-WebRequest -Uri 'http://127.0.0.1:18080/health' -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
    $ok14 = ($h.StatusCode -eq 200)
    $bd = if ($h.Content) { [string]$h.Content } else { '' }; $bd = $bd.Trim()
    if ($bd.Length -gt 100) { $bd = $bd.Substring(0,100) + '...' }
    Check '1.4 :18080/health HTTP 200 (llama-server online)' $ok14 `
        ("status=" + ($h.StatusCode)) ("status=200  body=$bd")
} catch {
    Check '1.4 :18080/health' $false `
        ("connect fail: " + $_.Exception.Message.Substring(0,[Math]::Min(160,$_.Exception.Message.Length)))
}

# GROUP 2 - References (FAIL -> some launch path broken)
Write-Host ""
Write-Host "[ GROUP 2 ] Code references (launch scripts / env / configs -> qwen3)" -ForegroundColor Yellow
Write-Host ("-" * 100)

# 2.1 .env / .env.example -> LOCAL_LLM_PATH points to qwen3
$envFile = Join-Path $ProjectRoot '.env'
$envEx   = Join-Path $ProjectRoot '.env.example'
$ENV_HAS_Q3 = $false
foreach ($ef in @($envFile, $envEx)) {
    $fn = [IO.Path]::GetFileName($ef)
    if (Test-Path $ef) {
        $txt = [IO.File]::ReadAllText($ef)
        $has    = [regex]::IsMatch($txt, 'LOCAL_LLM_PATH\s*=\s*.*qwen3-14b', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $old    = [regex]::IsMatch($txt, 'LOCAL_LLM_PATH\s*=\s*.*qwen2\.5-14b', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $hasAny = [regex]::IsMatch($txt, 'LOCAL_LLM_PATH', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $markOK = if ($has -and -not $old) { $true } elseif (-not $hasAny) { $null } else { $false }
        Check ("2.1 env file $fn") $markOK `
            ("still references qwen2.5! old=$old qwen3=$has") `
            ("LOCAL_LLM_PATH -> qwen3-14b OK")
        if ($markOK -eq $true -and $fn -eq '.env') { $ENV_HAS_Q3 = $true }
    } else {
        if ($fn -eq '.env.example') {
            Check ("2.1 env file $fn") $false "NOT FOUND"
        } else {
            Check ("2.1 env file $fn") $null "NOT FOUND (optional: launch.js can auto-find)"
        }
    }
}

# 2.2 scripts/launch.js
$lj = Join-Path $ProjectRoot 'scripts\launch.js'
if (Test-Path $lj) {
    $txt = [IO.File]::ReadAllText($lj)
    $hardOld = [regex]::IsMatch($txt, 'qwen2\.5-14b-instruct')
    $hardNew = [regex]::IsMatch($txt, 'qwen3-14b-instruct')
    if ($hardOld -and -not $hardNew) {
        Check '2.2 scripts/launch.js hardcoded path' $false `
            "still hardcodes qwen2.5-14b (dynamic find may still work, but not ideal)"
    } elseif ($hardNew -or (-not $hardOld -and -not $hardNew)) {
        Check '2.2 scripts/launch.js hardcoded path' $true "" `
            ("upgraded or fully dynamic find OK (hardNew=$hardNew, hardOld=$hardOld)")
    } else {
        Check '2.2 scripts/launch.js hardcoded path' $true "" `
            "both old+new present, first match wins OK"
    }
} else {
    Check '2.2 scripts/launch.js exists' $false "MISSING"
}

# 2.3 start_local_services.bat
$sls = Join-Path $ProjectRoot 'start_local_services.bat'
if (Test-Path $sls) {
    $txt = [IO.File]::ReadAllText($sls)
    $old = [regex]::IsMatch($txt, 'qwen2\.5-14b-instruct')
    $new = [regex]::IsMatch($txt, 'qwen3-14b-instruct')
    $ok23 = ($new -and -not $old)
    Check '2.3 start_local_services.bat model ref' $ok23 `
        ("qwen2.5?=$old  qwen3?=$new") ("all switched to qwen3 OK")
} else {
    Check '2.3 start_local_services.bat' $false "MISSING"
}

# 2.4 scripts/start_llm.bat MODEL_PATH
$sll = Join-Path $ProjectRoot 'scripts\start_llm.bat'
if (Test-Path $sll) {
    $txt = [IO.File]::ReadAllText($sll)
    $new = [regex]::IsMatch($txt, 'MODEL_PATH=.+qwen3-14b')
    $old = [regex]::IsMatch($txt, 'MODEL_PATH=.+qwen2\.5-14b')
    Check '2.4 scripts/start_llm.bat MODEL_PATH' ($new -and -not $old) `
        ("qwen2.5?=$old  qwen3?=$new") ("points to qwen3 OK")
} else {
    Check '2.4 scripts/start_llm.bat' $false "MISSING"
}

# 2.5 link_verify.py
$lv = Join-Path $ProjectRoot 'link_verify.pyc'
if (Test-Path $lv) {
    $txt = [IO.File]::ReadAllText($lv)
    $new = [regex]::IsMatch($txt, 'qwen3-14b-instruct')
    $old = [regex]::IsMatch($txt, 'qwen2\.5-14b-instruct')
    Check '2.5 link_verify.py LLM path' ($new -or -not $old) `
        ("still references qwen2.5? old=$old new=$new") `
        ("qwen3 OK")
} else {
    Check '2.5 link_verify.py' $null "not found"
}

# 2.6 full_check.py
$fc = Join-Path $ProjectRoot 'full_check.pyc'
if (Test-Path $fc) {
    $txt = [IO.File]::ReadAllText($fc)
    $new = [regex]::IsMatch($txt, 'qwen3-14b')
    $old = [regex]::IsMatch($txt, 'qwen2\.5-14b')
    Check '2.6 full_check.py LLM path' (-not $old -or $new) `
        ("still references qwen2.5? old=$old new=$new") ("llm label OK")
} else {
    Check '2.6 full_check.py' $null "not found"
}

# GROUP 3 - Real inference smoke test (golden standard)
Write-Host ""
Write-Host "[ GROUP 3 ] Real inference smoke tests (golden standard of success)" -ForegroundColor Green
Write-Host ("-" * 100)

# 3.1 GET /v1/models
try {
    $mdl = Invoke-RestMethod -Uri 'http://127.0.0.1:18080/v1/models' -Method GET -TimeoutSec 10
    if ($mdl -and $mdl.data -and $mdl.data.Count -gt 0) {
        $ids = ($mdl.data | ForEach-Object { $_.id }) -join ', '
        Check '3.1 GET /v1/models returns list' $true "" ("models=$ids")
    } else {
        Check '3.1 GET /v1/models' $false ("empty data: " + ($mdl | ConvertTo-Json -Depth 3))
    }
} catch {
    Check '3.1 GET /v1/models' $false `
        ("fail: " + $_.Exception.Message.Substring(0,[Math]::Min(160,$_.Exception.Message.Length)))
}

# 3.2 POST /v1/chat/completions
try {
    $payload = @{
        model='qwen'
        temperature=0.1
        max_tokens=16
        messages=@(
            @{role='system'; content='You are Qwen series model. Answer briefly.'}
            @{role='user';   content='Hi. Please reply with only the two letters OK, nothing else.'}
        )
    } | ConvertTo-Json -Depth 5
    $t0 = Get-Date
    $resp = Invoke-RestMethod -Uri 'http://127.0.0.1:18080/v1/chat/completions' `
        -Method POST -Body $payload -ContentType 'application/json' -TimeoutSec 90
    $dt = [int]((Get-Date) - $t0).TotalMilliseconds
    if ($resp.choices -and $resp.choices.Count -gt 0) {
        $ans = if ($resp.choices[0].message.content) { [string]$resp.choices[0].message.content } else { '' }; $ans = $ans.Trim()
        $ok32 = ($ans.Length -gt 0)
        $okish = ($ans -match '(OK|ok|Okay|Hi|Hello)')
        Check '3.2 POST chat/completions smoke (reply OK only)' ($ok32 -and $okish) `
            ("answer=[$ans]  (no OK keyword, wrong model?)") `
            ("TTFT=${dt}ms -> answer=[$ans] OK")
    } else {
        Check '3.2 chat/completions' $false `
            ("no choices! " + ($resp | ConvertTo-Json -Depth 4).Substring(0,[Math]::Min(300,($resp|ConvertTo-Json -Depth 4).Length)))
    }
} catch {
    Check '3.2 chat/completions' $false `
        ("fail (may still be loading, retry in 60s): " + $_.Exception.Message.Substring(0,[Math]::Min(200,$_.Exception.Message.Length)))
}

# GROUP 4 - Rollback insurance & log locations
Write-Host ""
Write-Host "[ GROUP 4 ] Rollback backups & log locations (warnings do NOT block runtime)" -ForegroundColor Magenta
Write-Host ("-" * 100)

# 4.1 backup files exist (last 2 hours >=5)
$baks = @()
if (Test-Path $BACKUP_DIR) {
    $cutoff = (Get-Date).AddHours(-2)
    $baks = @(Get-ChildItem $BACKUP_DIR -Filter 'qwen_upgrade_*.bak' | Where-Object { $_.LastWriteTime -gt $cutoff })
}
Check ('4.1 backups exist (scripts/backups/qwen_upgrade_*.bak, last 2h, >=5)') ($baks.Count -ge 5) $null `
    ("backed up {0} files OK" -f $baks.Count)
if ($baks.Count -gt 0) {
    Write-Host ("     -> Rollback: Copy-Item $BACKUP_DIR\qwen_upgrade_TIMESTAMP_*.bak back to original paths + restart llama-server") -ForegroundColor DarkGray
}

# 4.2 old GGUF kept (informational)
if (Test-Path $OLD_FILE) {
    $osz = (Get-Item $OLD_FILE).Length
    Check '4.2 old qwen2.5 GGUF kept (optional)' $null "" `
        ("kept {0:N3} GB -> delete to free space if upgrade stable" -f ($osz/1GB))
} else {
    Check '4.2 old qwen2.5 GGUF' $null "" `
        "not present (deleted earlier to free space; re-download if rollback needed)"
}

# 4.3 list all log locations
Write-Host ""
Write-Host "  Key log / artifact locations:" -ForegroundColor Magenta
$logMap = @(
    @('Monitor log (triggers upgrade)  ', $MON_LOG),
    @('Download progress (speed/retry)', $DL_LOG),
    @('Backup directory (rollback src)', $BACKUP_DIR),
    @('Upgrade script (re-runnable)   ', (Join-Path $ProjectRoot 'scripts\diagnostics\upgrade_llm_qwen25_to_qwen3.ps1')),
    @('THIS verify script (re-run any)', $PSCommandPath)
)
foreach ($entry in $logMap) {
    ($label, $pth) = $entry
    $exists = Test-Path $pth
    $mark = if ($exists) {'[FILE]'} else {'[MISS]'}
    Write-Host ("     {0}  {1} -> {2}" -f $mark, $label, $pth)
}

# FINAL VERDICT
Write-Host ""
Write-Host ("=" * 100) -ForegroundColor Cyan
Write-Host ("  STATS: PASS={0}  WARN={1}  FAIL={2}" -f $PASS, $WARN, $FAIL) -ForegroundColor Cyan

if ($FAIL -eq 0 -and $WARN -eq 0) {
    Write-Host "  VERDICT = GREEN   -> FULLY SUCCESSFUL" -ForegroundColor Green
    Write-Host "  Qwen3-14B is ready. Next start_local_services.bat will load qwen3." -ForegroundColor Green
} elseif ($FAIL -eq 0 -and $WARN -gt 0) {
    Write-Host ("  VERDICT = YELLOW  -> SUCCESS with {0} warnings (cosmetic only)" -f $WARN) -ForegroundColor Yellow
    Write-Host "  Review GROUP 2/4 [WARN] items; manually edit strings if you care." -ForegroundColor Yellow
} else {
    Write-Host ("  VERDICT = RED     -> FAILED  (FAIL={0})" -f $FAIL) -ForegroundColor Red
    Write-Host ("  Rollback: restore $BACKUP_DIR\qwen_upgrade_*.bak over originals + restart llama-server") -ForegroundColor DarkYellow
    Write-Host "  Paste full script output to developer for diagnosis." -ForegroundColor Red
}
Write-Host ("=" * 100) -ForegroundColor Cyan

return $FAIL
