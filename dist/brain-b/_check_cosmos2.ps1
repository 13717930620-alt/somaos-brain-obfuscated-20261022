$ErrorActionPreference = 'SilentlyContinue'
$root = $PSScriptRoot
Write-Output ("PROJECT_ROOT: " + $root)

Write-Output '========== [1] PROCESS CHECK (PID 15992) =========='
$p = Get-Process -Id 15992 -ErrorAction SilentlyContinue
if ($p) {
    Write-Output ("ALIVE: PID={0} Name={1} StartTime={2} CPU={3}" -f $p.Id, $p.ProcessName, $p.StartTime, $p.CPU)
} else {
    Write-Output 'DEAD: PID 15992 not running'
}
# also find any python running download_cosmos
$py = Get-Process -Name python* -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like '*cosmos*' -or $true }
Write-Output '--- ALL PYTHON PROCESSES ---'
Get-Process -Name python* -ErrorAction SilentlyContinue | Select-Object Id, ProcessName, StartTime, @{N='CPU';E={[math]::Round($_.CPU,1)}} | Format-Table -AutoSize | Out-String
# check command lines via CIM
Write-Output '--- PYTHON CMDLINES CONTAINING cosmos ---'
Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'" | Where-Object { $_.CommandLine -like '*cosmos*' } | Select-Object ProcessId, CommandLine | Format-List | Out-String

Write-Output '========== [2] MODEL DIR STATS =========='
$dir = Join-Path $root 'models\world_model\cosmos3-edge-policy-droid'
Write-Output ("TARGET_DIR: " + $dir)
if (Test-Path $dir) {
    $files = Get-ChildItem -Path $dir -Recurse -File
    $count = $files.Count
    $size = ($files | Measure-Object -Property Length -Sum).Sum
    Write-Output ("FILE_COUNT: " + $count)
    Write-Output ("TOTAL_SIZE_BYTES: " + $size)
    Write-Output ("TOTAL_SIZE_GB: " + [math]::Round($size/1GB, 4))
    Write-Output '--- TOP-LEVEL ENTRIES ---'
    Get-ChildItem -Path $dir | Select-Object Mode, Name, @{N='SizeMB';E={if($_.PSIsContainer){''}else{[math]::Round($_.Length/1MB,3)}}}, LastWriteTime | Format-Table -AutoSize | Out-String
} else {
    Write-Output 'DIR_NOT_FOUND'
}

Write-Output '========== [3] TRANSFORMER SAFETENSORS SHARDS =========='
$t = Join-Path $dir 'transformer'
if (Test-Path $t) {
    $shards = Get-ChildItem -Path $t -Filter '*.safetensors' -File
    Write-Output ("SAFETENSORS_SHARD_COUNT: " + $shards.Count + "  (TARGET: 7)")
    if ($shards.Count -gt 0) {
        $shards | Select-Object Name, @{N='SizeGB';E={[math]::Round($_.Length/1GB,3)}}, LastWriteTime | Format-Table -AutoSize | Out-String
    }
    Write-Output '--- OTHER FILES IN transformer ---'
    Get-ChildItem -Path $t -File | Where-Object { $_.Extension -ne '.safetensors' } | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize | Out-String
} else {
    Write-Output 'TRANSFORMER_DIR_NOT_FOUND'
}

Write-Output '========== [3b] VAE & VISION_ENCODER =========='
foreach ($sub in @('vae','vision_encoder')) {
    $s = Join-Path $dir $sub
    if (Test-Path $s) {
        $sf = Get-ChildItem -Path $s -Recurse -File
        $sz = ($sf | Measure-Object -Property Length -Sum).Sum
        Write-Output ("{0}: EXISTS, files={1}, sizeMB={2}" -f $sub, $sf.Count, [math]::Round($sz/1MB,3))
        $sf | Select-Object Name, @{N='SizeMB';E={[math]::Round($_.Length/1MB,3)}} | Format-Table -AutoSize | Out-String
    } else {
        Write-Output ("{0}: MISSING" -f $sub)
    }
}

Write-Output '========== [4] HF CACHE INCOMPLETE FILES =========='
$cache = Join-Path $root '.cache\huggingface\download'
if (Test-Path $cache) {
    $inc = Get-ChildItem -Path $cache -Recurse -File | Where-Object { $_.Name -like '*.incomplete' -or $_.Name -like '*.tmp' -or $_.Name -like '*.lock' }
    Write-Output ("LOCAL_CACHE_INCOMPLETE: " + $inc.Count)
    if ($inc.Count -gt 0) {
        $inc | Select-Object FullName, @{N='SizeMB';E={[math]::Round($_.Length/1MB,3)}}, LastWriteTime | Format-Table -AutoSize | Out-String
    }
} else {
    Write-Output 'LOCAL_CACHE_DIR_NOT_FOUND'
}
# user-level hf cache
$alt = Join-Path $env:USERPROFILE '.cache\huggingface'
Write-Output ("USER_HF_CACHE: " + $alt + " exists=" + (Test-Path $alt))
if (Test-Path $alt) {
    $inc2 = Get-ChildItem -Path $alt -Recurse -File | Where-Object { $_.Name -like '*.incomplete' }
    Write-Output ("USER_CACHE_INCOMPLETE: " + $inc2.Count)
    if ($inc2.Count -gt 0) {
        $inc2 | Select-Object FullName, @{N='SizeMB';E={[math]::Round($_.Length/1MB,3)}} | Format-Table -AutoSize | Out-String
    }
}
# also check models/.cache
$mc = Join-Path $root 'models\.cache'
Write-Output ("MODELS_CACHE: " + $mc + " exists=" + (Test-Path $mc))

Write-Output '========== [5] DOWNLOAD LOG TAIL =========='
$log = Join-Path $root 'logs\cosmos_download.log'
if (Test-Path $log) {
    $li = Get-Item $log
    Write-Output ("LOG_SIZE_BYTES: " + $li.Length)
    Write-Output ("LOG_LAST_WRITE: " + $li.LastWriteTime)
    Write-Output '--- LAST 10 LINES ---'
    Get-Content -Path $log -Tail 10
} else {
    Write-Output 'LOG_NOT_FOUND'
}

Write-Output ''
Write-Output '========== SUMMARY =========='
$shardCount = if (Test-Path $t) { (Get-ChildItem -Path $t -Filter '*.safetensors' -File).Count } else { 0 }
$vaeOk = Test-Path (Join-Path $dir 'vae')
$visOk = Test-Path (Join-Path $dir 'vision_encoder')
$dirOk = Test-Path $dir
Write-Output ("MODEL_DIR_EXISTS: " + $dirOk)
Write-Output ("SHARDS: " + $shardCount + "/7")
Write-Output ("VAE_PRESENT: " + $vaeOk)
Write-Output ("VISION_ENCODER_PRESENT: " + $visOk)
$complete = ($shardCount -ge 7 -and $vaeOk -and $visOk)
Write-Output ("DOWNLOAD_COMPLETE: " + $complete)