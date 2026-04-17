#!/bin/bash
# =============================================================================
# Benchmark #12: Thermal Stress Test
# Monitors CPU/GPU/NVMe temperatures under sustained AI workloads
# Matches StorageReview methodology for Gigabyte AI TOP ATOM
#
# Workload Profiles (3 phases, 10 minutes each):
#   Phase 1: Prefill Heavy (ISL=2048, OSL=1) — GPU compute intensive
#   Phase 2: Equal ISL/OSL (ISL=512, OSL=512) — balanced
#   Phase 3: Decode Heavy (ISL=1, OSL=2048) — memory bandwidth intensive
#
# Monitoring:
#   - GPU temperature, power, utilization (nvidia-smi, 1s interval)
#   - CPU temperature (thermal zones)
#   - NVMe temperature (smartctl)
#   - Ambient/board sensors if available
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="$SCRIPT_DIR/results"
LOG_FILE="$SCRIPT_DIR/logs/benchmark_${TIMESTAMP}.log"
THERMAL_CSV="$RESULTS_DIR/thermal_${TIMESTAMP}.csv"
SUMMARY_CSV="$RESULTS_DIR/thermal_summary_${TIMESTAMP}.csv"

mkdir -p "$RESULTS_DIR" "$SCRIPT_DIR/logs"

# HF token for gated models
if [ -z "${HF_TOKEN:-}" ]; then
    if [ -f "$HOME/.cache/huggingface/token" ]; then
        export HF_TOKEN=$(cat "$HOME/.cache/huggingface/token")
    else
        echo "WARNING: HF_TOKEN not set and no token file found."
    fi
fi

VLLM_IMAGE="nvcr.io/nvidia/vllm:26.01-py3"
VLLM_PORT=8000
VLLM_CONTAINER="vllm-thermal"
CACHE_DIR="/raid/cache"
MODEL_ID="Qwen/Qwen2.5-7B-Instruct"  # Use 7B for thermal test (fast loading)

PHASE_DURATION=600  # 10 minutes per phase
SAMPLE_INTERVAL=1   # 1 second between temperature samples
CONCURRENT_REQUESTS=4  # Keep GPU busy

# ============================================================================
# Helper functions
# ============================================================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

get_gpu_temp() {
    nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ' '
}

get_gpu_power() {
    nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null | tr -d ' '
}

get_gpu_util() {
    nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ' '
}

get_cpu_temp() {
    # ARM thermal zones
    local max_temp=0
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        if [ -f "$zone" ]; then
            local temp=$(cat "$zone" 2>/dev/null)
            if [ -n "$temp" ] && [ "$temp" -gt "$max_temp" ]; then
                max_temp=$temp
            fi
        fi
    done
    echo $((max_temp / 1000))
}

