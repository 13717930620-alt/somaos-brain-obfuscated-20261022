Get-CimInstance Win32_Process -Filter "Name='python.exe'" | ForEach-Object {
    $cpu = try { [math]::Round((Get-Process -Id $_.ProcessId -ErrorAction Stop).CPU, 1) } catch { 0 }
    Write-Output ("PID=" + $_.ProcessId + " CPU=" + $cpu + " CMD=" + $_.CommandLine)
}