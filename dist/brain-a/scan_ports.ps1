$ports = @(3001,18080,18090,18091,18092,8889,8001,8002,5001,18081,8011)
Write-Output "=== 端口扫描 ==="
foreach ($p in $ports) {
  $conn = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue
  if ($conn) {
    $pid = $conn[0].OwningProcess
    $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
    $mem = if ($proc) { [math]::Round($proc.WorkingSet64/1MB) } else { 0 }
    Write-Output "  $p  LISTEN  PID=$pid  MEM=${mem}MB  $($proc.ProcessName)"
  } else {
    Write-Output "  $p  CLOSED"
  }
}
Write-Output ""
Write-Output "=== Node进程 ==="
Get-Process -Name node -ErrorAction SilentlyContinue | ForEach-Object {
  $mem = [math]::Round($_.WorkingSet64/1MB)
  Write-Output "  PID=$($_.Id) MEM=${mem}MB START=$($_.StartTime.ToString('HH:mm:ss'))"
}
Write-Output ""
Write-Output "=== Python进程 ==="
Get-Process -Name python -ErrorAction SilentlyContinue | ForEach-Object {
  $mem = [math]::Round($_.WorkingSet64/1MB)
  Write-Output "  PID=$($_.Id) MEM=${mem}MB START=$($_.StartTime.ToString('HH:mm:ss'))"
}