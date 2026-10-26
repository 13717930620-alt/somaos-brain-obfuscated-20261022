﻿#requires -version 5.1

try { chcp 65001 > $null } catch {}
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'

$PROJECT_DIR = Join-Path $PSScriptRoot "大脑项目_副本"
$DESKTOP = Join-Path $env:USERPROFILE "Desktop"
$MINICONDA_DIR = Join-Path $DESKTOP "miniconda3"
$ISAAC_GROOT_DIR = Join-Path $DESKTOP "Isaac-GR00T"
$ENV_FILE = Join-Path $PROJECT_DIR ".env"
$LOG_FILE = Join-Path $PROJECT_DIR "setup_env.log"

function Log {
  param([string]$msg, [string]$level = "INFO")
  $line = "[$(Get-Date -Format 'HH:mm:ss')] [$level] $msg"
  Write-Host $line
  Add-Content -Path $LOG_FILE -Value $line -Encoding UTF8
}

function LogStep {
  param([string]$n, [string]$title)
  Log ""
  Log "============================================================"
  Log "  Step $n : $title"
  Log "============================================================"
}

function Check-Exit {
  param([string]$action)
  if ($LASTEXITCODE -ne 0) {
    Log "命令失败 (exit=$LASTEXITCODE): $action" "ERROR"
    Log "请查看上方输出定位问题, 修复后重新运行本脚本" "ERROR"
    exit 1
  }
}

function Write-Ok { param([string]$m) Write-Host "  [OK]   $m" -ForegroundColor Green }
function Write-Skip { param([string]$m) Write-Host "  [SKIP] $m" -ForegroundColor Yellow }
function Write-Fail { param([string]$m) Write-Host "  [FAIL] $m" -ForegroundColor Red }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "     大脑项目环境自动配置脚本" -ForegroundColor Cyan
Write-Host "     SomaOS Brain Agent - Environment Setup" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Log "脚本开始执行, 日志保存到: $LOG_FILE"
Log "项目目录: $PROJECT_DIR"
Log "目标 Miniconda 安装目录: $MINICONDA_DIR"
Log "目标 Isaac-GR00T 目录: $ISAAC_GROOT_DIR"
Write-Host ""

LogStep "1" "基础环境检查"

if (-not (Test-Path (Join-Path $PROJECT_DIR "package.json"))) {
  Write-Fail "项目目录不正确, 找不到 package.json"
  Write-Host "  请确认 setup_env.ps1 位于 大脑项目_副本 文件夹根目录"
  exit 1
}
Write-Ok "项目目录: $PROJECT_DIR"

$os = [System.Environment]::OSVersion.Version
Log "操作系统版本: Windows $os"
if ($os.Major -lt 10) {
  Write-Fail "需要 Windows 10 或更高版本"
  exit 1
}
Write-Ok "Windows 版本符合要求"

if ($PSVersionTable.PSVersion.Major -lt 5) {
  Write-Fail "需要 PowerShell 5.0+, 当前: $($PSVersionTable.PSVersion)"
  exit 1
}
Write-Ok "PowerShell 版本: $($PSVersionTable.PSVersion)"

$netOk = $false
try {
  $req = [System.Net.WebRequest]::Create("https://github.com")
  $req.Timeout = 5000
  $resp = $req.GetResponse()
  $resp.Close()
  $netOk = $true
  Write-Ok "网络连接正常 (GitHub 可达)"
} catch {
  Write-Fail "无法访问 GitHub, 请检查网络/代理"
  Write-Host "  如使用代理, 请先设置: `$env:HTTPS_PROXY='http://127.0.0.1:7890'"
  exit 1
}

$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
  Write-Ok "Git 已安装: $($gitCmd.Source)"
} else {
  Write-Skip "Git 未安装 (可选, 用于更新框架)"
  Write-Host "         下载地址: https://git-scm.com/download/win"
}

$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCmd) {
  $nodeVer = & node --version 2>&1
  Write-Ok "Node.js 已安装: $nodeVer"
} else {
  Write-Fail "Node.js 未安装 (必需)"
  Write-Host "  请先安装 Node.js 18+: https://nodejs.org/"
  Write-Host "  安装后重新运行本脚本"
  exit 1
}

$npmCmd = Get-Command npm -ErrorAction SilentlyContinue
if ($npmCmd) {
  $npmVer = & npm --version 2>&1
  Write-Ok "npm 已安装: $npmVer"
} else {
  Write-Fail "npm 未安装 (随 Node.js 一起)"
  exit 1
}

