﻿
$src = "C:\Users\redactxxxxxxx\Desktop\大脑项目\大脑项目_副本\models"
$dst = "C:\Users\redactxxxxxxx\Desktop\大脑项目2\models"

Write-Host "=============================================================================="
Write-Host "  模型权重链接完整性全面检查"
Write-Host "=============================================================================="

Write-Host ""
Write-Host "[1] 文件清单对比 (>1MB)"
$srcFiles = Get-ChildItem $src -Recurse -File | Where-Object { $_.Length -gt 1MB }
$srcRels = @{}
foreach ($f in $srcFiles) { $srcRels[$f.FullName.Substring($src.Length+1)] = $f.Length }
$dstFiles = Get-ChildItem $dst -Recurse -File | Where-Object { $_.Length -gt 1MB }
$dstRels = @{}
foreach ($f in $dstFiles) { $dstRels[$f.FullName.Substring($dst.Length+1)] = $f.Length }

$missing = 0; $mismatch = 0; $okCount = 0
foreach ($rel in ($srcRels.Keys | Sort-Object)) {
    $srcSize = [double]$srcRels[$rel]
    if ($dstRels.ContainsKey($rel)) {
        if ($srcRels[$rel] -eq $dstRels[$rel]) { $okCount++ }
        else { Write-Host "  [大小不匹配] $rel"; $mismatch++ }
    } else {
        $sizeMB = [math]::Round($srcSize / 1048576, 1)
        Write-Host "  [缺失] $rel ($sizeMB MB)"
        $missing++
    }
}
Write-Host "  匹配:$okCount 不匹配:$mismatch 缺失:$missing"

Write-Host ""
Write-Host "[2] 文件可读性验证 (magic bytes)"
$keyFiles = @(
    @("llm\qwen3-14b-instruct-q4_k_m.gguf", "LLM Qwen3-14B"),
    @("vlm\qwen3-vl-8b-instruct-q4_k_m.gguf", "VLM Qwen3-VL-8B"),
    @("vlm\mmproj-F16.gguf", "VLM mmproj"),
    @("vla\groot\model-00001-of-00003.safetensors", "VLA GR00T-1"),
    @("vla\groot\model-00002-of-00003.safetensors", "VLA GR00T-2"),
    @("vla\groot\model-00003-of-00003.safetensors", "VLA GR00T-3"),
    @("world_model\cosmos3-edge-policy-droid\transformer\diffusion_pytorch_model-00001-of-00002.safetensors", "WorldModel-T1"),
    @("world_model\cosmos3-edge-policy-droid\transformer\diffusion_pytorch_model-00002-of-00002.safetensors", "WorldModel-T2"),
    @("world_model\cosmos3-edge-policy-droid\vae\diffusion_pytorch_model.safetensors", "WorldModel-VAE"),
    @("world_model\cosmos3-edge-policy-droid\vision_encoder\model.safetensors", "WorldModel-Vision"),
    @("segmentation\sam2_hiera_large.pt", "SAM2"),
    @("segmentation\model.safetensors", "SAM2-safetensors"),
    @("embedding\model.onnx_data", "Embedding ONNX"),
    @("sensevoice\model.pt", "SenseVoice STT"),
    @("cosyvoice2-0.5b\llm.pt", "CosyVoice LLM"),
    @("cosyvoice2-0.5b\flow.pt", "CosyVoice Flow"),
    @("depth_anything_v2_vits.onnx", "DepthAnything"),
    @("yolov8n.onnx", "YOLOv8n"),
    @("yolo\yolo26n.onnx", "YOLO26n"),
    @("yolo\yolo26n.pt", "YOLO26n-pt")
)
$readOk = 0; $readFail = 0
foreach ($kf in $keyFiles) {
    $path = Join-Path $dst $kf[0]
    if (Test-Path $path) {
        try {
            $fs = [System.IO.File]::OpenRead($path)
            $buf = New-Object byte[] 4
            $fs.Read($buf, 0, 4) | Out-Null
            $fs.Close()
            $ascii = [System.Text.Encoding]::ASCII.GetString($buf)
            $sizeGB = [math]::Round((Get-Item $path).Length / 1073741824, 2)
            Write-Host "  [OK] $($kf[1])  magic:$ascii  $sizeGB GB"
            $readOk++
        } catch {
            Write-Host "  [读取失败] $($kf[1])"
            $readFail++
        }
    } else {
        Write-Host "  [不存在] $($kf[1])"
        $readFail++
    }
}

