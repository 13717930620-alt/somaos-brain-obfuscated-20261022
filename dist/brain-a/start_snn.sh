#!/bin/bash

cd "$(dirname "$0")"

PY="training/venv_gpu/bin/python"
[ -x "$PY" ] || PY="python3"

echo "启动 EMBER SNN 服务 ($PY) ..."
"$PY" services/embersnn/ember_snn_service.pyc \
  --port 8002 \
  --n-sensory 2000 \
  --n-concept 1500 \
  --n-category 1000 \
  --n-meta 500
