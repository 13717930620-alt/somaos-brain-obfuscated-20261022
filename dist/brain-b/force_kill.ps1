$conns = Get-NetTCPConnection -LocalPort 18090 -State Listen -ErrorAction SilentlyContinue
foreach ($c in $conns) {
  try { Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue } catch {}
}
Start-Sleep -Seconds 3
$c2 = Get-NetTCPConnection -LocalPort 18090 -State Listen -ErrorAction SilentlyContinue
if ($c2) { Write-Output "STILL UP" }
else { Write-Output "CLOSED OK" }