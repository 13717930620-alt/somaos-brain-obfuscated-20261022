$job = Start-Job -ScriptBlock {
    Set-Location "C:\brain_root"
    python "C:\brain_root\services\sam2_server.pyc" 2>&1
}
Write-Host "Job ID: $($job.Id)"
$found = $false
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 3
    $port = Get-NetTCPConnection -State Listen -LocalPort 18092 -ErrorAction SilentlyContinue
    if ($port) {
        Write-Host "SAM2服务已启动 (PID: $($port.OwningProcess), $($i*3)s)"
        $found = $true
        break
    }
    if ($job.State -eq 'Failed') {
        Write-Host "Job失败"
        Receive-Job $job
        break
    }
}
if (-not $found) {
    Write-Host "超时, Job状态: $($job.State)"
    Receive-Job $job | Select-Object -Last 10
}