$drive = Split-Path $DESKTOP -Qualifier
$free = (Get-PSDrive $drive.TrimEnd(':')).Free / 1GB
Log "磁盘 $drive 可用空间: $([math]::Round($free, 1)) GB"
if ($free -lt 20) {
  Write-Fail "磁盘空间不足 20GB (当前 $([math]::Round($free,1)) GB)"
  Write-Host "  Miniconda + 依赖约需 8GB, 模型权重已在项目内, 但仍需预留空间"
  exit 1
}
Write-Ok "磁盘空间充足"

LogStep "2" "Miniconda3 安装"

$condaExe = Join-Path $MINICONDA_DIR "Scripts\conda.exe"
$condaPy = Join-Path $MINICONDA_DIR "python.exe"

if (Test-Path $condaExe) {
  Write-Skip "Miniconda3 已安装: $MINICONDA_DIR"
  $condaVer = & $condaExe --version 2>&1
  Log "conda 版本: $condaVer"
} else {
  Write-Host "  下载 Miniconda3 安装包..." -ForegroundColor Cyan
  $installerUrl = "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe"
  $installerPath = Join-Path $env:TEMP "Miniconda3-latest-Windows-x86_64.exe"

  try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing -TimeoutSec 600
    Write-Ok "下载完成: $installerPath"
  } catch {
    Write-Fail "下载失败: $($_.Exception.Message)"
    Write-Host "  手动下载: $installerUrl"
    Write-Host "  保存为: $installerPath"
    Write-Host "  然后重新运行本脚本"
    exit 1
  }

  Write-Host "  静默安装到: $MINICONDA_DIR ..." -ForegroundColor Cyan
  Write-Host "  (大约 2-5 分钟, 请耐心等待)"
  $installArgs = "/InstallationType=JustMe /RegisterPython=0 /AddToPath=0 /S /D=$MINICONDA_DIR"
  $proc = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru
  if ($proc.ExitCode -ne 0) {
    Write-Fail "Miniconda3 安装失败 (exit=$($proc.ExitCode))"
    exit 1
  }
  Write-Ok "Miniconda3 安装完成"

  Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
  Log "已删除安装包"
}

if (-not (Test-Path $condaExe)) {
  Write-Fail "conda.exe 不存在: $condaExe"
  exit 1
}
Write-Ok "conda 可执行: $condaExe"

& $condaExe init powershell 2>&1 | Out-Null
Write-Ok "conda 已初始化 PowerShell 钩子"

LogStep "3" "创建 conda 环境 'groot' (Python 3.12)"

$grootPy = Join-Path $MINICONDA_DIR "envs\groot\python.exe"
$envsList = & $condaExe env list 2>&1
$grootExists = $envsList | Select-String -Pattern "\bgroot\b" -Quiet

if ($grootExists -and (Test-Path $grootPy)) {
  Write-Skip "conda 环境 'groot' 已存在"
  $grootVer = & $grootPy --version 2>&1
  Log "  Python 版本: $grootVer"
} else {
  Write-Host "  创建 conda 环境: groot (Python 3.12)..." -ForegroundColor Cyan
  Write-Host "  (大约 1-2 分钟)"
  & $condaExe create -n groot python=3.12 -y 2>&1 | ForEach-Object { Log "  $_" }
  Check-Exit "conda create"

  if (-not (Test-Path $grootPy)) {
    Write-Fail "环境创建后 python.exe 不存在: $grootPy"
    exit 1
  }
  Write-Ok "conda 环境 'groot' 创建完成"
}

$grootVer = & $grootPy --version 2>&1
if ($grootVer -notmatch "Python 3\.12") {
  Write-Fail "Python 版本不是 3.12: $grootVer"
  Write-Host "  GR00T N1.7 框架要求 Python 3.12, 不能用其他版本"
  exit 1
}
Write-Ok "groot 环境 Python: $grootVer"

LogStep "4" "安装 Python 依赖 (约 3GB, 耗时 10-30 分钟)"

Write-Host "  升级 pip..." -ForegroundColor Cyan
& $grootPy -m pip install --upgrade pip setuptools wheel 2>&1 | Select-Object -Last 3 | ForEach-Object { Log "  $_" }
Write-Ok "pip 升级完成"

$needTorch = $true
$needDeps = $true
try {
  $torchCheck = & $grootPy -c "import torch; print(torch.__version__)" 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-Skip "torch 已安装: $torchCheck"
    $needTorch = $false
  }
} catch {}
try {
  $diffCheck = & $grootPy -c "import diffusers; print(diffusers.__version__)" 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-Skip "diffusers 已安装: $diffCheck"
    $needDeps = $false
  }
} catch {}

if ($needTorch) {
  Write-Host "  安装 PyTorch (CUDA 12.1)..." -ForegroundColor Cyan
  Write-Host "  (大约 5-10 分钟, 包大约 2.5GB)"
  & $grootPy -m pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121 2>&1 |
    Select-Object -Last 5 | ForEach-Object { Log "  $_" }
  Check-Exit "pip install torch"
  Write-Ok "PyTorch 安装完成"
}