get_nvme_temp() {
    # Try smartctl first, fall back to hwmon
    local temp=$(sudo smartctl -A /dev/nvme0 2>/dev/null | grep -i "temperature" | head -1 | grep -oP '\d+' | head -1)
    if [ -z "$temp" ]; then
        temp=$(cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
        [ -n "$temp" ] && temp=$((temp / 1000))
    fi
    echo "${temp:-0}"
}

stop_vllm() {
    log "Stopping vLLM container..."
    sudo docker rm -f "$VLLM_CONTAINER" 2>/dev/null || true
    sleep 5
}

# Temperature monitoring background process
monitor_temps() {
    local phase="$1"
    local csv_file="$2"
    local duration="$3"
    local end_time=$(($(date +%s) + duration))

    while [ "$(date +%s)" -lt "$end_time" ]; do
        local ts=$(date +%s)
        local gpu_temp=$(get_gpu_temp)
        local gpu_power=$(get_gpu_power)
        local gpu_util=$(get_gpu_util)
        local cpu_temp=$(get_cpu_temp)
        local nvme_temp=$(get_nvme_temp)

        echo "$ts,$phase,$gpu_temp,$gpu_power,$gpu_util,$cpu_temp,$nvme_temp" >> "$csv_file"
        sleep "$SAMPLE_INTERVAL"
    done
}

# Generate load by sending continuous requests
generate_load() {
    local isl="$1"
    local osl="$2"
    local duration="$3"
    local end_time=$(($(date +%s) + duration))

    local input_text=""
    if [ "$isl" -gt 1 ]; then
        input_text=$(python3 -c "print(' '.join(['The quick brown fox jumps over the lazy dog.'] * ($isl // 10 + 1))[:$isl*4])")
    else
        input_text="Hi"
    fi

    # Build request JSON once
    local req_json=$(python3 -c "
import json
print(json.dumps({
    'model': '$MODEL_ID',
    'messages': [{'role': 'user', 'content': '''$input_text'''}],
    'max_tokens': $osl,
    'temperature': 0.0
}))
")

    while [ "$(date +%s)" -lt "$end_time" ]; do
        for i in $(seq 1 $CONCURRENT_REQUESTS); do
            curl -s --max-time 60 \
                http://localhost:${VLLM_PORT}/v1/chat/completions \
                -H "Content-Type: application/json" \
                -d "$req_json" > /dev/null 2>&1 &
        done
        wait || true
    done
}

# ============================================================================
# Main
# ============================================================================
echo "============================================" | tee "$LOG_FILE"
echo "  ATOM Benchmark #12: Thermal Stress Test"  | tee -a "$LOG_FILE"
echo "  $(date)"                                    | tee -a "$LOG_FILE"
echo "  Phase duration: ${PHASE_DURATION}s ($(( PHASE_DURATION / 60 )) min)" | tee -a "$LOG_FILE"
echo "  Model: $MODEL_ID"                          | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"

# Clean up any leftover containers on this port
sudo docker rm -f "$VLLM_CONTAINER" 2>/dev/null || true
sudo docker rm -f "vllm-bench10" 2>/dev/null || true

# CSV header
echo "timestamp,phase,gpu_temp_c,gpu_power_w,gpu_util_pct,cpu_temp_c,nvme_temp_c" > "$THERMAL_CSV"

# ---- Record idle baseline (60 seconds) ----
log ""
log "Phase 0: IDLE BASELINE (60s)"
monitor_temps "idle" "$THERMAL_CSV" 60

# ---- Start vLLM ----
log ""
log "Starting vLLM with $MODEL_ID..."
sudo docker rm -f "$VLLM_CONTAINER" 2>/dev/null || true
sudo docker run -d --name "$VLLM_CONTAINER" \
    --runtime nvidia --gpus all \
    --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
    -v "${CACHE_DIR}:/root/.cache" \
    -e HF_TOKEN="${HF_TOKEN:-}" \
    -p ${VLLM_PORT}:8000 \
    --entrypoint python3 \
    "$VLLM_IMAGE" \
    -m vllm.entrypoints.openai.api_server \
    --model "$MODEL_ID" \
    --max-model-len 4096 \
    --dtype auto \
    --gpu-memory-utilization 0.8 2>&1 | tee -a "$LOG_FILE"

log "Waiting for vLLM..."
vllm_ready=false
for i in $(seq 1 1200); do
    if curl -s http://localhost:${VLLM_PORT}/health > /dev/null 2>&1; then
        log "vLLM ready (took ${i}s)"
        vllm_ready=true
        break
    fi
    # Check if container crashed early
    if ! sudo docker ps -q -f name="$VLLM_CONTAINER" | grep -q .; then
        log "ERROR: vLLM container exited prematurely"
        sudo docker logs --tail 30 "$VLLM_CONTAINER" 2>&1 | tee -a "$LOG_FILE"
        break
    fi
    if [ $((i % 60)) -eq 0 ]; then
        log "Still waiting... (${i}s)"
    fi
    sleep 1
done

if [ "$vllm_ready" = false ]; then
    log "FATAL: vLLM failed to start. Cannot run thermal stress test."
    stop_vllm
    exit 1
fi
sleep 5

# ---- Phase 1: Prefill Heavy ----
log ""
log "Phase 1: PREFILL HEAVY (ISL=2048, OSL=1) — ${PHASE_DURATION}s"
generate_load 2048 1 "$PHASE_DURATION" &
LOAD_PID=$!
monitor_temps "prefill_heavy" "$THERMAL_CSV" "$PHASE_DURATION"
kill $LOAD_PID 2>/dev/null; wait $LOAD_PID 2>/dev/null || true

# ---- Cooldown (60s) ----
log ""
log "Cooldown: 60s"
monitor_temps "cooldown_1" "$THERMAL_CSV" 60

# ---- Phase 2: Equal ISL/OSL ----
log ""
log "Phase 2: EQUAL ISL/OSL (ISL=512, OSL=512) — ${PHASE_DURATION}s"
generate_load 512 512 "$PHASE_DURATION" &
LOAD_PID=$!
monitor_temps "equal" "$THERMAL_CSV" "$PHASE_DURATION"
kill $LOAD_PID 2>/dev/null; wait $LOAD_PID 2>/dev/null || true

# ---- Cooldown (60s) ----
log ""
log "Cooldown: 60s"
monitor_temps "cooldown_2" "$THERMAL_CSV" 60

# ---- Phase 3: Decode Heavy ----
log ""
log "Phase 3: DECODE HEAVY (ISL=1, OSL=2048) — ${PHASE_DURATION}s"
generate_load 1 2048 "$PHASE_DURATION" &
LOAD_PID=$!
monitor_temps "decode_heavy" "$THERMAL_CSV" "$PHASE_DURATION"
kill $LOAD_PID 2>/dev/null; wait $LOAD_PID 2>/dev/null || true

# ---- Final cooldown ----
log ""
log "Final cooldown: 120s"
monitor_temps "cooldown_final" "$THERMAL_CSV" 120

# ---- Stop vLLM ----
stop_vllm

# ============================================================================
# Summary
# ============================================================================
log ""
log "============================================"
log "THERMAL STRESS TEST COMPLETE"
log "============================================"

python3 - "$THERMAL_CSV" << 'PYEOF'
import csv, sys

csv_path = sys.argv[1]

phases = {}
with open(csv_path, "r") as f:
    reader = csv.DictReader(f)
    for row in reader:
        phase = row["phase"]
        if phase not in phases:
            phases[phase] = {"gpu_temp": [], "gpu_power": [], "cpu_temp": [], "nvme_temp": []}
        for key, pkey in [("gpu_temp_c","gpu_temp"), ("gpu_power_w","gpu_power"), ("cpu_temp_c","cpu_temp"), ("nvme_temp_c","nvme_temp")]:
            try:
                val = float(row[key])
                if val > 0:
                    phases[phase][pkey].append(val)
            except:
                pass

print(f"\n{'Phase':<20} {'GPU Temp':>10} {'GPU Power':>11} {'CPU Temp':>10} {'NVMe Temp':>11}")
print("-" * 65)
for phase in ["idle", "prefill_heavy", "equal", "decode_heavy"]:
    if phase in phases:
        p = phases[phase]
        gpu_t = f"{max(p['gpu_temp']):.0f}C" if p['gpu_temp'] else "N/A"
        gpu_p = f"{max(p['gpu_power']):.1f}W" if p['gpu_power'] else "N/A"
        cpu_t = f"{max(p['cpu_temp']):.0f}C" if p['cpu_temp'] else "N/A"
        nvme_t = f"{max(p['nvme_temp']):.0f}C" if p['nvme_temp'] else "N/A"
        print(f"{phase:<20} {gpu_t:>10} {gpu_p:>11} {cpu_t:>10} {nvme_t:>11}")
PYEOF

log ""
log "Results: $THERMAL_CSV"
log "Done."
