#!/bin/bash
# =============================================================================
# Benchmark #11: GPU Direct Storage (GDSIO)
# Tests NVMe-to-GPU transfer speeds using NVIDIA GDSIO
# Matches StorageReview methodology for Gigabyte AI TOP ATOM
#
# Tests:
#   - Read/Write throughput at 16K and 1M block sizes
#   - Thread counts: 1, 2, 4, 8, 16, 32, 64, 128
#   - Measures: throughput (GiB/s), latency (ms)
#
# Transfer modes tested:
#   - GPU Direct (x=0) if nvidia-fs driver is loaded
#   - CPU->GPU (x=2) as fallback/comparison
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="$SCRIPT_DIR/results"
LOG_FILE="$SCRIPT_DIR/logs/benchmark_${TIMESTAMP}.log"
RESULTS_CSV="$RESULTS_DIR/gdsio_${TIMESTAMP}.csv"

mkdir -p "$RESULTS_DIR" "$SCRIPT_DIR/logs"

GDSIO=$(which gdsio 2>/dev/null || echo "/usr/local/cuda-13.0/gds/tools/gdsio")
TEST_FILE="/tmp/gdsio_test_file"
FILE_SIZE="1G"
THREAD_COUNTS=(1 2 4 8 16 32 64 128)
BLOCK_SIZES=("16K" "1M")
OPERATIONS=("read" "write")
REPS=3

# ============================================================================
# Helper functions
# ============================================================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

gpu_stats() {
    nvidia-smi --query-gpu=temperature.gpu,power.draw --format=csv,noheader,nounits 2>/dev/null | tr -d ' '
}

# ============================================================================
# Pre-flight
# ============================================================================
echo "============================================" | tee "$LOG_FILE"
echo "  ATOM Benchmark #11: GPU Direct Storage"   | tee -a "$LOG_FILE"
echo "  $(date)"                                    | tee -a "$LOG_FILE"
echo "============================================" | tee -a "$LOG_FILE"

if [ ! -x "$GDSIO" ]; then
    log "ERROR: gdsio not found at $GDSIO"
    log "Install with: sudo apt install gds-tools-13-0"
    exit 1
fi
log "gdsio found: $GDSIO"

# Determine transfer mode based on nvidia-fs driver
XFER_MODES=()
XFER_NAMES=()
probe_gpu_direct() {
    # Quick probe: try a tiny GPU Direct read to see if it actually works
    local probe_file="/tmp/gdsio_probe"
    dd if=/dev/urandom of="$probe_file" bs=1M count=1 2>/dev/null
    if sudo "$GDSIO" -f "$probe_file" -d 0 -w 1 -s 1M -i 1M -x 0 -I 0 2>&1 | grep -q "Throughput"; then
        rm -f "$probe_file"
        return 0
    fi
    rm -f "$probe_file"
    return 1
}

if [ -f /proc/driver/nvidia-fs/stats ] || (sudo modprobe nvidia-fs 2>/dev/null && [ -f /proc/driver/nvidia-fs/stats ]); then
    log "NVIDIA-FS driver: loaded"
    if probe_gpu_direct; then
        log "GPU Direct Storage probe: PASS — testing both paths"
        XFER_MODES=(0 2)
        XFER_NAMES=("gpu_direct" "cpu_gpu")
    else
        log "GPU Direct Storage probe: FAIL (driver loaded but cuFile not functional on GB10)"
        log "Testing CPU->GPU path only."
        XFER_MODES=(2)
        XFER_NAMES=("cpu_gpu")
    fi
else
    log "WARNING: NVIDIA-FS driver not available."
    log "Testing CPU->GPU path only."
    XFER_MODES=(2)
    XFER_NAMES=("cpu_gpu")
fi

# System info
log ""
log "NVMe device:"
lsblk -d -o NAME,SIZE,MODEL,ROTA | grep -v loop | tee -a "$LOG_FILE"
log ""
log "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null)"
log "Test file location: $TEST_FILE ($(df -h /tmp | tail -1 | awk '{print $1, $2}'))"

# ============================================================================
# CSV header
# ============================================================================
echo "xfer_mode,operation,block_size,threads,rep,throughput_gibs,latency_ms,gpu_temp_c,gpu_power_w" > "$RESULTS_CSV"

