# Benchmark: Serving Engine Comparison

Same model (Qwen2.5-7B) tested on three different serving engines on the Gigabyte Grace Blackwell Desktop AI (ATOM).

## Hardware

- GPU: NVIDIA GB10 (Blackwell, SM 12.1)
- Memory: 128GB unified (120GB usable, shared CPU/GPU)
- CUDA: 13.0, Driver 580.142

## Engines Tested

| Engine | Version | Runtime | Notes |
|--------|---------|---------|-------|
| Ollama | 0.20.5 | Native systemd | Flash attention, q8_0 KV cache, 20 threads |
| llama.cpp | Native binary | Direct llama-bench, CUDA backend | Tested separately |
| vLLM | nvcr.io/nvidia/vllm:26.01-py3 | Docker container | **FAILED** — SM 12.1 not supported |

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
| Ollama | 43.94 | 43.89 | 43.85 | **43.89** |
| llama.cpp | 42.56 | -- | -- | **42.56** |
| vLLM (Docker) | -- | -- | -- | **FAILED** |

### Additional Metrics

| Engine | TTFT | GPU Temp | Notes |
|--------|-----:|---------:|-------|
| Ollama | 24-33ms | 61-65C | Consistent, low latency |
| llama.cpp | N/A | 64C | Prompt processing: 3,334 tok/s (PP512) |
| vLLM (Docker) | N/A | N/A | Failed to start — SM 12.1 unsupported in this image |

## Key Findings

1. **Ollama and llama.cpp are nearly identical speed (~43 tok/s).** This is expected — Ollama uses llama.cpp as its inference backend. The marginal difference is Ollama's API overhead.

2. **vLLM failed entirely.** The `nvcr.io/nvidia/vllm:26.01-py3` Docker image does not support the GB10's SM 12.1 architecture. The container started but never became ready within the 300s timeout. Unlike the GX10 (which used a community-compiled Docker image), no compatible vLLM build was available for this test.

3. **llama.cpp prompt processing is extremely fast at 3,334 tok/s** (PP512). This measures how quickly the engine can process input context — critical for long-context applications.

4. **GPU runs warmer than the GX10.** The Gigabyte variant reaches 61-65C during Ollama inference vs 53-55C on the ASUS GX10.

## Recommendation

- **Single user / local development:** Use Ollama. Simplest, fastest, built-in model management.
- **Maximum control / custom integration:** Use llama.cpp directly. Same speed as Ollama with no API overhead.
- **Multi-user production:** Wait for a vLLM build supporting SM 12.1 on aarch64, or use the community Docker image tested on the GX10.

## Date

13 April 2026

## Created by

Pendakwah Teknologi
