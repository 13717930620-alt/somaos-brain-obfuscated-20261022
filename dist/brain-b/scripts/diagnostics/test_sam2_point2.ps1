$tests = @('flat', 'single', 'multi', 'nested')
$passed = 0
foreach ($t in $tests) {
    $jsonFile = "C:\brain_root\scripts\diagnostics\_sam2_test_$t.json"
    $respFile = "C:\brain_root\scripts\diagnostics\_sam2_resp_$t.txt"
    curl.exe -s -m 60 -H "Content-Type: application/json" -d "@$jsonFile" "http://127.0.0.1:18092/segment" > $respFile 2>&1
    $size = (Get-ChildItem $respFile).Length
    $content = Get-Content $respFile -Raw
    if ($content -match '"masks"') {
        $maskCount = ([regex]::Matches($content, '"mask":')).Count
        $hasShape = if ($content -match '"shape"') { "yes" } else { "no" }
        Write-Host "[OK] $t : size=$size, masks=$maskCount, hasShape=$hasShape"
        $passed++
    } else {
        $short = if ($content.Length -gt 100) { $content.Substring(0, 100) } else { $content }
        Write-Host "[FAIL] $t : size=$size, content=$short"
    }
}
Write-Host ""
Write-Host "总计: $passed/4 通过"