# ============================================================================
# Create test file
# ============================================================================
log ""
log "Creating test file ($FILE_SIZE)..."
if [ ! -f "$TEST_FILE" ]; then
    sudo dd if=/dev/urandom of="$TEST_FILE" bs=1M count=1024 status=progress 2>&1 | tail -1 | tee -a "$LOG_FILE"
fi
log "Test file ready: $TEST_FILE ($(du -h "$TEST_FILE" | awk '{print $1}'))"

# ============================================================================
# Run benchmarks
# ============================================================================
TOTAL_TESTS=$((${#XFER_MODES[@]} * ${#OPERATIONS[@]} * ${#BLOCK_SIZES[@]} * ${#THREAD_COUNTS[@]} * REPS))
TEST_NUM=0

for xfer_idx in "${!XFER_MODES[@]}"; do
    xfer="${XFER_MODES[$xfer_idx]}"
    xfer_name="${XFER_NAMES[$xfer_idx]}"

    log ""
    log "============================================"
    log "TRANSFER MODE: $xfer_name (x=$xfer)"
    log "============================================"

    for op in "${OPERATIONS[@]}"; do
        # Map operation to gdsio -I flag
        local_io_flag=$([[ "$op" == "read" ]] && echo "0" || echo "1")

        for bs in "${BLOCK_SIZES[@]}"; do
            log ""
            log "--- $xfer_name | $op $bs ---"

            for threads in "${THREAD_COUNTS[@]}"; do
                for rep in $(seq 1 $REPS); do
                    TEST_NUM=$((TEST_NUM + 1))
                    log "  [$TEST_NUM/$TOTAL_TESTS] $xfer_name $op $bs threads=$threads rep=$rep"

                    # Run gdsio
                    local_output=$(sudo "$GDSIO" -f "$TEST_FILE" -d 0 -w "$threads" -s "${FILE_SIZE}" -i "${bs}" -x "$xfer" -I "$local_io_flag" 2>&1) || true

                    # Parse throughput (GiB/s) and latency (ms) from output
                    throughput=$(echo "$local_output" | grep -oP '[\d.]+\s*GiB/s' | grep -oP '[\d.]+' | head -1)
                    latency=$(echo "$local_output" | grep -ioP 'avg_latency:\s*[\d.]+' | grep -oP '[\d.]+' | head -1)

                    # Fallback: try MiB/s and convert
                    if [ -z "${throughput:-}" ]; then
                        throughput_mib=$(echo "$local_output" | grep -oP '[\d.]+\s*MiB/s' | grep -oP '[\d.]+' | head -1)
                        if [ -n "${throughput_mib:-}" ]; then
                            throughput=$(python3 -c "print(round($throughput_mib / 1024, 4))")
                        fi
                    fi

                    [ -z "${throughput:-}" ] && throughput="0"
                    [ -z "${latency:-}" ] && latency="0"

                    gpu=$(gpu_stats)
                    gpu_temp=$(echo "$gpu" | cut -d',' -f1)
                    gpu_power=$(echo "$gpu" | cut -d',' -f2)

                    log "    => ${throughput} GiB/s | ${latency}ms latency | GPU: ${gpu_temp}C"

                    echo "$xfer_name,$op,$bs,$threads,$rep,$throughput,$latency,$gpu_temp,$gpu_power" >> "$RESULTS_CSV"
                done
            done
        done
    done
done

# ============================================================================
# Cleanup
# ============================================================================
log ""
log "Cleaning up test file..."
sudo rm -f "$TEST_FILE"

# ============================================================================
# Summary
# ============================================================================
echo "" | tee -a "$LOG_FILE"
log "============================================"
log "BENCHMARK COMPLETE"
log "Results: $RESULTS_CSV"
log "============================================"

echo "" | tee -a "$LOG_FILE"
log "PEAK RESULTS:"
for xfer_idx in "${!XFER_MODES[@]}"; do
    xfer_name="${XFER_NAMES[$xfer_idx]}"
    for op in "${OPERATIONS[@]}"; do
        for bs in "${BLOCK_SIZES[@]}"; do
            peak=$(awk -F',' -v xn="$xfer_name" -v op="$op" -v bs="$bs" '$1==xn && $2==op && $3==bs {if($6+0>max) max=$6+0} END{printf "%.2f", max}' "$RESULTS_CSV")
            log "  $xfer_name $op $bs: ${peak} GiB/s peak"
        done
    done
done

echo "" | tee -a "$LOG_FILE"
log "Done."
