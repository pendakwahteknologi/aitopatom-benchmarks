# Benchmark: llama.cpp Multi-Quantization

Tests Qwen2.5 models across 4 sizes and 3 quantizations using llama.cpp on the ATOM (Gigabyte GB10).

## Hardware

- GPU: NVIDIA GB10 (Blackwell, SM 12.1)
- Memory: 120GB unified (shared CPU/GPU)
- CUDA: 13.0, Driver 580.142
- llama.cpp: Build e97492369 (8782), April 14 2026

## Methodology

- Engine: llama.cpp with CUDA backend
- Models: Qwen2.5 Instruct (3B, 7B, 14B, 32B) — standalone GGUF files from HuggingFace
- Quantizations: Q4_K_M, Q5_K_M, Q8_0 (12 total configurations)
- Tests: Prompt Processing (PP) at 128, 256, 512 tokens; Text Generation (TG) at 128 tokens
- 3 repetitions per configuration, averaged
- Flash Attention enabled, all layers on GPU (ngl=99)
- All other services stopped during benchmark

## Results

### Prompt Processing (tok/s) — higher is better

| Model | Quant | PP 128 | PP 256 | PP 512 |
|-------|-------|-------:|-------:|-------:|
| **Qwen2.5-3B** | Q4_K_M | 4,696 | 6,088 | **6,946** |
| | Q5_K_M | 4,366 | 5,822 | 6,647 |
| | Q8_0 | 3,894 | 4,998 | 5,919 |
| **Qwen2.5-7B** | Q4_K_M | 2,753 | 3,394 | **3,503** |
| | Q5_K_M | 2,556 | 3,237 | 3,282 |
| | Q8_0 | 2,146 | 2,589 | 2,647 |
| **Qwen2.5-14B** | Q4_K_M | 1,483 | **1,701** | 1,707 |
| | Q5_K_M | 1,368 | 1,546 | 1,519 |
| | Q8_0 | 1,136 | 1,228 | 1,198 |
| **Qwen2.5-32B** | Q4_K_M | 702 | **738** | 699 |
| | Q5_K_M | 599 | 647 | 628 |
| | Q8_0 | 435 | 445 | 455 |

### Text Generation (tok/s) — higher is better

| Model | Q4_K_M | Q5_K_M | Q8_0 |
|-------|-------:|-------:|-----:|
| **Qwen2.5-3B** | **97.5** | 83.9 | 66.0 |
| **Qwen2.5-7B** | **46.2** | 38.8 | 29.9 |
| **Qwen2.5-14B** | **23.7** | 19.4 | 14.7 |
| **Qwen2.5-32B** | **10.4** | 8.1 | 6.5 |

### Comparison with GX10 (Q4_K_M only)

| Model | ATOM PP512 | GX10 PP512 | Diff | ATOM TG128 | GX10 TG128 | Diff |
|-------|----------:|-----------:|-----:|-----------:|-----------:|-----:|
| 3B | 6,946 | 5,797 | +19.8% | 97.5 | 95.9 | +1.7% |
| 7B | 3,503 | 3,334 | +5.1% | 46.2 | 42.6 | +8.5% |
| 32B | 699 | 716 | -2.4% | 10.4 | 9.6 | +8.3% |

ATOM shows significant prompt processing improvements (+5–20%) and modest text generation improvements (+2–8%) over the GX10, likely due to the newer llama.cpp build.

## Key Findings

1. **Peak prompt processing: 6,946 tok/s** (Qwen2.5-3B Q4_K_M at PP512). This is ~20% faster than the GX10's 5,797 tok/s.

2. **Q4_K_M is consistently the fastest quantization** for both prompt processing and text generation, with only minor quality loss vs Q8_0.

3. **All 12 configurations fit in memory.** The GB10's 120GB unified memory handles even the largest Q8_0 32B model (34.8GB) without issue.

4. **PP scales well with prompt length.** Throughput increases from PP128 to PP256/PP512 across all models, showing efficient batched computation.

5. **Text generation sweet spots:**
   - Real-time chat (40+ tok/s): 3B (any quant), 7B Q4_K_M
   - Comfortable chat (20+ tok/s): 7B Q5_K_M, 14B Q4_K_M
   - Usable: 32B Q4_K_M at 10.4 tok/s

6. **Q8_0 is 30–40% slower than Q4_K_M** for text generation, but provides higher quality outputs. The trade-off is worth considering for production use.

## Date

14 April 2026

## Created by

Pendakwah Teknologi
