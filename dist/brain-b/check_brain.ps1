Write-Output "=== Node processes ==="
Get-Process -Name node -ErrorAction SilentlyContinue | ForEach-Object {
  $mem = [math]::Round($_.WorkingSet64/1MB)
  Write-Output "  PID=$($_.Id) MEM=${mem}MB START=$($_.StartTime.ToString('HH:mm:ss'))"
}
Write-Output ""
Write-Output "=== Port 3001 ==="
$c = Get-NetTCPConnection -LocalPort 3001 -State Listen -ErrorAction SilentlyContinue
if ($c) { Write-Output "  LISTENING PID=$($c[0].OwningProcess)" }
else { Write-Output "  NOT LISTENING" }
Write-Output ""
Write-Output "=== Port 8889 ==="
$c2 = Get-NetTCPConnection -LocalPort 8889 -State Listen -ErrorAction SilentlyContinue
if ($c2) { Write-Output "  LISTENING PID=$($c2[0].OwningProcess)" }
else { Write-Output "  NOT LISTENING" }