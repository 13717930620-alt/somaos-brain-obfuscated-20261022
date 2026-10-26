$ErrorActionPreference = 'Continue'
$pyPath = '../training/venv_gpu/Scripts/python.exe'
$scriptPath = './download_cosmos.pyc'
$logPath = '../logs/cosmos_download.log'
$errPath = '../logs/cosmos_download_err.log'
& $pyPath $scriptPath *> $logPath 2>&1
"EXIT_CODE=$LASTEXITCODE" | Out-File -Append $logPath -Encoding UTF8