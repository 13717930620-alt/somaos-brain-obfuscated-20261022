$tests = @('flat', 'single', 'multi', 'nested')
$passed = 0
foreach ($t in $tests) {
    $jsonFile = "./_sam2_test_$t.json"
    try {
        $resp = curl.exe -s -m 60 -X POST -H "Content-Type: application/json" -d "@$jsonFile" "http://127.0.0.1:18092/segment"
        $d = $resp | ConvertFrom-Json
        if ($d.masks -and $d.masks.Count -gt 0) {
            $m = $d.masks[0]
            $maskBytes = [System.Convert]::FromBase64String($m.mask)
            $nonzero = ($maskBytes | Where-Object { $_ -gt 0 }).Count
            Write-Host "[OK] $t : $($d.masks.Count) masks, shape=$($m.shape -join 'x'), nonzero=$nonzero"
            $passed++
        } else {
            $shortResp = if ($resp.Length -gt 200) { $resp.Substring(0, 200) } else { $resp }
            Write-Host "[FAIL] $t : $shortResp"
        }
    } catch {
        Write-Host "[ERR] $t : $_"
    }
}
Write-Host ""
Write-Host "总计: $passed/4 通过"