# Benchmark #12: Thermal Stress Test

Monitors CPU/GPU/NVMe temperatures under sustained AI workloads across three phases, matching the [StorageReview Gigabyte AI TOP ATOM review](https://www.storagereview.com/review/gigabyte-ai-top-atom-review) methodology.

## Status: Pending

## Hardware

- GPU: NVIDIA GB10 (Blackwell, SM 12.1)
- CPU: 20 ARM cores (Cortex-X925 + A725)
- Memory: 120GB unified (shared CPU/GPU)
- Storage: 3.7TB NVMe SSD

## Test Phases (10 minutes each)

| Phase | Workload | What it stresses |
|-------|----------|-----------------|
| Idle | No load (60s baseline) | Baseline temperatures |
| Prefill Heavy | ISL=2048, OSL=1 | GPU compute |
| Equal | ISL=512, OSL=512 | Balanced GPU + memory |
| Decode Heavy | ISL=1, OSL=2048 | Memory bandwidth |

## Monitoring

- GPU: temperature, power draw, utilization (nvidia-smi, 1s interval)
- CPU: temperature (thermal zones)
- NVMe: temperature (smartctl / hwmon)
- 4 concurrent vLLM requests to maintain sustained load
- 60s cooldown between phases

## StorageReview Reference Results

| Component | Peak Temp | Idle Temp |
|-----------|----------:|----------:|
| CPU | 90C | 38.7C |
| GPU | 81C | 37C |
| NVMe | 59.8C | 37.8C |
| GPU Power | 75.54W max | — |

## Total Duration

~45 minutes (60s idle + 3x 10min phases + 3x 60s cooldowns + 120s final cool)

## Usage

```bash
./run.sh
```

## Date

Created: 16 April 2026

## Created by

Pendakwah Teknologi
