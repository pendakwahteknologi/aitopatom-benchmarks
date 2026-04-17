# Benchmark #12: Thermal Stress Test

Monitors CPU/GPU/NVMe temperatures under sustained AI workloads across three phases, matching the [StorageReview Gigabyte AI TOP ATOM review](https://www.storagereview.com/review/gigabyte-ai-top-atom-review) methodology.

## Status: Done

## Results Summary

| Phase | GPU Peak | GPU Avg | Power Peak | Power Avg | CPU Peak | NVMe Peak |
|-------|--------:|-------:|----------:|---------:|--------:|---------:|
| Idle | 44C | 42.9C | 3.7W | 3.1W | 46C | 40C |
| **Prefill Heavy** | **74C** | 69.6C | **53.9W** | 44.2W | **80C** | **52C** |
| Equal ISL/OSL | 68C | 65.9C | 37.4W | 36.8W | 75C | 51C |
| Decode Heavy | 69C | 66.0C | 39.8W | 38.1W | 74C | 50C |

### vs StorageReview Reference

| Component | ATOM Peak | StorageReview Peak | Notes |
|-----------|----------:|-------------------:|-------|
| GPU | **74C** | 81C | ATOM runs 7C cooler |
| CPU | **80C** | 90C | ATOM runs 10C cooler |
| NVMe | **52C** | 59.8C | ATOM runs 8C cooler |
| GPU Power | **53.9W** | 75.5W | ATOM draws 29% less power |

> ATOM runs significantly cooler and draws less power than StorageReview's reference. This is likely due to differences in workload intensity (7B model vs potentially larger) and testing environment. All temperatures remain well within safe operating limits.

### Key Findings

- **Prefill Heavy is the hottest phase** — GPU compute-intensive workload pushes GPU to 74C and CPU to 80C
- **Equal and Decode phases** run ~6C cooler on GPU (68-69C) with lower power draw (37-40W vs 54W)
- **Cooldown is effective** — GPU drops ~14C in 60 seconds after peak load
- **NVMe stays cool** — only 12C rise from idle (40C) to peak (52C)
- **No thermal throttling observed** — all components well below throttle limits
- GPU temperature stabilizes within 2-3 minutes of sustained load

## Hardware

- GPU: NVIDIA GB10 (Blackwell, SM 12.1)
- CPU: 20 ARM cores (Cortex-X925 + A725)
- Memory: 120GB unified (shared CPU/GPU)
- Storage: 3.7TB Samsung NVMe SSD

## Test Phases (10 minutes each)

| Phase | Workload | What it stresses |
|-------|----------|-----------------|
| Idle | No load (60s baseline) | Baseline temperatures |
| Prefill Heavy | ISL=2048, OSL=1 | GPU compute |
| Equal | ISL=512, OSL=512 | Balanced GPU + memory |
| Decode Heavy | ISL=1, OSL=2048 | Memory bandwidth |

## Monitoring

- Model: Qwen2.5-7B-Instruct via vLLM (Docker)
- GPU: temperature, power draw, utilization (nvidia-smi, 1s interval)
- CPU: temperature (thermal zones)
- NVMe: temperature (smartctl / hwmon)
- 4 concurrent vLLM requests to maintain sustained load
- 60s cooldown between phases, 120s final cooldown
- 1,689 total temperature samples collected

## Usage

```bash
./run.sh
```

## Date

Completed: 17 April 2026

## Created by

Pendakwah Teknologi
