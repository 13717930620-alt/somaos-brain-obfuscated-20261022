$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"
Set-Location "C:\Users\redactxxxxxxx\Desktop\大脑项目\大脑项目_副本\training"
python train_deepmimic_full.py 2>&1 | Tee-Object -FilePath "deepmimic_live.log"