if ($needDeps) {
  Write-Host "  安装 diffusers + transformers + 其他依赖..." -ForegroundColor Cyan
  Write-Host "  (大约 3-5 分钟)"
  $deps = @(
    "diffusers==0.35.1",
    "transformers==4.57.3",
    "accelerate",
    "safetensors",
    "einops",
    "huggingface_hub",
    "pillow",
    "opencv-python-headless",
    "numpy<2.0",
    "pyyaml",
    "tqdm",
    "requests",
    "aiohttp",
    "scipy",
    "matplotlib",
    "pandas"
  )
  & $grootPy -m pip install $deps 2>&1 |
    Select-Object -Last 5 | ForEach-Object { Log "  $_" }
  Check-Exit "pip install deps"
  Write-Ok "Python 依赖安装完成"
}

Write-Host "  验证关键依赖..." -ForegroundColor Cyan
$depsCheck = @(
  @{name="torch"; code="import torch; print(f'torch {torch.__version__}, cuda={torch.cuda.is_available()}')"},
  @{name="diffusers"; code="import diffusers; print(f'diffusers {diffusers.__version__}')"},
  @{name="transformers"; code="import transformers; print(f'transformers {transformers.__version__}')"},
  @{name="einops"; code="import einops; print('einops OK')"},
  @{name="safetensors"; code="import safetensors; print('safetensors OK')"}
)
$depsOk = $true
foreach ($d in $depsCheck) {
  $r = & $grootPy -c $d.code 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-Ok "$($d.name): $r"
  } else {
    Write-Fail "$($d.name): $r"
    $depsOk = $false
  }
}
if (-not $depsOk) {
  Write-Fail "部分依赖验证失败"
  exit 1
}

LogStep "5" "Isaac-GR00T 框架安装"

if (Test-Path (Join-Path $ISAAC_GROOT_DIR "pyproject.toml")) {
  Write-Skip "Isaac-GR00T 已存在: $ISAAC_GROOT_DIR"
} else {
  $gitCmd = Get-Command git -ErrorAction SilentlyContinue
  if (-not $gitCmd) {
    Write-Fail "Git 未安装, 无法 clone Isaac-GR00T"
    Write-Host "  请先安装 Git: https://git-scm.com/download/win"
    Write-Host "  或从 https://github.com/NVIDIA/Isaac-GR00T 下载 ZIP 解压到: $ISAAC_GROOT_DIR"
    exit 1
  }

  Write-Host "  克隆 Isaac-GR00T 仓库到桌面..." -ForegroundColor Cyan
  Write-Host "  (大约 5-10 分钟, 含子模块)"
  & git clone --recurse-submodules https://github.com/NVIDIA/Isaac-GR00T $ISAAC_GROOT_DIR 2>&1 |
    ForEach-Object { Log "  $_" }
  Check-Exit "git clone Isaac-GR00T"

  if (-not (Test-Path (Join-Path $ISAAC_GROOT_DIR "pyproject.toml"))) {
    Write-Fail "克隆完成后 pyproject.toml 不存在"
    exit 1
  }
  Write-Ok "Isaac-GR00T 克隆完成"
}

Write-Host "  安装 Isaac-GR00T 到 conda 环境 (--no-deps)..." -ForegroundColor Cyan
Push-Location $ISAAC_GROOT_DIR
& $grootPy -m pip install -e . --no-deps 2>&1 |
  Select-Object -Last 5 | ForEach-Object { Log "  $_" }
$installExit = $LASTEXITCODE
Pop-Location
if ($installExit -ne 0) {
  Write-Fail "Isaac-GR00T 安装失败 (exit=$installExit)"
  Write-Host "  可尝试手动: cd $ISAAC_GROOT_DIR; pip install -e . --no-deps"
  exit 1
}
Write-Ok "Isaac-GR00T 安装完成"

$grootMod = & $grootPy -c "from gr00t.model import Gr00tN1d7Pipeline; print('GR00T N1.7 框架 OK')" 2>&1
if ($LASTEXITCODE -eq 0) {
  Write-Ok "Isaac-GR00T 框架验证: $grootMod"
} else {
  Write-Skip "Isaac-GR00T 框架导入测试未通过 (可能缺依赖, 不影响 stub 模式)"
  Log "详细: $grootMod"
}

LogStep "6" "配置 .env 文件"

if (-not (Test-Path $ENV_FILE)) {
  $envExample = Join-Path $PROJECT_DIR ".env.example"
  if (Test-Path $envExample) {
    Copy-Item $envExample $ENV_FILE -Force
    Write-Ok "从 .env.example 创建 .env"
  } else {
    @"
COSMOS_HOST=127.0.0.1
COSMOS_PORT=5001
COSMOS_MODEL_PATH=models/world_model/cosmos3-edge-policy-droid
COSMOS_PYTHON=$grootPy
"@ | Set-Content -Path $ENV_FILE -Encoding UTF8
    Write-Ok "新建 .env"
  }
}

