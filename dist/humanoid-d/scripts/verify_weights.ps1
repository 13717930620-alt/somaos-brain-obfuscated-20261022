﻿
$dst = "C:\Users\redactxxxxxxx\Desktop\大脑项目2\models"
$bigFiles = Get-ChildItem $dst -Recurse -File | Where-Object { $_.Length -gt 10MB }
$totalGB = 0
$count = 0
foreach ($f in $bigFiles) {
    $rel = $f.FullName.Substring($dst.Length + 1)
    $sizeMB = [math]::Round($f.Length / 1MB, 1)
    $totalGB += $f.Length
    $count++
    Write-Host ("  {0,10:N1} MB  {1}" -f $sizeMB, $rel)
}
Write-Host ("`n  文件数: {0}" -f $count)
Write-Host ("  总计: {0:N1} GB" -f ($totalGB / 1GB))