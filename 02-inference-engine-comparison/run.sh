#!/bin/bash
# =============================================================================
# Benchmark #2: Serving Engine Comparison
# Same model on vLLM vs Ollama vs llama.cpp
# Measures: tok/s, TTFT, total time
#
# Uses Qwen2.5-7B for fair comparison across all 3 engines.
# vLLM runs via NVIDIA docker container (nvcr.io/nvidia/vllm)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="$RESULTS_DIR/results_${TIMESTAMP}.csv"
LOG_FILE="$RESULTS_DIR/log_${TIMESTAMP}.txt"

PROMPT="Explain quantum computing in 3 paragraphs. Be detailed and technical."
NUM_TOKENS=256
OLLAMA_MODEL="qwen2.5:7b"
VLLM_MODEL="Qwen/Qwen2.5-7B-Instruct"
VLLM_PORT=8001
VLLM_CONTAINER="vllm-bench02"

echo "============================================" | tee "$LOG_FILE"
echo "  ATOM Benchmark: Serving Engine Comparison" | tee -a "$LOG_FILE"
echo "  Machine: Gigabyte GB10 (ATOM)" | tee -a "$LOG_FILE"
echo "  Model: Qwen2.5-7B on all engines" | tee -a "$LOG_FILE"
echo "  $(date)" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"

echo "engine,test,tok_s,ttft_ms,total_time_s,tokens,gpu_temp" > "$RESULTS_FILE"

# ============================================================================
# ENGINE 1: OLLAMA
# ============================================================================
echo "" | tee -a "$LOG_FILE"
echo "=== ENGINE 1: OLLAMA ===" | tee -a "$LOG_FILE"

# Pull model if needed
if ! ollama list 2>/dev/null | grep -q "qwen2.5.*7b"; then
    echo "  Pulling $OLLAMA_MODEL..." | tee -a "$LOG_FILE"
    ollama pull "$OLLAMA_MODEL" 2>&1 | tail -3 | tee -a "$LOG_FILE"
fi

# Warm up
echo "  Warming up..." | tee -a "$LOG_FILE"
curl -s http://localhost:11434/api/generate -d "{\"model\":\"$OLLAMA_MODEL\",\"prompt\":\"warmup\",\"stream\":false,\"options\":{\"num_predict\":5}}" > /dev/null 2>&1
sleep 2

# Single request benchmark (3 runs)
for run in 1 2 3; do
    echo "  Run $run/3..." | tee -a "$LOG_FILE"
    RESP=$(curl -s http://localhost:11434/api/generate \
        -d "{\"model\":\"$OLLAMA_MODEL\",\"prompt\":\"$PROMPT\",\"stream\":false,\"options\":{\"num_predict\":$NUM_TOKENS}}")

    EVAL_COUNT=$(echo "$RESP" | python3 -c "import sys,json;print(json.load(sys.stdin).get('eval_count',0))" 2>/dev/null)
    EVAL_DUR=$(echo "$RESP" | python3 -c "import sys,json;print(json.load(sys.stdin).get('eval_duration',0))" 2>/dev/null)
    PROMPT_DUR=$(echo "$RESP" | python3 -c "import sys,json;print(json.load(sys.stdin).get('prompt_eval_duration',0))" 2>/dev/null)
    TOTAL_DUR=$(echo "$RESP" | python3 -c "import sys,json;print(json.load(sys.stdin).get('total_duration',0))" 2>/dev/null)

    TOK_S=$(python3 -c "print(round($EVAL_COUNT / ($EVAL_DUR / 1e9), 2))" 2>/dev/null || echo "0")
    TTFT=$(python3 -c "print(round($PROMPT_DUR / 1e6, 1))" 2>/dev/null || echo "0")
    TOTAL_S=$(python3 -c "print(round($TOTAL_DUR / 1e9, 2))" 2>/dev/null || echo "0")
    GPU_T=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null || echo "N/A")

    echo "    tok/s: $TOK_S | TTFT: ${TTFT}ms | Total: ${TOTAL_S}s | GPU: ${GPU_T}C" | tee -a "$LOG_FILE"
    echo "ollama,single_run${run},$TOK_S,$TTFT,$TOTAL_S,$EVAL_COUNT,$GPU_T" >> "$RESULTS_FILE"
    sleep 1
done

# Unload Ollama model
curl -s http://localhost:11434/api/generate -d "{\"model\":\"$OLLAMA_MODEL\",\"keep_alive\":0}" > /dev/null 2>&1
sleep 3

# ============================================================================
# ENGINE 2: vLLM (via NVIDIA docker)
# ============================================================================
echo "" | tee -a "$LOG_FILE"
echo "=== ENGINE 2: vLLM ===" | tee -a "$LOG_FILE"

# Stop any existing bench container
sudo docker rm -f "$VLLM_CONTAINER" 2>/dev/null || true

echo "  Starting vLLM container with $VLLM_MODEL..." | tee -a "$LOG_FILE"
sudo docker run -d --name "$VLLM_CONTAINER" \
    --runtime nvidia --gpus all \
    --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
    -v /raid/cache/huggingface:/root/.cache/huggingface \
    -v /raid/cache/vllm:/root/.cache/vllm \
    -p ${VLLM_PORT}:8000 \
    --entrypoint python3 \
    nvcr.io/nvidia/vllm:26.01-py3 \
    -m vllm.entrypoints.openai.api_server \
    --model "$VLLM_MODEL" \
    --max-model-len 4096 \
    --dtype auto 2>&1 | tee -a "$LOG_FILE"

