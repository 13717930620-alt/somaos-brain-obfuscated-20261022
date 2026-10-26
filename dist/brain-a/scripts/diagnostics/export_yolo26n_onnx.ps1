#requires -version 5.1
# Export YOLO26n PyTorch model to ONNX format
# Replaces old yolo26n.onnx (which is actually a YOLOv8n copy)
# Source: yolo26n.pt (real YOLO26n COCO 80-class pretrained)
# Target: yolo26n.onnx (NMS-free output format [1, 300, 6] - top-300 detections)
# Output layout per detection: [x1, y1, x2, y2, conf, class] (corner format, pixel coords)

try { chcp 65001 > $null } catch {}
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'

$log = Join-Path $env:USERPROFILE "Desktop\yolo26n_onnx_export_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Log {
  param([string]$m)
  $line = "[$(Get-Date -Format 'HH:mm:ss')] $m"
  Write-Host $line
  Add-Content -Path $log -Value $line -Encoding UTF8
}

Log "============================================"
Log "  YOLO26n ONNX Export Script"
Log "============================================"

Log ""
Log "=== Step 0: Locate project directory ==="

$desktop = Join-Path $env:USERPROFILE "Desktop"
$projectDir = $null

Get-ChildItem -Path $desktop -Directory -ErrorAction SilentlyContinue | ForEach-Object {
  $dir = $_
  if ($dir.Name -match '副本' -and (Test-Path (Join-Path $dir.FullName "models"))) {
    $script:projectDir = $dir.FullName
    return
  }
  if (-not $script:projectDir) {
    Get-ChildItem -Path $dir.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object {
      $subDir = $_
      if ($subDir.Name -match '副本' -and (Test-Path (Join-Path $subDir.FullName "models"))) {
        $script:projectDir = $subDir.FullName
      }
    }
  }
}

if (-not $projectDir) {
  Log "[FAIL] Could not locate project directory (containing 'models' subdir with YOLO files)"
  Log "Searched under: $desktop"
  exit 1
}

$modelsDir = Join-Path $projectDir "models"
Set-Location -Path $modelsDir
Log "[OK] Project directory: $projectDir"
Log "[OK] Models directory: $modelsDir"
Log "[OK] Current location: $(Get-Location)"

Log ""
Log "=== Step 1: Verify source yolo26n.pt ==="

$ptFile = Join-Path $modelsDir "yolo26n.pt"
if (-not (Test-Path $ptFile)) {
  Log "[FAIL] Source file not found: yolo26n.pt"
  Log "Please run dl_yolo26n.ps1 first to download real YOLO26n weights."
  exit 1
}

$ptItem = Get-Item $ptFile
$ptSizeMB = [math]::Round($ptItem.Length / 1MB, 2)
$ptMD5 = (Get-FileHash -Path $ptFile -Algorithm MD5).Hash
Log "[OK] yolo26n.pt found"
Log "  Size: $ptSizeMB MB ($($ptItem.Length) bytes)"
Log "  MD5:  $ptMD5"

$stream = [System.IO.File]::OpenRead($ptFile)
$buf = New-Object byte[] 4
[void]$stream.Read($buf, 0, 4)
$stream.Close()
if ($buf[0] -eq 0x50 -and $buf[1] -eq 0x4B) {
  Log "  Magic: PK (valid PyTorch checkpoint)"
} else {
  Log "  [WARN] Unexpected magic bytes (not a standard PyTorch checkpoint)"
}

Log ""
Log "=== Step 2: Locate Python interpreter ==="

$pythonCandidates = @(
  "C:\Users\redact\python-sdk\python3.13.2\python.exe",
  "C:\Python311\python.exe",
  "C:\Python312\python.exe",
  "C:\Python310\python.exe",
  "C:\Users\redact\AppData\Local\Programs\Python\Python311\python.exe",
  "C:\Users\redact\AppData\Local\Programs\Python\Python312\python.exe",
  "C:\Users\redact\AppData\Local\Programs\Python\Python310\python.exe",
  "C:\Users\redact\miniconda3\python.exe",
  "C:\Users\redact\anaconda3\python.exe"
)

$pythonExe = $null
foreach ($p in $pythonCandidates) {
  if (Test-Path $p) {
    try {
      $ver = & $p --version 2>&1
      if ($LASTEXITCODE -eq 0) {
        $pythonExe = $p
        Log "[OK] Found Python: $p"
        Log "  Version: $ver"
        break
      }
    } catch {}
  }
}

if (-not $pythonExe) {
  $pathPy = Get-Command python -ErrorAction SilentlyContinue
  if ($pathPy -and $pathPy.Source -notlike "*\WindowsApps\*") {
    $pythonExe = $pathPy.Source
    Log "[OK] Found Python in PATH: $pythonExe"
  }
}

