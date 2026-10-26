﻿
$src = "C:\Users\redactxxxxxxx\Desktop\大脑项目\大脑项目_副本\models"
$dst = "C:\Users\redactxxxxxxx\Desktop\大脑项目2\models"

Write-Host "=== 源项目大权重文件 (>10MB) ==="
$bigFiles = Get-ChildItem $src -Recurse -File | Where-Object { $_.Length -gt 10MB }
$totalGB = 0
foreach ($f in $bigFiles) {
    $rel = $f.FullName.Substring($src.Length + 1)
    $sizeMB = [math]::Round($f.Length / 1MB, 1)
    $totalGB += $f.Length
    Write-Host ("  {0,10:N1} MB  {1}" -f $sizeMB, $rel)
}
Write-Host ("  总计: {0:N1} GB" -f ($totalGB / 1GB))

Write-Host "`n=== 创建硬链接 ==="
$created = 0
$skipped = 0
$failed = 0
foreach ($f in $bigFiles) {
    $rel = $f.FullName.Substring($src.Length + 1)
    $target = Join-Path $dst $rel
    $targetDir = Split-Path $target -Parent

    if (Test-Path $target) {
        $existing = Get-Item $target
        if ($existing.Length -eq $f.Length) {
            Write-Host "  [跳过] $rel (已存在且大小匹配)"
            $skipped++
            continue
        }
        Remove-Item $target -Force
    }

    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    try {
        New-Item -ItemType HardLink -Path $target -Target $f.FullName -Force | Out-Null
        Write-Host "  [硬链接] $rel"
        $created++
    } catch {
        Write-Host "  [失败] $rel : $($_.Exception.Message)"
        $failed++
    }
}

Write-Host "`n=== 完成 ==="
Write-Host "  创建硬链接: $created"
Write-Host "  跳过(已存在): $skipped"
Write-Host "  失败: $failed"