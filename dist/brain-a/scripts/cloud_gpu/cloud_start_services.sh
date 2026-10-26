#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOGDIR="$ROOT/logs"
PIDDIR="$ROOT/logs/cloud_pids"
mkdir -p "$LOGDIR" "$PIDDIR"

USE_GPU=0
ONLY=""
ACTION="start"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gpu) USE_GPU=1; shift ;;
    --cpu) USE_GPU=0; shift ;;
    --only) ONLY="$2"; shift 2 ;;
    --stop) ACTION="stop"; shift ;;
    --status) ACTION="status"; shift ;;
    -h|--help) sed -n '2,16p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

NGLL=$([[ $USE_GPU -eq 1 ]] && echo 99 || echo 0)
NTHREADS="$(nproc 2>/dev/null || echo 4)"

LLM_MODEL="${LOCAL_LLM_PATH:-models/llm/qwen3-14b-instruct-q4_k_m.gguf}"
VLM_MODEL="${LOCAL_VLM_PATH:-models/vlm/qwen3-vl-8b-instruct-q4_k_m.gguf}"
VLM_MMPROJ="${LOCAL_VLM_MMPROJ:-models/vlm/mmproj-F16.gguf}"
REASON_MODEL="${LOCAL_REASONING_PATH:-models/llm/openthinker3-1.5b-q4_k_m.gguf}"

LLAMA_BIN="$ROOT/llama/llama-server"
[[ -x "$LLAMA_BIN" ]] || LLAMA_BIN="$ROOT/llama/llama-server.exe"

SERVICES=(
  "LLM|18080|llama|$LLAMA_BIN -m $ROOT/$LLM_MODEL --host 127.0.0.1 --port 18080 -ngl $NGLL -c 16384 -t $NTHREADS"
  "VLM|18081|llama|$LLAMA_BIN -m $ROOT/$VLM_MODEL --mmproj $ROOT/$VLM_MMPROJ --host 127.0.0.1 --port 18081 -ngl $NGLL -c 4096 -t $NTHREADS"
  "REASONING_SMALL|18082|llama|$LLAMA_BIN -m $ROOT/$REASON_MODEL --host 127.0.0.1 --port 18082 -ngl $NGLL -c 8192 -t $NTHREADS"
  "STT|18090|python|python3 $ROOT/services/stt_server.pyc"
  "TTS|18091|python|python3 $ROOT/services/tts_server.pyc"
  "SAM2|18092|python|python3 $ROOT/services/sam2_server.pyc"
  "COSMOS|5001|python|python3 $ROOT/services/cosmos_server.pyc --model-path $ROOT/models/world_model/cosmos3-edge-policy-droid --port 5001"
  "GR00T|8001|python|python3 $ROOT/services/groot_server.pyc"
  "GUSH3R|8011|node|node $ROOT/gush3r_launcher.js"
)

want() {
  [[ -z "$ONLY" ]] && return 0
  local IFS=','
  for k in $ONLY; do [[ "${k^^}" == "${1^^}" ]] && return 0; done
  return 1
}

health() {
  local port="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -s -m 3 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/health" 2>/dev/null
  else
    python3 - "$port" <<'PY'
import socket,sys
s=socket.socket(); s.settimeout(2)
try:
    s.connect(("127.0.0.1",int(sys.argv[1]))); print("000")
except Exception: print("ERR")
finally: s.close()
PY
  fi
}

wait_up() {
  local port="$1" name="$2" tries="${3:-40}"
  for ((i=0;i<tries;i++)); do
    local code; code="$(health "$port")"
    [[ "$code" == "200" ]] && { echo "  [ OK ] $name :$port 已就绪"; return 0; }
    sleep 2
  done
  echo "  [WARN] $name :$port 未在超时内就绪（看 $LOGDIR/$(echo "$name" | tr 'A-Z' 'a-z').log）"
  return 1
}

case "$ACTION" in
  stop)
    for f in "$PIDDIR"/*.pid; do
      [[ -e "$f" ]] || continue
      pid="$(cat "$f")"; name="$(basename "$f" .pid)"
      kill "$pid" 2>/dev/null && echo "已停止 $name (PID $pid)" || echo "$name 已不在运行"
      rm -f "$f"
    done
    exit 0
    ;;
  status)
    printf '%-18s %-7s %-10s %s\n' 服务 端口 健康 进程
    for spec in "${SERVICES[@]}"; do
      IFS='|' read -r name port _type _cmd <<<"$spec"
      want "$name" || continue
      code="$(health "$port")"
      pidf="$PIDDIR/$name.pid"
      pid="$( [[ -e "$pidf" ]] && cat "$pidf" || echo - )"
      [[ -n "$pid" && "$pid" != "-" ]] && (kill -0 "$pid" 2>/dev/null || pid="$pid(dead)")
      printf '%-18s %-7s %-10s %s\n' "$name" "$port" "$code" "$pid"
    done
    exit 0
    ;;
esac

echo "=== SomaOS 云端服务启动 ==="
echo "根目录 : $ROOT"
echo "GPU    : $([[ $USE_GPU -eq 1 ]] && echo 启用 || echo 关闭)"
if [[ $USE_GPU -eq 1 ]] && command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | sed 's/^/         /'
fi
echo

[[ -x "$LLAMA_BIN" ]] || echo "[WARN] 未找到 llama-server: $LLAMA_BIN（LLM/VLM 会起不来）"

started=()
for spec in "${SERVICES[@]}"; do
  IFS='|' read -r name port type cmd <<<"$spec"
  want "$name" || continue

  pidf="$PIDDIR/$name.pid"
  if [[ -e "$pidf" ]] && kill -0 "$(cat "$pidf")" 2>/dev/null; then
    echo "[skip] $name 已在运行 (PID $(cat "$pidf"))"
    continue
  fi

  logf="$LOGDIR/$(echo "$name" | tr 'A-Z' 'a-z').log"
  echo "[start] $name :$port"
  if [[ "$type" == "node" ]]; then
    ( cd "$ROOT" && nohup env GUSH3R_DEVICE="$([[ $USE_GPU -eq 1 ]] && echo cuda || echo cpu)" \
        $cmd >>"$logf" 2>&1 & echo $! >"$pidf" )
  else
    ( cd "$ROOT" && nohup env HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}" \
        $cmd >>"$logf" 2>&1 & echo $! >"$pidf" )
  fi
  sleep 1
  started+=("$name:$port")
done

echo
echo "=== 健康检查（模型加载可能较慢，最多等 80s）==="
for spec in "${SERVICES[@]}"; do
  IFS='|' read -r name port _type _cmd <<<"$spec"
  want "$name" || continue
  wait_up "$port" "$name" 40
done

echo
echo "完成。下一步在本地执行:"
echo "  powershell -ExecutionPolicy Bypass -File scripts\\cloud_gpu\\tunnel.ps1 -RemoteHost <云端IP> -Port <SSH端口>"
