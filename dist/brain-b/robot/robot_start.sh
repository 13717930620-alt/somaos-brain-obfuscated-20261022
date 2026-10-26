#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $(date '+%H:%M:%S') $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $(date '+%H:%M:%S') $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $1"; }

cleanup() {
    log_warn "正在停止所有进程..."
    [ -n "$LLM_PID" ] && kill $LLM_PID 2>/dev/null
    [ -n "$BRAIN_PID" ] && kill $BRAIN_PID 2>/dev/null
    [ -n "$CAM_PID" ] && kill $CAM_PID 2>/dev/null
    [ -n "$ROBOT_PID" ] && kill $ROBOT_PID 2>/dev/null
    [ -n "$RT_PID" ] && kill $RT_PID 2>/dev/null
    log_info "所有进程已停止"
}
trap cleanup EXIT INT TERM

GROOT_HOST="${GROOT_HOST:-127.0.0.1}"
GROOT_PORT="${GROOT_PORT:-8001}"
LLM_PORT="${LLM_PORT:-18080}"
BRAIN_PORT="${BRAIN_PORT:-3001}"
ROBOT_TYPE="${ROBOT_TYPE:-franka_droid}"
LLM_MODEL="${LLM_MODEL:-$PROJECT_ROOT/models/llm/qwen3-14b-instruct-q4_k_m.gguf}"
LLAMA_DIR="${LLAMA_DIR:-$PROJECT_ROOT/llama}"

# ═══════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════
log_info "Step 1/5: 启动 LLM 服务 (llama-server)..."
LLAMA_SERVER="$LLAMA_DIR/llama-server"
if [ ! -x "$LLAMA_SERVER" ] && [ -f "$LLAMA_SERVER.exe" ]; then
    LLAMA_SERVER="$LLAMA_SERVER.exe"
fi
if [ -x "$LLAMA_SERVER" ] && [ -f "$LLM_MODEL" ]; then
    "$LLAMA_SERVER" \
        --model "$LLM_MODEL" \
        --port "$LLM_PORT" \
        --ctx-size 8192 \
        --n-gpu-layers 32 &
    LLM_PID=$!
    sleep 3
    log_info "LLM 已启动 (端口 $LLM_PORT, 模型 $(basename "$LLM_MODEL"))"
else
    log_warn "llama-server 或 LLM 权重未就绪, 跳过 LLM 服务 (语言功能将降级)"
    log_warn "  查找位置: $LLAMA_SERVER / $LLM_MODEL"
fi

log_info "Step 2/5: 启动 Node.js Brain (daemon模式)..."
cd "$PROJECT_ROOT"
node "$PROJECT_ROOT/scripts/daemon.js" "$PROJECT_ROOT/scripts/start_robot.js" &
BRAIN_PID=$!
log_info "Brain daemon PID: $BRAIN_PID"

log_info "等待 Brain 就绪..."
for i in $(seq 1 30); do
    if curl -s "http://127.0.0.1:${BRAIN_PORT}/health" > /dev/null 2>&1; then
        log_info "Brain 就绪 (${i}s)"
        break
    fi
    sleep 2
done

log_info "Step 4/5: 启动摄像头采集..."
python "$SCRIPT_DIR/camera_capture.pyc" \
    --fps 30 \
    --resolution 640x480 \
    --output "http://${GROOT_HOST}:${GROOT_PORT}/frame" &
CAM_PID=$!
log_info "摄像头采集 PID: $CAM_PID"

log_info "Step 5/5: 启动机器人驱动..."
python "$SCRIPT_DIR/robot_driver.py" \
    --robot-type "$ROBOT_TYPE" \
    --brain-url "http://127.0.0.1:${BRAIN_PORT}" \
    --groot-url "http://${GROOT_HOST}:${GROOT_PORT}" &
ROBOT_PID=$!
log_info "机器人驱动 PID: $ROBOT_PID"

log_info "启动 1kHz 实时控制循环..."
python "$SCRIPT_DIR/robot_rt_loop.pyc" \
    --brain-url "http://127.0.0.1:${BRAIN_PORT}" \
    --frequency 1000 &
RT_PID=$!
log_info "实时控制 PID: $RT_PID"

# ═══════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════
log_info "执行全脑自检..."
sleep 3
if curl -s "http://127.0.0.1:${BRAIN_PORT}/brain-status" > /dev/null 2>&1; then
    STATUS=$(curl -s "http://127.0.0.1:${BRAIN_PORT}/brain-status")
    echo ""
    echo "══════════════════════════════════════════════"
    echo "  ✅ SomaOS 全脑启动完成"
    echo "  🧠 Brain PID:     $BRAIN_PID"
    echo "  🎥 Camera PID:    $CAM_PID"
    echo "  🤖 Robot PID:     $ROBOT_PID"
    echo "  ⚡ RealTime PID:  $RT_PID"
    echo "  🖥️  GR00T Server:  $GROOT_HOST:$GROOT_PORT"
    echo "  📡 Brain API:     http://127.0.0.1:$BRAIN_PORT"
    echo "══════════════════════════════════════════════"
    echo ""
else
    log_error "全脑自检失败！请检查日志: $LOG_DIR"
    exit 1
fi

log_info "所有服务运行中. 按 Ctrl+C 停止."
wait
