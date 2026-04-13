#!/bin/bash
# =============================================================================
# Benchmark #08: Voice STT & TTS Performance
# Tests Whisper large-v3 (STT) and MMS-TTS Malay (TTS) on the GX10
#
# Models:
#   1. Whisper large-v3 (faster-whisper, float16) — speech-to-text
#   2. MMS-TTS Malay (facebook/mms-tts-zlm, VITS) — text-to-speech
#
# Test matrix:
#   TTS: 4 text lengths (short/medium/long/very_long), 3 reps
#   STT: 6 audio durations (5s/15s/30s/60s/120s/300s), 3 reps
#
# Output:
#   results_*.csv, summary_*.csv, metadata_*.json, log_*.txt, report_*.html
# =============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="log_${TIMESTAMP}.txt"
# ATOM: use lmmllava conda env (torch + transformers)
CONDA_ENV="lmmllava"
N_REPS=3

echo "============================================" | tee "$LOG_FILE"
echo "  ATOM Benchmark #08: Voice STT & TTS"      | tee -a "$LOG_FILE"
echo "  $(date)"                                    | tee -a "$LOG_FILE"
echo "  Reps per config: $N_REPS"                  | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"

# ---- Stop non-essential GPU services ----
echo "" | tee -a "$LOG_FILE"
echo "[Setup] Stopping non-essential services..." | tee -a "$LOG_FILE"
sudo systemctl stop comfyui 2>/dev/null || true
echo "  Done." | tee -a "$LOG_FILE"

# ---- Activate conda environment ----
eval "$(conda shell.bash hook 2>/dev/null)"
conda activate "$CONDA_ENV"

# ---- Install faster-whisper if needed ----
if ! python3 -c "from faster_whisper import WhisperModel" 2>/dev/null; then
    echo "  Installing faster-whisper..." | tee -a "$LOG_FILE"
    pip install faster-whisper -q 2>&1 | tee -a "$LOG_FILE"
fi

# ---- Run benchmark ----
echo "" | tee -a "$LOG_FILE"
python3 benchmark.py --reps "$N_REPS" --output-dir "." 2>&1 | tee -a "$LOG_FILE"

# ---- Generate report ----
echo "" | tee -a "$LOG_FILE"
echo "[Phase 4] Generating HTML report..." | tee -a "$LOG_FILE"

RESULTS=$(ls -t results_*.csv 2>/dev/null | head -1)
SUMMARY=$(ls -t summary_*.csv 2>/dev/null | head -1)
METADATA=$(ls -t metadata_*.json 2>/dev/null | head -1)
REPORT="report_${TIMESTAMP}.html"

if [ -n "$RESULTS" ] && [ -n "$SUMMARY" ] && [ -n "$METADATA" ]; then
    python3 generate_report.py "$RESULTS" "$SUMMARY" "$METADATA" "$REPORT" 2>&1 | tee -a "$LOG_FILE"
else
    echo "  ERROR: Missing result files!" | tee -a "$LOG_FILE"
fi

# ---- Restart ComfyUI if we stopped it ----
echo "" | tee -a "$LOG_FILE"
echo "[Cleanup] Restarting ComfyUI..." | tee -a "$LOG_FILE"
sudo systemctl start comfyui 2>/dev/null || true
echo "  Done." | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"
echo "  Benchmark Complete!" | tee -a "$LOG_FILE"
echo "  Results: $(pwd)/$RESULTS" | tee -a "$LOG_FILE"
echo "  Summary: $(pwd)/$SUMMARY" | tee -a "$LOG_FILE"
echo "  Report:  $(pwd)/$REPORT" | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"