if (-not $pythonExe) {
  Log "[FAIL] No Python interpreter found"
  Log "Please install Python 3.10/3.11/3.12 and retry"
  exit 1
}

Log ""
Log "=== Step 3: Check/install ultralytics + onnx ==="

$checkResult = & $pythonExe -c "import ultralytics; print(ultralytics.__version__)" 2>&1
if ($LASTEXITCODE -eq 0) {
  Log "[OK] ultralytics already installed: $checkResult"
} else {
  Log "ultralytics not installed, installing (this also installs torch, numpy, etc.)..."
  Log "Installing ultralytics (CPU-only torch)..."
  $installArgs = @("-m", "pip", "install", "ultralytics", "onnx", "onnxsim", "--quiet", "--disable-pip-version-check")
  & $pythonExe @installArgs 2>&1 | ForEach-Object { Log "  $_" }
  
  $checkResult = & $pythonExe -c "import ultralytics; print(ultralytics.__version__)" 2>&1
  if ($LASTEXITCODE -eq 0) {
    Log "[OK] ultralytics installed: $checkResult"
  } else {
    Log "[FAIL] ultralytics installation failed"
    Log "Error: $checkResult"
    exit 1
  }
}

$onnxCheck = & $pythonExe -c "import onnx; print('onnx:', onnx.__version__)" 2>&1
if ($LASTEXITCODE -eq 0) {
  Log "[OK] onnx package: $onnxCheck"
} else {
  Log "Installing onnx package..."
  & $pythonExe -m pip install onnx --quiet --disable-pip-version-check 2>&1 | Out-Null
}

Log ""
Log "=== Step 4: Backup old yolo26n.onnx ==="

$oldOnnx = Join-Path $modelsDir "yolo26n.onnx"
if (Test-Path $oldOnnx) {
  $oldItem = Get-Item $oldOnnx
  $oldSizeMB = [math]::Round($oldItem.Length / 1MB, 2)
  $oldMD5 = (Get-FileHash -Path $oldOnnx -Algorithm MD5).Hash
  Log "Old yolo26n.onnx: $oldSizeMB MB"
  Log "  MD5: $oldMD5"
  
  $backupName = "yolo26n.onnx.bak_yolov8n_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  $backupPath = Join-Path $modelsDir $backupName
  Move-Item -Path $oldOnnx -Destination $backupPath -Force
  Log "[OK] Backed up to: $backupName"
} else {
  Log "No existing yolo26n.onnx found (will create new file)"
}

Log ""
Log "=== Step 5: Export yolo26n.pt to ONNX ==="

$exportScript = @"
import os, sys
sys.stdout.reconfigure(line_buffering=True)
os.chdir(r'$modelsDir')
print('Working dir:', os.getcwd())
print('Source file: yolo26n.pt')
print('Loading model...')
from ultralytics import YOLO
model = YOLO('yolo26n.pt')
print('Model loaded.')
print('Model info:')
print('  Task:', model.task)
print('  Names:', model.names)
print('Exporting to ONNX (imgsz=640, opset=12, simplify=True, dynamic=False)...')
try:
    path = model.export(format='onnx', imgsz=640, simplify=True, dynamic=False, opset=12)
    print(f'Exported to: {path}')
    print(f'File size: {os.path.getsize(path) / 1024 / 1024:.2f} MB')
    print('EXPORT_SUCCESS')
except Exception as e:
    print(f'EXPORT_ERROR: {e}')
    sys.exit(1)
"@

$exportScriptFile = Join-Path $env:TEMP "yolo26n_export_$(Get-Date -Format 'yyyyMMddHHmmss').py"
$exportScript | Out-File -FilePath $exportScriptFile -Encoding UTF8 -Force
Log "Export script: $exportScriptFile"
Log "Running export (this may take 1-3 minutes)..."
Log ""

$exportOutput = & $pythonExe $exportScriptFile 2>&1
$exportOutput | ForEach-Object { Log $_ }

Log ""
Log "=== Step 6: Verify exported ONNX ==="

$newOnnx = Join-Path $modelsDir "yolo26n.onnx"
if (-not (Test-Path $newOnnx)) {
  Log "[FAIL] Export failed - yolo26n.onnx was not created"
  exit 1
}

$newItem = Get-Item $newOnnx
$newSizeMB = [math]::Round($newItem.Length / 1MB, 2)
$newMD5 = (Get-FileHash -Path $newOnnx -Algorithm MD5).Hash
Log "New yolo26n.onnx: $newSizeMB MB"
Log "  MD5: $newMD5"