$envContent = Get-Content $ENV_FILE -Raw
if ($envContent -match "COSMOS_PYTHON\s*=") {
  $envContent = $envContent -replace "(?m)^COSMOS_PYTHON=.*", "COSMOS_PYTHON=$grootPy"
  Set-Content -Path $ENV_FILE -Value $envContent -Encoding UTF8 -NoNewline
  Write-Ok "已设置 COSMOS_PYTHON=$grootPy"
} else {
  Add-Content -Path $ENV_FILE -Value "`nCOSMOS_PYTHON=$grootPy" -Encoding UTF8
  Write-Ok "已追加 COSMOS_PYTHON=$grootPy"
}

$verifyContent = Get-Content $ENV_FILE -Raw
if ($verifyContent -match "COSMOS_PYTHON=$([regex]::Escape($grootPy))") {
  Write-Ok ".env 配置验证通过"
} else {
  Write-Fail ".env 配置写入失败"
  exit 1
}

LogStep "7" "配置 HuggingFace 镜像 (国内加速)"

$hfEnvPath = Join-Path $env:USERPROFILE ".cache\huggingface"
if (-not (Test-Path $hfEnvPath)) {
  New-Item -ItemType Directory -Path $hfEnvPath -Force | Out-Null
}

$hfExisting = [System.Environment]::GetEnvironmentVariable("HF_ENDPOINT", "User")
if ($hfExisting -ne "https://hf-mirror.com") {
  [System.Environment]::SetEnvironmentVariable("HF_ENDPOINT", "https://hf-mirror.com", "User")
  Write-Ok "已设置 HF_ENDPOINT=https://hf-mirror.com (用户级)"
  Write-Host "         重启 PowerShell 后生效"
} else {
  Write-Skip "HF_ENDPOINT 已配置"
}

LogStep "8" "最终验证"

$allOk = $true

$pyFinal = & $grootPy -c "import sys; print(f'Python {sys.version}')" 2>&1
if ($LASTEXITCODE -eq 0) {
  Write-Ok "Python 环境: $pyFinal"
} else {
  Write-Fail "Python 验证失败"
  $allOk = $false
}

$finalDeps = & $grootPy -c @"
import torch, diffusers, transformers, einops, safetensors
print('  torch:', torch.__version__, '(CUDA:', torch.cuda.is_available(), ')')
print('  diffusers:', diffusers.__version__)
print('  transformers:', transformers.__version__)
print('  einops:', einops.__version__)
print('  safetensors:', safetensors.__version__)
"@ 2>&1
if ($LASTEXITCODE -eq 0) {
  Write-Ok "Python 依赖全部可导入"
  Write-Host $finalDeps -ForegroundColor DarkGray
} else {
  Write-Fail "Python 依赖验证失败"
  Write-Host $finalDeps
  $allOk = $false
}

if (Test-Path $ENV_FILE) {
  Write-Ok ".env 文件存在"
} else {
  Write-Fail ".env 文件缺失"
  $allOk = $false
}

if (Test-Path (Join-Path $ISAAC_GROOT_DIR "pyproject.toml")) {
  Write-Ok "Isaac-GR00T 框架就位"
} else {
  Write-Skip "Isaac-GR00T 框架未就位 (可后续手动 clone)"
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
if ($allOk) {
  Write-Host "     环境配置完成!" -ForegroundColor Green
} else {
  Write-Host "     环境配置部分失败, 请查看日志" -ForegroundColor Yellow
}
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "项目目录:    $PROJECT_DIR"
Write-Host "Miniconda3:  $MINICONDA_DIR"
Write-Host "conda 环境:  $grootPy"
Write-Host "Isaac-GR00T: $ISAAC_GROOT_DIR"
Write-Host ".env 文件:   $ENV_FILE"
Write-Host "日志文件:    $LOG_FILE"
Write-Host ""
Write-Host "后续启动命令:" -ForegroundColor Cyan
Write-Host "  1. 双击运行 一键启动-具身智能.bat"
Write-Host "  2. 或在项目目录运行: node scripts\launch.js"
Write-Host ""
Write-Host "注意:" -ForegroundColor Yellow
Write-Host "  - 首次启动 GR00T/COSMOS 真实推理需要 Linux + NVIDIA GPU"
Write-Host "  - Windows 本机只能跑 stub 模拟模式 (接口测试用)"
Write-Host "  - 如需更新框架: cd $ISAAC_GROOT_DIR; git pull"
Write-Host ""
Write-Host "按任意键退出..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