Write-Host ""
Write-Host "[3] 目录结构完整性"
$expectedDirs = @("llm","vlm","vla\groot","world_model\cosmos3-edge-policy-droid",
    "world_model\cosmos3-edge-policy-droid\transformer",
    "world_model\cosmos3-edge-policy-droid\vae",
    "world_model\cosmos3-edge-policy-droid\vision_encoder",
    "segmentation","embedding","sensevoice","stt\iic\SenseVoiceSmall",
    "cosyvoice2-0.5b","yolo","pointflow")
$dirOk = 0; $dirFail = 0
foreach ($d in $expectedDirs) {
    if (Test-Path (Join-Path $dst $d)) { $dirOk++ }
    else { Write-Host "  [缺失目录] $d"; $dirFail++ }
}
Write-Host "  目录:$dirOk/$($dirOk+$dirFail)"

Write-Host ""
Write-Host "[4] 配置文件检查"
$configFiles = @(
    "vla\groot\config.json","vla\groot\model.safetensors.index.json",
    "world_model\cosmos3-edge-policy-droid\config.json",
    "world_model\cosmos3-edge-policy-droid\model.safetensors.index.json",
    "segmentation\config.json","vlm\lora_adapter\adapter_config.json"
)
$cfgOk = 0; $cfgFail = 0
foreach ($c in $configFiles) {
    if (Test-Path (Join-Path $dst $c)) { $cfgOk++ }
    else { Write-Host "  [缺失] $c"; $cfgFail++ }
}
Write-Host "  配置:$cfgOk/$($cfgOk+$cfgFail)"

Write-Host ""
Write-Host "[5] VLA分片与index.json一致性"
$vlaIndex = Get-Content (Join-Path $dst "vla\groot\model.safetensors.index.json") -Raw | ConvertFrom-Json
$vlaTotal = $vlaIndex.metadata.total_size
$vlaShards = Get-ChildItem (Join-Path $dst "vla\groot") -Filter "model-*.safetensors"
$vlaActualTotal = 0
foreach ($s in $vlaShards) { $vlaActualTotal += $s.Length }
Write-Host "  index.json total_size: $vlaTotal"
Write-Host "  实际分片总大小: $vlaActualTotal"
Write-Host "  分片数: $($vlaShards.Count)"
if ($vlaTotal -eq $vlaActualTotal) { Write-Host "  [一致] VLA分片大小匹配" }
else { Write-Host "  [不一致] 差异: $($vlaTotal - $vlaActualTotal)" }

Write-Host ""
Write-Host "[6] WorldModel分片检查"
$wmDir = Join-Path $dst "world_model\cosmos3-edge-policy-droid"
$wmTransformer = Get-ChildItem (Join-Path $wmDir "transformer") -Filter "*.safetensors"
$wmVae = Get-ChildItem (Join-Path $wmDir "vae") -Filter "*.safetensors"
$wmVision = Get-ChildItem (Join-Path $wmDir "vision_encoder") -Filter "*.safetensors"
$wmTotal = 0
foreach ($s in $wmTransformer + $wmVae + $wmVision) { $wmTotal += $s.Length }
Write-Host "  Transformer分片: $($wmTransformer.Count)个"
Write-Host "  VAE分片: $($wmVae.Count)个"
Write-Host "  Vision分片: $($wmVision.Count)个"
Write-Host "  总大小: $([math]::Round($wmTotal/1073741824, 2)) GB"

Write-Host ""
Write-Host "=============================================================================="
$allPass = ($missing -eq 0 -and $mismatch -eq 0 -and $readFail -eq 0 -and $dirFail -eq 0 -and $cfgFail -eq 0)
Write-Host "  文件匹配:$okCount 不匹配:$mismatch 缺失:$missing"
Write-Host "  可读性:$readOk OK $readFail 失败"
Write-Host "  目录:$dirOk/$($dirOk+$dirFail)  配置:$cfgOk/$($cfgOk+$cfgFail)"
Write-Host "  硬链接:30个"
if ($allPass) { Write-Host "  *** 全部通过 - 模型权重完整融入大脑项目2 ***" }
else { Write-Host "  !!! 存在问题 !!!" }
Write-Host "=============================================================================="
