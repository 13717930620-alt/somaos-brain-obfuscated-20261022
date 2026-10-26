param([int]$Port = 18080, [string]$Name = "LLM")
$c = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($c) {
  $procId = $c[0].OwningProcess
  $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
  $mem = if ($proc) { [math]::Round($proc.WorkingSet64/1MB) } else { 0 }
  Write-Output "[$Name] Killing PID=$procId MEM=${mem}MB"
  Stop-Process -Id $procId -Force
  Start-Sleep -Seconds 3
  $c2 = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  if ($c2) { Write-Output "[$Name] STILL LISTENING - FAIL" }
  else { Write-Output "[$Name] Port $Port CLOSED - OK" }
} else {
  Write-Output "[$Name] Port $Port not found"
}