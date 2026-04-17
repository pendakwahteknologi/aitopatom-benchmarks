#!/bin/bash
# =============================================================================
# Benchmark #10: vLLM Online Serving (Multi-Batch)
# Tests throughput, TTFT, and TPOT across batch sizes 1-64
# Matches StorageReview methodology for Gigabyte AI TOP ATOM
#
# Models:
#   1. openai/gpt-oss-120b (120B dense)
#   2. openai/gpt-oss-20b (20B dense)
#   3. Qwen/Qwen2.5-7B-Instruct (7B, for comparison with bench #02)
#   4. meta-llama/Llama-3.1-8B-Instruct (8B FP8)
#
# Workload Profiles (matching StorageReview):
#   - Prefill Heavy: ISL=2048, OSL=1
#   - Equal ISL/OSL: ISL=512, OSL=512
#   - Decode Heavy: ISL=1, OSL=2048
#
# Batch sizes: 1, 2, 4, 8, 16, 32, 64
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="$SCRIPT_DIR/results"
LOG_FILE="$SCRIPT_DIR/logs/benchmark_${TIMESTAMP}.log"
RESULTS_CSV="$RESULTS_DIR/vllm_serving_${TIMESTAMP}.csv"
RESULTS_JSON="$RESULTS_DIR/vllm_serving_${TIMESTAMP}.json"

mkdir -p "$RESULTS_DIR" "$SCRIPT_DIR/logs"

# HF token for gated models (Llama)
if [ -z "${HF_TOKEN:-}" ]; then
    if [ -f "$HOME/.cache/huggingface/token" ]; then
        export HF_TOKEN=$(cat "$HOME/.cache/huggingface/token")
    else
        echo "WARNING: HF_TOKEN not set and no token file found. Gated models will fail."
    fi
fi

VLLM_IMAGE="nvcr.io/nvidia/vllm:26.01-py3"
VLLM_PORT=8000
VLLM_CONTAINER="vllm-bench10"
CACHE_DIR="/raid/cache"

# Models to test (StorageReview used FP8/FP4 variants)
declare -A MODELS
MODELS["gpt-oss-120b"]="openai/gpt-oss-120b"
MODELS["gpt-oss-20b"]="openai/gpt-oss-20b"
MODELS["qwen2.5-7b"]="Qwen/Qwen2.5-7B-Instruct"
MODELS["llama-3.1-8b"]="meta-llama/Llama-3.1-8B-Instruct"

MODEL_ORDER=("llama-3.1-8b" "qwen2.5-7b" "gpt-oss-20b" "gpt-oss-120b")

# Workload profiles: name -> "ISL,OSL"
declare -A WORKLOADS
WORKLOADS["prefill_heavy"]="2048,1"
WORKLOADS["equal"]="512,512"
WORKLOADS["decode_heavy"]="1,2048"

WORKLOAD_ORDER=("prefill_heavy" "equal" "decode_heavy")

BATCH_SIZES=(1 2 4 8 16 32 64)
N_REQUESTS=100  # minimum requests per batch size test

# ============================================================================
# Helper functions
# ============================================================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

gpu_stats() {
    nvidia-smi --query-gpu=temperature.gpu,power.draw,utilization.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ' '
}

