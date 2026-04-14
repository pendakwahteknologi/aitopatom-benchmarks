#!/bin/bash
# =============================================================================
# Benchmark #07: Image & Video Generation Speed
# Tests ComfyUI generation performance on the GX10
#
# Models:
#   1. Z-Image-Turbo (bf16) — text-to-image, 4 steps
#   2. Wan 2.2 T2V 14B (fp8) — text-to-video, 4 steps (LightX2V LoRA)
#
# Test matrix:
#   Image: 512x512, 768x768, 1024x1024, 1280x1280 (4 steps) + 1024x1024 (8 steps)
#   Video: 640x640 (33/49/81 frames) + 480x480 (33 frames)
#   Repetitions: 3 per config
#
# Output:
#   results_*.csv, summary_*.csv, metadata_*.json, log_*.txt, report_*.html
# =============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="log_${TIMESTAMP}.txt"
# ATOM: ComfyUI uses conda env, not venv
CONDA_ENV="comfyui"
N_REPS=3

echo "============================================" | tee "$LOG_FILE"
echo "  ATOM Benchmark #07: Image & Video Gen"    | tee -a "$LOG_FILE"
echo "  $(date)"                                    | tee -a "$LOG_FILE"
echo "  Reps per config: $N_REPS"                  | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"

# ---- Ensure ComfyUI is running ----
echo "" | tee -a "$LOG_FILE"
echo "[Setup] Checking ComfyUI..." | tee -a "$LOG_FILE"

if ! curl -s http://127.0.0.1:8188/system_stats > /dev/null 2>&1; then
    echo "  ComfyUI is not running. Starting..." | tee -a "$LOG_FILE"
    sudo systemctl start comfyui
    echo "  Waiting for ComfyUI to be ready..." | tee -a "$LOG_FILE"
    for i in $(seq 1 60); do
        if curl -s http://127.0.0.1:8188/system_stats > /dev/null 2>&1; then
            echo "  ComfyUI is ready (took ${i}s)" | tee -a "$LOG_FILE"
            break
        fi
        sleep 1
    done
    if ! curl -s http://127.0.0.1:8188/system_stats > /dev/null 2>&1; then
        echo "  ERROR: ComfyUI failed to start!" | tee -a "$LOG_FILE"
        exit 1
    fi
else
    echo "  ComfyUI is already running." | tee -a "$LOG_FILE"
fi

# ---- Activate conda environment ----
echo "" | tee -a "$LOG_FILE"
echo "[Setup] Activating conda environment..." | tee -a "$LOG_FILE"
eval "$(conda shell.bash hook 2>/dev/null)"
conda activate "$CONDA_ENV"
echo "  Using: $(which python3)" | tee -a "$LOG_FILE"

# ---- Ensure websocket-client is available ----
echo "" | tee -a "$LOG_FILE"
echo "[Setup] Checking websocket-client..." | tee -a "$LOG_FILE"
if ! python3 -c "import websocket" 2>/dev/null; then
    echo "  Installing websocket-client..." | tee -a "$LOG_FILE"
    pip install websocket-client -q 2>&1 | tee -a "$LOG_FILE"
fi
echo "  OK" | tee -a "$LOG_FILE"

# ---- Run benchmark ----
echo "" | tee -a "$LOG_FILE"
N_VIDEO_REPS=2
# Skip video: WAN 2.2 T2V VAE decoding is CPU-bound on ARM and takes 3+ hours per video
# Image-only benchmark completes in ~10 minutes
python3 benchmark.py --reps "$N_REPS" --video-reps "$N_VIDEO_REPS" --skip-video 2>&1 | tee -a "$LOG_FILE"

# ---- Generate report ----
echo "" | tee -a "$LOG_FILE"
echo "[Phase 3] Generating HTML report..." | tee -a "$LOG_FILE"

# Find the latest results files
RESULTS=$(ls -t results_*.csv 2>/dev/null | head -1)
SUMMARY=$(ls -t summary_*.csv 2>/dev/null | head -1)
METADATA=$(ls -t metadata_*.json 2>/dev/null | head -1)
REPORT="report_${TIMESTAMP}.html"

if [ -n "$RESULTS" ] && [ -n "$SUMMARY" ] && [ -n "$METADATA" ]; then
    python3 generate_report.py "$RESULTS" "$SUMMARY" "$METADATA" "$REPORT" 2>&1 | tee -a "$LOG_FILE"
else
    echo "  ERROR: Missing result files!" | tee -a "$LOG_FILE"
fi

# ---- Cleanup ----

echo "" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"
echo "  Benchmark Complete!" | tee -a "$LOG_FILE"
echo "  Results: $(pwd)/$RESULTS" | tee -a "$LOG_FILE"
echo "  Summary: $(pwd)/$SUMMARY" | tee -a "$LOG_FILE"
echo "  Report:  $(pwd)/$REPORT" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"
