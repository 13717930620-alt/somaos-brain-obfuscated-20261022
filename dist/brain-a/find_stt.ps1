$c = Get-NetTCPConnection -LocalPort 18090 -State Listen -ErrorAction SilentlyContinue
if ($c) {
  $procId = $c[0].OwningProcess
  $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
  Write-Output "Port 18090 PID=$procId Name=$($proc.ProcessName) Path=$($proc.Path)"
  $parent = (Get-CimInstance Win32_Process -Filter "ProcessId=$procId").ParentProcessId
  Write-Output "Parent PID=$parent"
  $parentProc = Get-Process -Id $parent -ErrorAction SilentlyContinue
  if ($parentProc) { Write-Output "Parent Name=$($parentProc.ProcessName)" }
}
Write-Output "--- All python processes ---"
Get-Process -Name python -ErrorAction SilentlyContinue | ForEach-Object {
  $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine
  if ($cmd -match "18090|whisper|stt") {
    Write-Output "  PID=$($_.Id) CMD=$cmd"
  }
}