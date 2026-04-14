# Benchmark #07: Image & Video Generation Speed

Tests how fast the ATOM (Gigabyte GB10) can generate images using ComfyUI with Z-Image-Turbo.

## Hardware

- GPU: NVIDIA GB10 (Blackwell, SM 12.1)
- Memory: 120GB unified (shared CPU/GPU)
- CUDA: 13.0, Driver 580.142
- ComfyUI: v0.18.1

## Model

- **Z-Image-Turbo** (12B, bf16) — text-to-image
- Sampler: `res_multistep`, 4 steps (and 8 steps for comparison)
- Text encoder: Qwen 3 4B

## Methodology

- 5 configurations: 512x512, 768x768, 1024x1024, 1280x1280 (4 steps) + 1024x1024 (8 steps)
- 3 repetitions per configuration
- GPU temperature and power monitored
- ComfyUI API via WebSocket for precise timing

## Results

| Resolution | Steps | Time | Images/min | GPU Temp | Power |
|------------|------:|-----:|-----------:|---------:|------:|
| 512x512 | 4 | **1.21s** | **49.7** | 58C | 76W |
| 768x768 | 4 | 2.46s | 24.4 | 56C | 75W |
| 1024x1024 | 4 | 4.22s | 14.2 | 60C | 65W |
| 1280x1280 | 4 | 6.66s | 9.0 | 63C | 54W |
| 1024x1024 | 8 | 7.64s | 7.9 | 67C | 64W |

### Comparison with Previous Run

| Resolution | New | Previous | Diff |
|------------|----:|---------:|-----:|
| 512x512 | 1.21s | 5.0s | **4.1x faster** |
| 768x768 | 2.46s | 7.1s | **2.9x faster** |
| 1024x1024 (4step) | 4.22s | 14.5s | **3.4x faster** |
| 1280x1280 | 6.66s | 16.0s | **2.4x faster** |

The new run is **2.4-4.1x faster** than the previous run, likely due to cleaner GPU state (all other services stopped) and updated ComfyUI.

## Video Generation — Skipped

WAN 2.2 T2V 14B (fp8 + LightX2V LoRA) was attempted but **timed out after 3+ hours**. The VAE decoding step is heavily CPU-bound on ARM architecture, making video generation impractically slow for automated benchmarking on this hardware.

## Key Findings

1. **512x512 at 49.7 images/min** — nearly 1 image per second. Fast enough for real-time iteration.

2. **1024x1024 in 4.22 seconds** — high quality output in under 5 seconds. Previous run was 14.5s.

3. **4 steps vs 8 steps at 1024x1024:** 4.22s vs 7.64s (1.8x slower). 8 steps produces marginally better quality but double the cost.

4. **GPU runs hot during image gen** (56-67C, 54-76W) — significantly more power than inference benchmarks.

5. **Video generation is not viable** on the GB10 in its current state. The ARM CPU bottleneck in VAE decoding makes WAN 2.2 T2V impractical.

## Output

- `results_20260415_030509.csv` — raw per-run data (15 rows)
- `summary_20260415_030509.csv` — aggregated statistics (5 configs)
- `metadata_20260415_030509.json` — system and model info
- `report_20260415_030508.html` — interactive HTML report

## Date

15 April 2026

## Created by

Pendakwah Teknologi
