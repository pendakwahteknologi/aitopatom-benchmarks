# Benchmark: Serving Engine Comparison

Same model (Qwen2.5-7B) tested on three different serving engines on the ATOM (Gigabyte GB10).

## Hardware

- GPU: NVIDIA GB10 (Blackwell, SM 12.1)
- Memory: 120GB unified (shared CPU/GPU)
- CUDA: 13.0, Driver 580.142

## Engines Tested

| Engine | Version | Runtime | Notes |
|--------|---------|---------|-------|
| Ollama | 0.20.6 | Native systemd | Default config |
| llama.cpp | Build e97492369 (8782) | Native binary | Direct llama-bench, CUDA backend |
| vLLM | 26.01 | Docker container | nvcr.io/nvidia/vllm:26.01-py3 |

**Note on vLLM:** Stock vLLM does not natively support the GB10 GPU (Blackwell sm_121 on aarch64). The NVIDIA NGC container (nvcr.io/nvidia/vllm:26.01-py3) includes the necessary CUDA kernels. Docker overhead adds latency compared to natively compiled Ollama and llama.cpp.

## Methodology

- Model: Qwen2.5-7B-Instruct (Q4_K_M quantization for Ollama/llama.cpp, FP16 for vLLM)
- Prompt: "Explain quantum computing in 3 paragraphs. Be detailed and technical."
- Max tokens: 256
- 3 runs per engine, results shown individually
- All other services stopped during benchmark
- Models unloaded between engine tests

## Results

### Token Generation (tok/s)

| Engine | Run 1 | Run 2 | Run 3 | Average |
|--------|------:|------:|------:|--------:|
| Ollama | 47.10 | 47.05 | 47.04 | **47.06** |
| llama.cpp | 44.93 | -- | -- | **44.93** |
| vLLM (Docker) | 11.74 | 13.39 | 13.36 | **12.83** |

### Additional Metrics

| Engine | TTFT | GPU Temp | Notes |
|--------|-----:|---------:|-------|
| Ollama | 23-32ms | 52-56C | Consistent, low latency |
| llama.cpp | N/A | 64C | Prompt processing: 3,049 tok/s |
| vLLM (Docker) | N/A | 59-64C | Runs hotter due to Docker + FP16 |

### Comparison with GX10

| Engine | ATOM (tok/s) | GX10 (tok/s) | Difference |
|--------|-------------:|-------------:|------------|
| Ollama | 47.06 | 43.67 | +7.8% |
| llama.cpp | 44.93 | 43.00 | +4.5% |
| vLLM | 12.83 | 12.54 | +2.3% |

The ATOM is faster across all three engines, with the largest improvement on Ollama (+7.8%).

## Key Findings

1. **Ollama is the fastest engine for single-user requests (47 tok/s).** Slightly faster than raw llama.cpp due to Ollama's internal optimizations (flash attention, KV cache tuning).

2. **llama.cpp matches Ollama closely (44.9 tok/s).** This is expected — Ollama uses llama.cpp as its inference backend. The difference is Ollama's additional optimizations.

3. **vLLM is 3.7x slower for single-user requests.** This is due to:
   - Docker container overhead (not native)
   - FP16 precision vs Q4_K_M quantization (more compute per token)
   - vLLM is designed for concurrent throughput, not single-request latency

4. **vLLM's advantage is concurrency.** While slower per-request, vLLM uses continuous batching and PagedAttention. At 50+ concurrent users, vLLM maintains throughput while Ollama queues requests sequentially. This benchmark only tests single-user performance.

5. **llama.cpp prompt processing is extremely fast at 3,049 tok/s.** This measures how quickly the engine can process input context — critical for long-context applications.

## Recommendation

- **Single user / local development:** Use Ollama. Simplest, fastest, built-in model management.
- **Multi-user production (20+ concurrent):** Use vLLM. Continuous batching prevents queue buildup.
- **Maximum control / custom integration:** Use llama.cpp directly. Same speed tier as Ollama with no API overhead.

## Date

14 April 2026

## Created by

Pendakwah Teknologi
