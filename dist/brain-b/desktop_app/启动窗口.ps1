# BrainAgent 桌面窗口启动器
$projectDir = "C:\Users\redact\Desktop\大脑项目"

# 1. 检查服务
try {
    $r = Invoke-WebRequest -Uri "http://localhost:3003/" -TimeoutSec 2 -ErrorAction Stop
    Write-Host "服务已在运行"
} catch {
    Write-Host "启动 BrainAgent 服务..."
    Start-Process -FilePath "$projectDir\一键启动.bat" -WindowStyle Minimized
    Start-Sleep -Seconds 18
}

# 2. 打开 Edge 无边框窗口
$edgePaths = @(
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
)
$edge = "msedge.exe"
foreach ($p in $edgePaths) {
    if (Test-Path $p) { $edge = $p; break }
}

Write-Host "打开窗口..."
Start-Process -FilePath $edge -ArgumentList "--app=http://localhost:3003","--window-size=1200,800" -WindowStyle Maximized
Write-Host "完成"
