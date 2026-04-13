# Benchmark: Can It Run X? (Model Size Scaling)

Tests every available model from 8B to 72B on the Gigabyte Grace Blackwell Desktop AI (ATOM).

## Hardware

- GPU: NVIDIA GB10 (Blackwell, SM 12.1)
- Memory: 128GB unified (120GB usable, shared CPU/GPU)
- CUDA: 13.0, Driver 580.142
- Serving engine: Ollama 0.20.5

## Methodology

- Each model is pulled, warmed up (1 short inference to load into GPU), then benchmarked
- Standard prompt: "Explain quantum computing in 3 paragraphs. Be detailed and technical."
- Max tokens: 256
- Models unloaded between tests to ensure clean GPU state
- All services stopped during benchmark (clean GPU, no contention)
- Ollama optimized: flash attention, q8_0 KV cache, 20 threads, GPU overhead 0

## Results

| Model | Size | tok/s | TTFT | Total Time | GPU Temp |
|-------|------|------:|-----:|-----------:|---------:|
| Qwen3 | 8B | 40.68 | 93.9ms | 6.5s | 65C |
| Qwen3.5 | 9B | 34.61 | 53.7ms | 7.7s | 70C |
| DeepSeek-Coder-V2 | 16B | 0 | -- | -- | 56C |
| Devstral | 14B | 13.83 | 115.1ms | 18.9s | 69C |
| Mistral-Small3.2 | 15B | 13.82 | 105.4ms | 18.9s | 72C |
| Qwen2.5-Coder | 32B | 10.02 | 133.7ms | 26.0s | 74C |
| Qwen2.5 | 72B | 4.29 | 314.2ms | 61.5s | 74C |

## Key Findings

1. **72B model runs on this machine.** Most consumer GPUs with 24GB or even 48GB VRAM cannot load a 72B model at all. The ATOM's 128GB unified memory handles it comfortably.

2. **DeepSeek-Coder-V2 16B failed.** The model timed out without generating any tokens — likely an incompatibility with the Ollama version or model format.

3. **GPU runs warm but within limits.** Temperatures range from 56-74C across all model sizes. The Gigabyte variant runs warmer than the ASUS GX10 counterpart.

4. **Sweet spots by use case:**
   - Real-time chat (40+ tok/s): Qwen3 8B
   - Comfortable chat (30+ tok/s): Qwen3.5 9B
   - Usable generation: 14-15B models at ~14 tok/s
   - Batch/offline workloads: 72B at 4.3 tok/s

5. **Unified memory advantage.** No model loading failures at any size (except DeepSeek format issue). The 72B model requires ~47GB which fits entirely in the unified memory pool.

## Date

13 April 2026

## Created by

Pendakwah Teknologi
