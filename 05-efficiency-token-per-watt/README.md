# Benchmark #05: Token per Watt Efficiency

Measures energy efficiency of LLM inference on the ATOM (Gigabyte GB10), calculating tokens generated per watt across model sizes and quantizations.

## Hardware

- GPU: NVIDIA GB10 (Blackwell, SM 12.1)
- Memory: 120GB unified (shared CPU/GPU)
- CUDA: 13.0, Driver 580.142
- llama.cpp: Build e97492369 (8782), April 14 2026

## Method

- Engine: llama.cpp with CUDA, Flash Attention enabled, all layers on GPU
- Models: Qwen2.5 Instruct (3B, 7B, 14B, 32B) — standalone GGUF files
- Quantizations: Q4_K_M, Q5_K_M, Q8_0
- 512 tokens generated per run, 5 repetitions
- GPU power sampled via nvidia-smi every 0.5s during generation
- Electricity cost: RM 0.55/kWh (Malaysian tariff)

## Results

| Model | Quant | tok/s | Avg Power | tok/W | RM/1M tokens |
|-------|-------|------:|----------:|------:|-------------:|
| 3B | Q4_K_M | 98.5 | 45.6W | **2.16** | RM 0.07 |
| 3B | Q5_K_M | 84.1 | 47.5W | 1.77 | RM 0.09 |
| 3B | Q8_0 | 65.8 | 40.7W | 1.62 | RM 0.09 |
| 7B | Q4_K_M | 45.4 | 50.9W | 0.89 | RM 0.17 |
| 7B | Q5_K_M | 38.5 | 50.2W | 0.77 | RM 0.20 |
| 7B | Q8_0 | 29.6 | 42.4W | 0.70 | RM 0.22 |
| 14B | Q4_K_M | 23.5 | 51.8W | 0.45 | RM 0.34 |
| 14B | Q5_K_M | 19.2 | 49.9W | 0.38 | RM 0.40 |
| 14B | Q8_0 | 14.6 | 42.1W | 0.35 | RM 0.44 |
| 32B | Q4_K_M | 10.3 | 51.9W | 0.20 | RM 0.77 |
| 32B | Q5_K_M | 8.3 | 47.5W | 0.17 | RM 0.87 |
| 32B | Q8_0 | 6.2 | 40.0W | 0.16 | RM 0.98 |

### Comparison with GX10

| Model | Quant | ATOM tok/W | GX10 tok/W | Diff |
|-------|-------|----------:|-----------:|-----:|
| 3B | Q4_K_M | 2.16 | 2.62 | -17.6% |
| 3B | Q5_K_M | 1.77 | 2.20 | -19.5% |
| 3B | Q8_0 | 1.62 | 1.96 | -17.3% |
| 7B | Q4_K_M | 0.89 | 1.11 | -19.8% |
| 7B | Q5_K_M | 0.77 | 0.94 | -18.1% |
| 7B | Q8_0 | 0.70 | 0.86 | -18.6% |
| 14B | Q4_K_M | 0.45 | 0.55 | -18.2% |
| 14B | Q5_K_M | 0.38 | 0.40 | -5.0% |
| 14B | Q8_0 | 0.35 | 0.44 | -20.5% |
| 32B | Q4_K_M | 0.20 | 0.23 | -13.0% |
| 32B | Q5_K_M | 0.17 | 0.20 | -15.0% |
| 32B | Q8_0 | 0.16 | 0.15 | +6.7% |

**The ATOM is less power-efficient than the GX10 despite being faster.** The ATOM generates tokens ~2-8% faster but draws ~25-35% more power (40-52W vs 33-44W on GX10). This is likely due to differences in power management firmware between the Gigabyte and NVIDIA OEM implementations.

## Key Findings

1. **Best efficiency: 3B Q4_K_M at 2.16 tok/W** (RM 0.07 per 1M tokens). Below the GX10's 2.62 tok/W due to higher power draw.

2. **ATOM draws more power than the GX10.** Average power is 40-52W on ATOM vs 33-44W on GX10 for the same workloads. The NVIDIA OEM firmware appears more aggressive with power gating.

3. **Smaller quants are more power-efficient** despite similar wattage — Q4_K_M consistently beats Q5_K_M and Q8_0 on tok/W.

4. **Running 1M tokens costs less than RM 1.00** across all configurations. The 3B Q4_K_M costs just RM 0.07 per million tokens — extremely cheap inference.

5. **32B Q8_0 is the one config where ATOM beats GX10 on efficiency** (+6.7%), because ATOM's higher power draw is offset by a proportionally larger speed gain for this specific configuration.

## Output

- `results/token_per_watt_20260414_202931.csv` — raw data
- `results/token_per_watt_20260414_202931.json` — structured data
- `results/token_per_watt_20260414_202931.log` — run log

## Date

14 April 2026

## Created by

Pendakwah Teknologi
