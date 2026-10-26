$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"
Set-Location "./"
python train_deepmimic_full.py 2>&1 | Tee-Object -FilePath "deepmimic_live.log"