#!/bin/bash
# =============================================================================
# Benchmark #05: Token-Per-Watt Efficiency
# Measures generation throughput vs power draw using llama-bench + nvidia-smi
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LLAMA_BENCH="/home/atom/Utility_dont_remove/llama.cpp/build/bin/llama-bench"
LLAMA_BIN_DIR="$(dirname "$LLAMA_BENCH")"
export LD_LIBRARY_PATH="${LLAMA_BIN_DIR}:${LD_LIBRARY_PATH:-}"

BLOB_DIR="/usr/share/ollama/.ollama/models/blobs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_CSV="$SCRIPT_DIR/results_${TIMESTAMP}.csv"
LOG_FILE="$SCRIPT_DIR/log_${TIMESTAMP}.txt"

TG_LENGTH=512
N_REPS=3
POWER_SAMPLE_INTERVAL=0.5

declare -A MODELS
MODELS["qwen2.5-7B"]="sha256-2bada8a7450677000f678be90653b85d364de7db25eb5ea54136ada5f3933730"
MODELS["qwen3-8B"]="sha256-a3de86cd1c132c822487ededd47a324c50491393e6565cd14bafa40d0b8e686f"
MODELS["qwen2.5-coder-32B"]="sha256-ac3d1ba8aa77755dab3806d9024e9c385ea0d5b412d6bdf9157f8a4a7e9fc0d9"
MODELS["qwen2.5-72B"]="sha256-6e7fdda508e91cb0f63de5c15ff79ac63a1584ccafd751c07ca12b7f442101b8"

MODEL_ORDER=("qwen2.5-7B" "qwen3-8B" "qwen2.5-coder-32B" "qwen2.5-72B")

echo "============================================" | tee "$LOG_FILE"
echo "  ATOM Benchmark #05: Token-Per-Watt" | tee -a "$LOG_FILE"
echo "  TG: $TG_LENGTH tokens | Reps: $N_REPS" | tee -a "$LOG_FILE"
echo "  $(date)" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"

echo "model,tg_tokens,tg_tok_sec,avg_power_w,tokens_per_watt,joules_per_token" > "$RESULTS_CSV"

for model_name in "${MODEL_ORDER[@]}"; do
    blob="${MODELS[$model_name]}"
    model_path="$BLOB_DIR/$blob"

    echo "" | tee -a "$LOG_FILE"
    echo "=== $model_name ===" | tee -a "$LOG_FILE"

    if ! sudo test -f "$model_path"; then
        echo "  SKIP: blob not found" | tee -a "$LOG_FILE"
        continue
    fi

    # Start power sampling in background
    POWER_TMP=$(mktemp)
    (
        while true; do
            p=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
            [ -n "$p" ] && echo "$p" >> "$POWER_TMP"
            sleep $POWER_SAMPLE_INTERVAL
        done
    ) &
    SAMPLER_PID=$!

    # Run benchmark
    bench_output=$(sudo LD_LIBRARY_PATH="$LD_LIBRARY_PATH" "$LLAMA_BENCH" \
        -m "$model_path" -p 0 -n "$TG_LENGTH" -r "$N_REPS" -ngl 99 -fa 1 -o csv 2>&1) || true

    # Stop power sampling
    kill $SAMPLER_PID 2>/dev/null; wait $SAMPLER_PID 2>/dev/null || true

    # Parse tok/s
    tg_tok_sec=$(echo "$bench_output" | tail -1 | sed 's/"//g' | awk -F',' '{print $(NF-1)}')

    # Parse power
    avg_power=$(awk 'BEGIN{s=0;n=0} /^[0-9]/{s+=$1;n++} END{if(n>0) printf "%.2f",s/n; else print "0"}' "$POWER_TMP")
    rm -f "$POWER_TMP"

    # Calculate efficiency
    if [ -n "$tg_tok_sec" ] && [ -n "$avg_power" ]; then
        tok_per_watt=$(python3 -c "t=$tg_tok_sec; p=$avg_power; print(f'{t/p:.3f}' if p > 0 else '0')" 2>/dev/null)
        j_per_tok=$(python3 -c "t=$tg_tok_sec; p=$avg_power; print(f'{p/t:.3f}' if t > 0 else '0')" 2>/dev/null)

        echo "  TG: ${tg_tok_sec} tok/s | Power: ${avg_power}W | Efficiency: ${tok_per_watt} tok/W" | tee -a "$LOG_FILE"
        echo "$model_name,$TG_LENGTH,$tg_tok_sec,$avg_power,$tok_per_watt,$j_per_tok" >> "$RESULTS_CSV"
    fi
done

echo "" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"
echo "  Benchmark Complete!" | tee -a "$LOG_FILE"
echo "  Results: $RESULTS_CSV" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "RESULTS:" | tee -a "$LOG_FILE"
cat "$RESULTS_CSV" | tee -a "$LOG_FILE"
