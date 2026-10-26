<#
  大脑项目2 轻量版 —— 模型权重一键下载 / 恢复脚本
  =====================================================================
  用途：把轻量版里被剥离的 34 个模型权重（38.9 GB）重新拉回来，放到正确路径。

  用法：
    powershell -ExecutionPolicy Bypass -File .\download_weights.ps1
    powershell -ExecutionPolicy Bypass -File .\download_weights.ps1 -List
    powershell -ExecutionPolicy Bypass -File .\download_weights.ps1 -Group llm,vlm
    powershell -ExecutionPolicy Bypass -File .\download_weights.ps1 -Group local `
        -OriginalProject "C:\Users\redact\Desktop\大脑项目2"

  分组：llm vlm vla world tts stt vision local
  依赖：pip install -U "huggingface_hub[cli]" modelscope
#>
[CmdletBinding()]
param(
  [string[]]$Group = @('llm','vlm','vla','world','tts','stt','vision','local'),
  [string]$OriginalProject = '',
  [switch]$List,
  [switch]$Force
)

$ErrorActionPreference = 'Continue'
$Root = $PSScriptRoot
Set-Location -LiteralPath $Root

function Info($m) { Write-Host "[.] $m" -ForegroundColor Cyan }
function Ok  ($m) { Write-Host "[v] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Err ($m) { Write-Host "[x] $m" -ForegroundColor Red }

$HfCli = $null
foreach ($c in @('hf','huggingface-cli')) {
  if (Get-Command $c -ErrorAction SilentlyContinue) { $HfCli = $c; break }
}
$MsCli = $null
if (Get-Command 'modelscope' -ErrorAction SilentlyContinue) { $MsCli = 'modelscope' }

$Tasks = @(
  @{ g='llm';   kind='hf'; repo='Qwen/Qwen3-14B-GGUF'; dir='models/llm'
     files=@('Qwen3-14B-Q4_K_M.gguf')
     rename=@{ 'Qwen3-14B-Q4_K_M.gguf' = 'qwen3-14b-instruct-q4_k_m.gguf' }
     need='models/llm/qwen3-14b-instruct-q4_k_m.gguf' }
  @{ g='vlm';   kind='hf'; repo='Qwen/Qwen3-VL-8B-Instruct-GGUF'; dir='models/vlm'
     files=@('Qwen3-VL-8B-Instruct-Q4_K_M.gguf','mmproj-F16.gguf')
     rename=@{ 'Qwen3-VL-8B-Instruct-Q4_K_M.gguf' = 'qwen3-vl-8b-instruct-q4_k_m.gguf' }
     need='models/vlm/qwen3-vl-8b-instruct-q4_k_m.gguf' }

  # ---- GR00T VLA ----
  @{ g='vla';   kind='hf'; repo='nvidia/GR00T-N1.7-3B'; dir='models/vla/groot'
     files=@()
     need='models/vla/groot/model-00001-of-00003.safetensors' }

  @{ g='world'; kind='hf'; repo='nvidia/Cosmos3-Edge-Policy-DROID'; dir='models/world_model/cosmos3-edge-policy-droid'
     files=@()
     need='models/world_model/cosmos3-edge-policy-droid/transformer/diffusion_pytorch_model-00001-of-00002.safetensors' }

  # ---- CosyVoice2 TTS ----
  @{ g='tts';   kind='ms'; repo='iic/CosyVoice2-0.5B'; dir='models/cosyvoice2-0.5b'
     files=@()
     need='models/cosyvoice2-0.5b/llm.pt' }

  # ---- SenseVoice STT ----
  @{ g='stt';   kind='ms'; repo='iic/SenseVoiceSmall'; dir='models/stt/iic/SenseVoiceSmall'
     files=@()
     need='models/stt/iic/SenseVoiceSmall/model.pt' }

  @{ g='vision'; kind='hf'; repo='facebook/sam2-hiera-large'; dir='models/segmentation'
     files=@()
     need='models/segmentation/model.safetensors' }

  @{ g='local'; kind='copy'; dir='models/pointflow'
     src='models/pointflow/pointflow_weights_v7.pt'
     need='models/pointflow/pointflow_weights_v7.pt' }
  @{ g='local'; kind='copy'; dir='models/vlm/lora_adapter'
     src='models/vlm/lora_adapter/adapter_model.safetensors'
     need='models/vlm/lora_adapter/adapter_model.safetensors' }
  @{ g='local'; kind='copy'; dir='models/world_model/cosmos_lora_adapter'
     src='models/world_model/cosmos_lora_adapter/adapter_model.safetensors'
     need='models/world_model/cosmos_lora_adapter/adapter_model.safetensors' }
)

Write-Host ''
Write-Host '=============================================================' -ForegroundColor White
Write-Host '  大脑项目2 轻量版 · 模型权重下载 / 恢复' -ForegroundColor White
Write-Host '=============================================================' -ForegroundColor White
Info ("工作目录 : " + $Root)
Info ("HuggingFace CLI : " + $(if ($HfCli) { $HfCli } else { '未安装' }))
Info ("ModelScope CLI  : " + $(if ($MsCli)  { $MsCli }  else { '未安装' }))
Info ("目标分组 : " + ($Group -join ', '))
Write-Host ''

$todo = @()
foreach ($t in $Tasks) {
  if ($Group -notcontains $t.g) { continue }
  $needPath = Join-Path $Root $t.need
  if ((Test-Path -LiteralPath $needPath) -and (-not $Force)) {
    Ok ("已存在，跳过 : " + $t.need)
  } else {
    $todo += $t
  }
}

if ($todo.Count -eq 0) { Ok '该分组下没有需要下载的文件。'; exit 0 }

if ($List) {
  Write-Host ''
  Info '待处理清单：'
  foreach ($t in $todo) {
    $kindTxt = switch ($t.kind) { 'hf' { 'HuggingFace' } 'ms' { 'ModelScope' } default { '本地复制' } }
    Say ("   [" + $t.g + "] " + $kindTxt + "  " + $(if ($t.repo) { $t.repo } else { $t.src }) + "  ->  " + $t.need)
  }
  exit 0
}

foreach ($t in $todo) {
  Write-Host ''
  Write-Host ('-------------------------------------------------------------') -ForegroundColor DarkGray
  Info ("[" + $t.g + "] 目标 : " + $t.need)

  if ($t.kind -eq 'hf') {
    if (-not $HfCli) { Err '未找到 hf / huggingface-cli，请先执行: pip install -U "huggingface_hub[cli]"'; continue }
    $dirAbs = Join-Path $Root $t.dir
    New-Item -ItemType Directory -Force -Path $dirAbs | Out-Null
    $a = @('download', $t.repo)
    if ($t.files -and $t.files.Count -gt 0) { $a += $t.files }
    $a += @('--local-dir', $dirAbs)
    & $HfCli @a
    if ($LASTEXITCODE -ne 0) { Err ("下载失败 : " + $t.repo + "（请核对仓库名 / 网络）"); continue }
  }
  elseif ($t.kind -eq 'ms') {
    if (-not $MsCli) { Err '未找到 modelscope，请先执行: pip install -U modelscope'; continue }
    $dirAbs = Join-Path $Root $t.dir
    New-Item -ItemType Directory -Force -Path $dirAbs | Out-Null
    & $MsCli download --model $t.repo --local_dir $dirAbs
    if ($LASTEXITCODE -ne 0) { Err ("下载失败 : " + $t.repo); continue }
  }
  elseif ($t.kind -eq 'copy') {
    if (-not $OriginalProject) {
      Warn ('本地训练产物需从原项目复制，请加参数 -OriginalProject "<原项目路径>"，例如：')
      Say  ('    -OriginalProject "C:\Users\redact\Desktop\大脑项目2"')
      continue
    }
    $srcPath = Join-Path $OriginalProject $t.src
    if (-not (Test-Path -LiteralPath $srcPath)) { Err ("原项目中找不到 : " + $srcPath); continue }
    $dirAbs = Join-Path $Root $t.dir
    New-Item -ItemType Directory -Force -Path $dirAbs | Out-Null
    Copy-Item -LiteralPath $srcPath -Destination $dirAbs -Force
    Ok ("已复制 : " + $t.src)
  }

  if ($t.rename) {
    foreach ($k in $t.rename.Keys) {
      $from = Join-Path (Join-Path $Root $t.dir) $k
      $to   = Join-Path (Join-Path $Root $t.dir) $t.rename[$k]
      if ((Test-Path -LiteralPath $from) -and ($from -ne $to)) {
        if (Test-Path -LiteralPath $to) { Remove-Item -LiteralPath $to -Force }
        Move-Item -LiteralPath $from -Destination $to -Force
        Ok ("已重命名 : " + $k + "  ->  " + $t.rename[$k])
      }
    }
  }

  $ph = Join-Path $Root ($t.need + '.placeholder')
  if ((Test-Path -LiteralPath (Join-Path $Root $t.need)) -and (Test-Path -LiteralPath $ph)) {
    Remove-Item -LiteralPath $ph -Force
  }
}

Write-Host ''
Write-Host '=============================================================' -ForegroundColor White
Info '完成后请运行校验：'
Say  '    node scripts\verify-local-models.js'
Say  '    powershell -File scripts\verify_weights.ps1'
Write-Host '=============================================================' -ForegroundColor White
Write-Host ''
