$ErrorActionPreference = 'Continue'
$pyPath = 'D:\DreamDojo\python311\python.exe'
$scriptPath = 'C:\Users\redact\Desktop\大脑项目\大脑项目_副本\scripts\download_cosmos.pyc'
$logPath = 'C:\Users\redact\Desktop\大脑项目\大脑项目_副本\logs\cosmos_download.log'
$errPath = 'C:\Users\redact\Desktop\大脑项目\大脑项目_副本\logs\cosmos_download_err.log'
& $pyPath $scriptPath *> $logPath 2>&1
"EXIT_CODE=$LASTEXITCODE" | Out-File -Append $logPath -Encoding UTF8