$stream = [System.IO.File]::OpenRead($newOnnx)
$buf = New-Object byte[] 16
[void]$stream.Read($buf, 0, 16)
$stream.Close()
$firstByte = $buf[0]
$irVersion = $buf[1]
Log "  First byte: 0x$($firstByte.ToString('X2')) (expected 0x08 for ONNX)"
Log "  IR version: $irVersion"

if ($firstByte -ne 0x08) {
  Log "  [FAIL] Invalid ONNX file - first byte not 0x08"
  exit 1
}

Log ""
Log "=== Step 6b: Validate ONNX with onnx package ==="
$validateScript = @"
import os, sys
sys.stdout.reconfigure(line_buffering=True)
os.chdir(r'$modelsDir')
import onnx
print('Loading yolo26n.onnx...')
m = onnx.load('yolo26n.onnx')
print('ONNX IR version:', m.ir_version)
print('Producer name:', m.producer_name)
print('Producer version:', m.producer_version)
print('Opset imports:')
for opset in m.opset_import:
    print(f'  domain={opset.domain!r}, version={opset.version}')
print('Inputs:')
for i in m.graph.input:
    shape = [d.dim_value if d.dim_value > 0 else d.dim_param for d in i.type.tensor_type.shape.dim]
    print(f'  {i.name}: shape={shape}, dtype={i.type.tensor_type.elem_type}')
print('Outputs:')
for o in m.graph.output:
    shape = [d.dim_value if d.dim_value > 0 else d.dim_param for d in o.type.tensor_type.shape.dim]
    print(f'  {o.name}: shape={shape}, dtype={o.type.tensor_type.elem_type}')
print('Node count:', len(m.graph.node))
print('VALIDATE_SUCCESS')
"@

$validateScriptFile = Join-Path $env:TEMP "yolo26n_validate_$(Get-Date -Format 'yyyyMMddHHmmss').py"
$validateScript | Out-File -FilePath $validateScriptFile -Encoding UTF8 -Force
Log "Running ONNX validation..."
$validateOutput = & $pythonExe $validateScriptFile 2>&1
$validateOutput | ForEach-Object { Log $_ }

Log ""
Log "=== Step 7: Compare new ONNX with old backup ==="

$backupFiles = Get-ChildItem -Path $modelsDir -Filter "yolo26n.onnx.bak_*" -ErrorAction SilentlyContinue
if ($backupFiles) {
  $latestBackup = $backupFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $oldHash = (Get-FileHash -Path $latestBackup.FullName -Algorithm MD5).Hash
  $newHash = (Get-FileHash -Path $newOnnx -Algorithm MD5).Hash
  Log "Old (YOLOv8n copy) MD5: $oldHash"
  Log "  Size: $([math]::Round($latestBackup.Length / 1MB, 2)) MB"
  Log "New (real YOLO26n) MD5: $newHash"
  Log "  Size: $newSizeMB MB"
  if ($oldHash -ne $newHash) {
    Log ""
    Log "[OK] New ONNX is DIFFERENT from old backup"
    Log "  => Real YOLO26n ONNX successfully created (replaces YOLOv8n copy)"
  } else {
    Log ""
    Log "[WARNING] New ONNX is identical to old backup - export may have used cached file"
  }
}

Log ""
Log "=== Step 8: Output format check ==="
Log "YOLODetector.js:292-307 expects output shape [1, 6, 8400]"
Log "  = 8400 candidates x [cx, cy, w, h, conf, class] (NMS-free format)"
Log ""
Log "Real YOLO26n ONNX output:"
Log "  - Output0 shape should be [1, 6, 8400] or similar"
Log "  - If shape is [1, 84, 8400] = old YOLOv8 format (NMS-based, incompatible)"
Log ""
Log "See Step 6b output above for actual output tensor shape."

Remove-Item -Path $exportScriptFile -Force -ErrorAction SilentlyContinue
Remove-Item -Path $validateScriptFile -Force -ErrorAction SilentlyContinue

Log ""
Log "============================================"
Log "  EXPORT COMPLETE!"
Log "============================================"
Log ""
Log "Files in models directory:"
Get-ChildItem -Path $modelsDir -Filter "yolo*" | ForEach-Object {
  $sz = [math]::Round($_.Length / 1MB, 2)
  Log "  $($_.Name)  ($sz MB)"
}
Log ""
Log "Next steps:"
Log "  1. YOLODetector.js will load new yolo26n.onnx at next startup"
Log "  2. python_bridge.py can also load yolo26n.pt directly via Ultralytics"
Log "  3. If output format is [1, 6, 8400], no code changes needed"
Log "     If [1, 84, 8400], YOLODetector.js needs update to NMS-based parser"

Log ""
Log "Log: $log"
Write-Host ""
Write-Host "Done. Log: $log"