# Wait for vLLM to be ready (can take a few minutes to download + load)
echo "  Waiting for vLLM to be ready..." | tee -a "$LOG_FILE"
VLLM_READY=false
for i in $(seq 1 300); do
    if curl -s http://localhost:${VLLM_PORT}/health > /dev/null 2>&1; then
        echo "  vLLM ready (took ${i}s)" | tee -a "$LOG_FILE"
        VLLM_READY=true
        break
    fi
    if [ $((i % 30)) -eq 0 ]; then
        echo "  Still waiting... (${i}s)" | tee -a "$LOG_FILE"
    fi
    sleep 1
done

if [ "$VLLM_READY" = true ]; then
    sleep 5

    # Single request benchmark (3 runs)
    for run in 1 2 3; do
        echo "  Run $run/3..." | tee -a "$LOG_FILE"
        START_NS=$(date +%s%N)

        RESP=$(curl -s http://localhost:${VLLM_PORT}/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$VLLM_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"$PROMPT\"}],\"max_tokens\":$NUM_TOKENS,\"temperature\":0.2}")

        END_NS=$(date +%s%N)
        TOTAL_S=$(python3 -c "print(round(($END_NS - $START_NS) / 1e9, 2))")

        TOKENS=$(echo "$RESP" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('usage',{}).get('completion_tokens',0))" 2>/dev/null || echo "0")
        TOK_S=$(python3 -c "print(round($TOKENS / $TOTAL_S, 2))" 2>/dev/null || echo "0")
        GPU_T=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null || echo "N/A")

        echo "    tok/s: $TOK_S | Total: ${TOTAL_S}s | Tokens: $TOKENS | GPU: ${GPU_T}C" | tee -a "$LOG_FILE"
        echo "vllm,single_run${run},$TOK_S,0,$TOTAL_S,$TOKENS,$GPU_T" >> "$RESULTS_FILE"
        sleep 1
    done
else
    echo "  ERROR: vLLM failed to start within 300s" | tee -a "$LOG_FILE"
    echo "  Container logs:" | tee -a "$LOG_FILE"
    sudo docker logs --tail 20 "$VLLM_CONTAINER" 2>&1 | tee -a "$LOG_FILE"
fi

# Stop vLLM container
echo "  Stopping vLLM container..." | tee -a "$LOG_FILE"
sudo docker rm -f "$VLLM_CONTAINER" 2>/dev/null || true
sleep 3

# ============================================================================
# ENGINE 3: llama.cpp (direct)
# ============================================================================
echo "" | tee -a "$LOG_FILE"
echo "=== ENGINE 3: llama.cpp ===" | tee -a "$LOG_FILE"

LLAMA_BENCH="/home/atom/Utility_dont_remove/llama.cpp/build/bin/llama-bench"
LLAMA_BIN_DIR="$(dirname "$LLAMA_BENCH")"
export LD_LIBRARY_PATH="${LLAMA_BIN_DIR}:${LD_LIBRARY_PATH:-}"

# Find a qwen2.5-7b GGUF model from Ollama blobs
# Ollama stores models as sha256 blobs under /usr/share/ollama/ (runs as 'ollama' user)
GGUF_MODEL=$(sudo find /usr/share/ollama/.ollama/models/blobs/ -type f -size +4G -size -6G -name "sha256-*" 2>/dev/null | head -1)

if [ -f "$LLAMA_BENCH" ] && [ -n "$GGUF_MODEL" ]; then
    echo "  Running llama-bench with Qwen2.5-7B GGUF..." | tee -a "$LOG_FILE"
    echo "  Model file: $GGUF_MODEL" | tee -a "$LOG_FILE"

    # Token generation benchmark (sudo needed — Ollama blobs owned by ollama user)
    BENCH_OUT=$(sudo LD_LIBRARY_PATH="$LD_LIBRARY_PATH" "$LLAMA_BENCH" -m "$GGUF_MODEL" -p 0 -n $NUM_TOKENS -r 3 -ngl 99 -fa 1 -o csv 2>/dev/null)
    echo "$BENCH_OUT" | tee -a "$LOG_FILE"

    # Extract tok/s from the CSV output
    TG_TOKS=$(echo "$BENCH_OUT" | tail -1 | awk -F, '{print $NF}')
    GPU_T=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null || echo "N/A")

    echo "    Token generation: $TG_TOKS tok/s | GPU: ${GPU_T}C" | tee -a "$LOG_FILE"
    echo "llama.cpp,tg_bench,$TG_TOKS,0,0,$NUM_TOKENS,$GPU_T" >> "$RESULTS_FILE"

    # Prompt processing benchmark
    BENCH_PP=$(sudo LD_LIBRARY_PATH="$LD_LIBRARY_PATH" "$LLAMA_BENCH" -m "$GGUF_MODEL" -p 512 -n 0 -r 3 -ngl 99 -fa 1 -o csv 2>/dev/null)
    PP_TOKS=$(echo "$BENCH_PP" | tail -1 | awk -F, '{print $NF}')
    echo "    Prompt processing: $PP_TOKS tok/s" | tee -a "$LOG_FILE"
    echo "llama.cpp,pp_bench,$PP_TOKS,0,0,512,$GPU_T" >> "$RESULTS_FILE"
else
    echo "  SKIPPED — llama-bench binary or GGUF model not found" | tee -a "$LOG_FILE"
    echo "  llama-bench: $LLAMA_BENCH (exists: $([ -f "$LLAMA_BENCH" ] && echo yes || echo no))" | tee -a "$LOG_FILE"
    echo "  GGUF: $GGUF_MODEL" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"
echo "  Benchmark Complete!" | tee -a "$LOG_FILE"
echo "  Results: $RESULTS_FILE" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"

# Print summary
echo "" | tee -a "$LOG_FILE"
echo "SUMMARY:" | tee -a "$LOG_FILE"
cat "$RESULTS_FILE" | tee -a "$LOG_FILE"
