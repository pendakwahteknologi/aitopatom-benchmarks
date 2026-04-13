#!/bin/bash
# =============================================================================
# Benchmark #03: llama.cpp Inference (CUDA)
# Tests tok/s across model sizes using Ollama's GGUF blobs with llama-bench
# Models: qwen2.5-7B, qwen3-8B, qwen2.5-coder-32B, qwen2.5-72B
# Quant: All Q4_K_M (Ollama default)
# Measures: PP (prompt processing) and TG (text generation) tok/s
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LLAMA_BENCH="/home/atom/Utility_dont_remove/llama.cpp/build/bin/llama-bench"
LLAMA_BIN_DIR="$(dirname "$LLAMA_BENCH")"
export LD_LIBRARY_PATH="${LLAMA_BIN_DIR}:${LD_LIBRARY_PATH:-}"

BLOB_DIR="/usr/share/ollama/.ollama/models/blobs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_CSV="$SCRIPT_DIR/results/benchmark_${TIMESTAMP}.csv"
LOG_FILE="$SCRIPT_DIR/results/benchmark_${TIMESTAMP}.log"
mkdir -p "$SCRIPT_DIR/results"

PP_LENGTHS="128,256,512"
TG_LENGTH=128
N_REPS=3

# Model blobs identified from Ollama
declare -A MODELS
MODELS["qwen2.5-7B-Q4_K_M"]="sha256-2bada8a7450677000f678be90653b85d364de7db25eb5ea54136ada5f3933730"
MODELS["qwen3-8B-Q4_K_M"]="sha256-a3de86cd1c132c822487ededd47a324c50491393e6565cd14bafa40d0b8e686f"
MODELS["qwen2.5-coder-32B-Q4_K_M"]="sha256-ac3d1ba8aa77755dab3806d9024e9c385ea0d5b412d6bdf9157f8a4a7e9fc0d9"
MODELS["qwen2.5-72B-Q4_K_M"]="sha256-6e7fdda508e91cb0f63de5c15ff79ac63a1584ccafd751c07ca12b7f442101b8"

MODEL_ORDER=("qwen2.5-7B-Q4_K_M" "qwen3-8B-Q4_K_M" "qwen2.5-coder-32B-Q4_K_M" "qwen2.5-72B-Q4_K_M")

# System info
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
DRIVER_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
CUDA_VER=$(nvcc --version 2>/dev/null | grep "release" | sed 's/.*release //' | sed 's/,.*//')
RAM_TOTAL=$(free -h | awk '/Mem:/ {print $2}')

echo "============================================" | tee "$LOG_FILE"
echo "  ATOM Benchmark #03: llama.cpp Inference" | tee -a "$LOG_FILE"
echo "  Machine: Gigabyte GB10 (ATOM)" | tee -a "$LOG_FILE"
echo "  GPU: $GPU_NAME | CUDA $CUDA_VER" | tee -a "$LOG_FILE"
echo "  Memory: $RAM_TOTAL Unified" | tee -a "$LOG_FILE"
echo "  Backend: llama.cpp (CUDA + Flash Attention)" | tee -a "$LOG_FILE"
echo "  PP: $PP_LENGTHS tokens | TG: $TG_LENGTH tokens" | tee -a "$LOG_FILE"
echo "  Reps: $N_REPS" | tee -a "$LOG_FILE"
echo "  $(date)" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"

# Check deps
if [ ! -f "$LLAMA_BENCH" ]; then
    echo "ERROR: llama-bench not found at $LLAMA_BENCH" | tee -a "$LOG_FILE"
    exit 1
fi

# CSV header
echo "model,quant,pp_tokens,pp_tok_sec,tg_tokens,tg_tok_sec" > "$RESULTS_CSV"

TOTAL=${#MODEL_ORDER[@]}
NUM=0

for model_name in "${MODEL_ORDER[@]}"; do
    NUM=$((NUM + 1))
    blob="${MODELS[$model_name]}"
    model_path="$BLOB_DIR/$blob"

    echo "" | tee -a "$LOG_FILE"
    echo "=== [$NUM/$TOTAL] $model_name ===" | tee -a "$LOG_FILE"

    if ! sudo test -f "$model_path"; then
        echo "  SKIP: blob not found" | tee -a "$LOG_FILE"
        continue
    fi

    file_size=$(sudo ls -lh "$model_path" | awk '{print $5}')
    echo "  File: $file_size" | tee -a "$LOG_FILE"
    echo "  Running llama-bench (PP: $PP_LENGTHS, TG: $TG_LENGTH, reps: $N_REPS)..." | tee -a "$LOG_FILE"

    # Run llama-bench
    bench_output=$(sudo LD_LIBRARY_PATH="$LD_LIBRARY_PATH" "$LLAMA_BENCH" \
        -m "$model_path" \
        -p "$PP_LENGTHS" \
        -n "$TG_LENGTH" \
        -r "$N_REPS" \
        -ngl 99 \
        -fa 1 \
        -o csv 2>&1) || true

    echo "$bench_output" >> "$LOG_FILE"

    # Parse CSV output
    echo "$bench_output" | sed 's/"//g' | while IFS=',' read -r \
        f0 f1 f2 f3 f4 f5 f6 f7 f8 f9 \
        f10 f11 f12 f13 f14 f15 f16 f17 f18 f19 \
        f20 f21 f22 f23 f24 f25 f26 f27 f28 f29 \
        f30 n_prompt n_gen n_depth test_time avg_ns stddev_ns avg_ts stddev_ts; do

        if [[ "$n_prompt" =~ ^[0-9]+$ ]] && [ "$n_prompt" -gt 0 ] && [ "$n_gen" -eq 0 ]; then
            printf "  PP %4s tokens -> %10s tok/s\n" "$n_prompt" "$avg_ts" | tee -a "$LOG_FILE"
            echo "$model_name,Q4_K_M,$n_prompt,$avg_ts,0,0" >> "$RESULTS_CSV"
        elif [[ "$n_gen" =~ ^[0-9]+$ ]] && [ "$n_gen" -gt 0 ] && [ "$n_prompt" -eq 0 ]; then
            printf "  TG %4s tokens -> %10s tok/s\n" "$n_gen" "$avg_ts" | tee -a "$LOG_FILE"
            echo "$model_name,Q4_K_M,0,0,$n_gen,$avg_ts" >> "$RESULTS_CSV"
        fi
    done 2>/dev/null || true

    echo "  DONE" | tee -a "$LOG_FILE"
done

echo "" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"
echo "  Benchmark Complete!" | tee -a "$LOG_FILE"
echo "  Results: $RESULTS_CSV" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"

# Summary
echo "" | tee -a "$LOG_FILE"
echo "RESULTS:" | tee -a "$LOG_FILE"
cat "$RESULTS_CSV" | tee -a "$LOG_FILE"
