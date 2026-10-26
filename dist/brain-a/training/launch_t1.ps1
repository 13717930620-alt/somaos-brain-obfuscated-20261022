$env:PYTORCH_CUDA_ALLOC_CONF = "expandable_segments:True"
$env:PYTHONUNBUFFERED = "1"
Set-Location ".."
python training\run_t1_v7_full.pyc 2>&1 | Out-File -FilePath "training\v7_full_train.log" -Encoding UTF8