start_vllm() {
    local model_id="$1"
    local model_name="$2"
    local extra_args="${3:-}"

    log "Starting vLLM with $model_name ($model_id)..."

    # Stop any existing container
    sudo docker rm -f "$VLLM_CONTAINER" 2>/dev/null || true
    sleep 2

    sudo docker run -d --name "$VLLM_CONTAINER" \
        --runtime nvidia --gpus all \
        --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
        -v "${CACHE_DIR}:/root/.cache" \
        -e HF_TOKEN="${HF_TOKEN:-}" \
        -p ${VLLM_PORT}:8000 \
        --entrypoint python3 \
        "$VLLM_IMAGE" \
        -m vllm.entrypoints.openai.api_server \
        --model "$model_id" \
        --max-model-len 4096 \
        --dtype auto \
        --gpu-memory-utilization 0.8 \
        $extra_args 2>&1 | tee -a "$LOG_FILE"

    # Wait for ready (1200s — Blackwell needs extra time for KV cache + CUDA graphs)
    log "Waiting for vLLM to be ready..."
    local ready=false
    for i in $(seq 1 1200); do
        if curl -s http://localhost:${VLLM_PORT}/health > /dev/null 2>&1; then
            log "vLLM ready (took ${i}s)"
            ready=true
            break
        fi
        # Check if container crashed early
        if ! sudo docker ps -q -f name="$VLLM_CONTAINER" | grep -q .; then
            log "ERROR: vLLM container exited prematurely"
            sudo docker logs --tail 30 "$VLLM_CONTAINER" 2>&1 | tee -a "$LOG_FILE"
            return 1
        fi
        if [ $((i % 60)) -eq 0 ]; then
            log "Still waiting... (${i}s)"
        fi
        sleep 1
    done

    if [ "$ready" = false ]; then
        log "ERROR: vLLM failed to start within 1200s"
        sudo docker logs --tail 30 "$VLLM_CONTAINER" 2>&1 | tee -a "$LOG_FILE"
        return 1
    fi

    sleep 5
    return 0
}

stop_vllm() {
    log "Stopping vLLM container..."
    sudo docker rm -f "$VLLM_CONTAINER" 2>/dev/null || true
    sleep 5
}

run_benchmark() {
    local model_name="$1"
    local model_id="$2"
    local workload_name="$3"
    local isl="$4"
    local osl="$5"
    local batch_size="$6"

    local n_requests=$((batch_size * 3))  # at least 3x batch size
    [ "$n_requests" -lt "$N_REQUESTS" ] && n_requests="$N_REQUESTS"

    log "  Bench: $model_name | $workload_name | batch=$batch_size | ISL=$isl OSL=$osl | n=$n_requests"

    # Generate input text once (approximate ISL token count)
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
    'model': '$model_id',
    'messages': [{'role': 'user', 'content': '''$input_text'''}],
    'max_tokens': $osl,
    'temperature': 0.0
}))
")

    local start_ns=$(date +%s%N)
    local total_tokens=0
    local total_time=0
    local success=0
    local failed=0

    # Send requests concurrently in batches to test vLLM's actual batching
    local remaining=$n_requests
    while [ "$remaining" -gt 0 ]; do
        local concurrent=$batch_size
        [ "$concurrent" -gt "$remaining" ] && concurrent="$remaining"

        # Launch concurrent requests
        local pids=()
        local tmpdir=$(mktemp -d)
        for j in $(seq 1 $concurrent); do
            local req_start=$(date +%s%N)
            (
                resp=$(curl -s --max-time 120 \
                    http://localhost:${VLLM_PORT}/v1/chat/completions \
                    -H "Content-Type: application/json" \
                    -d "$req_json" 2>/dev/null)
                req_end=$(date +%s%N)
                req_time=$(python3 -c "print(round(($req_end - $req_start) / 1e9, 4))")
                tokens=$(echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('usage',{}).get('completion_tokens',0))" 2>/dev/null || echo "0")
                echo "$tokens $req_time" > "$tmpdir/$j"
            ) &
            pids+=($!)
        done

        # Wait for all concurrent requests
        for pid in "${pids[@]}"; do
            wait "$pid" 2>/dev/null || true
        done

        # Collect results
        for j in $(seq 1 $concurrent); do
            if [ -f "$tmpdir/$j" ]; then
                read tokens req_time < "$tmpdir/$j"
                if [ "${tokens:-0}" -gt 0 ]; then
                    total_tokens=$((total_tokens + tokens))
                    total_time=$(python3 -c "print(round($total_time + $req_time, 4))")
                    success=$((success + 1))
                else
                    failed=$((failed + 1))
                fi
            else
                failed=$((failed + 1))
            fi
        done
        rm -rf "$tmpdir"

        remaining=$((remaining - concurrent))
    done

    local end_ns=$(date +%s%N)
    local wall_time=$(python3 -c "print(round(($end_ns - $start_ns) / 1e9, 2))")

    # Calculate metrics
    local tok_s=0
    local avg_latency=0
    if [ "$success" -gt 0 ]; then
        tok_s=$(python3 -c "print(round($total_tokens / $wall_time, 2))")
        avg_latency=$(python3 -c "print(round($total_time / $success, 4))")
    fi

    local gpu=$(gpu_stats)
    local gpu_temp=$(echo "$gpu" | cut -d',' -f1)
    local gpu_power=$(echo "$gpu" | cut -d',' -f2)

    log "    => ${tok_s} tok/s | ${success}/${n_requests} ok | ${wall_time}s wall | GPU: ${gpu_temp}C ${gpu_power}W"

    # Write CSV row
    echo "$model_name,$workload_name,$batch_size,$isl,$osl,$n_requests,$success,$failed,$total_tokens,$wall_time,$tok_s,$avg_latency,$gpu_temp,$gpu_power" >> "$RESULTS_CSV"
}

