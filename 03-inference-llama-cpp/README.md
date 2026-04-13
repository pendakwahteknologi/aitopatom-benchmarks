# Benchmark: llama.cpp Multi-Quantization

Tests Qwen models across sizes using Q4_K_M quantization (extracted from Ollama blobs) on the Gigabyte Grace Blackwell Desktop AI (ATOM).

## Hardware

- GPU: NVIDIA GB10 (Blackwell, SM 12.1)
- Memory: 128GB unified (120GB usable, shared CPU/GPU)
- CUDA: 13.0, Driver 580.142

## Methodology

- Engine: llama.cpp with CUDA backend
- Models: Qwen2.5-7B, Qwen3-8B, Qwen2.5-32B, Qwen2.5-72B
- Quantization: Q4_K_M (all extracted from Ollama model blobs)
- Tests: Prompt Processing (PP) at 128, 256, 512 tokens; Text Generation (TG) at 128 tokens
- All other services stopped during benchmark

## Results

| Model | Quant | PP128 | PP256 | PP512 | TG128 |
|-------|-------|------:|------:|------:|------:|
| **Qwen2.5-7B** | Q4_K_M | 2,557 | 3,224 | 3,334 | 42.6 |
| **Qwen3-8B** | Q4_K_M | 2,577 | 2,954 | 3,018 | 38.3 |
| **Qwen2.5-32B** | Q4_K_M | 683 | 723 | 716 | 9.6 |
| **Qwen2.5-72B** | Q4_K_M | 306 | 314 | 305 | 4.0 |

All values in tok/s.

## Key Findings

1. **Peak prompt processing: 3,334 tok/s** (Qwen2.5-7B at PP512). Context ingestion is very fast for the smaller models.

2. **Qwen2.5-7B slightly outperforms Qwen3-8B** in both PP and TG, likely due to architecture differences (Qwen3's additional features add overhead).

3. **72B model processes prompts at 305-314 tok/s** — usable for batch processing despite the large model size.

4. **PP512 is generally the fastest prompt size** for 7-8B models, but 32B and 72B models show no improvement beyond PP256.

## Output

- `results/benchmark_20260413_120412.csv` — raw benchmark data
- `results/benchmark_20260413_120412.log` — run log

## Date

13 April 2026

## Created by

Pendakwah Teknologi
