#   Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File run_v17_after_v16.ps1" -WindowStyle Hidden
$ErrorActionPreference = "Continue"
$dir = 'c:/Users/redactxxxxxxx/Desktop/大脑项目/大脑项目_副本/training'
Set-Location $dir
$py = 'C:\Users\redactxxxxxxx\AppData\Local\Programs\Python\Python311\python.exe'

"[watcher] start $(Get-Date -Format 'HH:mm:ss')" | Out-File -FilePath watcher_v17.log -Encoding UTF8 -Append

$waited = 0
while ($waited -lt 43200) {
    $p = Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
         Where-Object { $_.CommandLine -like '*train_long_v16*' }
    if (-not $p) { break }
    Start-Sleep -Seconds 60
    $waited += 60
    if ($waited % 1800 -eq 0) {
        "[watcher] 已等待 $([int]($waited/60)) 分钟, v16 仍在运行" |
            Out-File -FilePath watcher_v17.log -Encoding UTF8 -Append
    }
}
"[watcher] v16 已结束 ($(Get-Date -Format 'HH:mm:ss'))，等待子进程回收..." |
    Out-File -FilePath watcher_v17.log -Encoding UTF8 -Append
Start-Sleep -Seconds 20

Copy-Item 'hier_v16_v16_best.zip'    'hier_v16final_best.zip'    -Force -ErrorAction SilentlyContinue
Copy-Item 'hier_v16_v16_vecnorm.pkl' 'hier_v16final_vecnorm.pkl' -Force -ErrorAction SilentlyContinue
"[watcher] 已复制起始权重 -> hier_v16final_best.zip" |
    Out-File -FilePath watcher_v17.log -Encoding UTF8 -Append

"[watcher] 启动 train_until_ok $(Get-Date -Format 'HH:mm:ss')" |
    Out-File -FilePath watcher_v17.log -Encoding UTF8 -Append
& $py -u train_until_ok.py --rounds 6 --hours 3 --start-tag v16final --n-envs 8 `
    > v17_out.log 2> v17_err.log

"[watcher] train_until_ok 结束 ($(Get-Date -Format 'HH:mm:ss'))" |
    Out-File -FilePath watcher_v17.log -Encoding UTF8 -Append