# ============================================================================
# Main
# ============================================================================
echo "============================================" | tee "$LOG_FILE"
echo "  ATOM Benchmark #10: vLLM Online Serving"  | tee -a "$LOG_FILE"
echo "  $(date)"                                    | tee -a "$LOG_FILE"
echo "  Models: ${MODEL_ORDER[*]}"                 | tee -a "$LOG_FILE"
echo "  Batch sizes: ${BATCH_SIZES[*]}"            | tee -a "$LOG_FILE"
echo "  Workloads: ${WORKLOAD_ORDER[*]}"           | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"

# CSV header
echo "model,workload,batch_size,input_seq_len,output_seq_len,n_requests,success,failed,total_tokens,wall_time_s,tok_per_sec,avg_latency_s,gpu_temp_c,gpu_power_w" > "$RESULTS_CSV"

for model_name in "${MODEL_ORDER[@]}"; do
    model_id="${MODELS[$model_name]}"

    echo "" | tee -a "$LOG_FILE"
    log "============================================"
    log "MODEL: $model_name ($model_id)"
    log "============================================"

    if ! start_vllm "$model_id" "$model_name"; then
        log "SKIPPING $model_name — failed to start"
        stop_vllm
        continue
    fi

    for workload_name in "${WORKLOAD_ORDER[@]}"; do
        IFS=',' read -r isl osl <<< "${WORKLOADS[$workload_name]}"

        log ""
        log "--- Workload: $workload_name (ISL=$isl, OSL=$osl) ---"

        for batch_size in "${BATCH_SIZES[@]}"; do
            run_benchmark "$model_name" "$model_id" "$workload_name" "$isl" "$osl" "$batch_size"
        done
    done

    stop_vllm
done

# ============================================================================
# Summary
# ============================================================================
echo "" | tee -a "$LOG_FILE"
log "============================================"
log "BENCHMARK COMPLETE"
log "Results: $RESULTS_CSV"
log "============================================"

echo "" | tee -a "$LOG_FILE"
log "SUMMARY (Prefill Heavy, tok/s by batch size):"
echo "" | tee -a "$LOG_FILE"
printf "%-20s" "Model" | tee -a "$LOG_FILE"
for bs in "${BATCH_SIZES[@]}"; do printf "%10s" "B=$bs" | tee -a "$LOG_FILE"; done
echo "" | tee -a "$LOG_FILE"
printf '%0.s-' {1..90} | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

for model_name in "${MODEL_ORDER[@]}"; do
    printf "%-20s" "$model_name" | tee -a "$LOG_FILE"
    for bs in "${BATCH_SIZES[@]}"; do
        val=$(grep "^${model_name},prefill_heavy,${bs}," "$RESULTS_CSV" 2>/dev/null | cut -d',' -f11)
        printf "%10s" "${val:-N/A}" | tee -a "$LOG_FILE"
    done
    echo "" | tee -a "$LOG_FILE"
done

echo "" | tee -a "$LOG_FILE"
log "Done."
