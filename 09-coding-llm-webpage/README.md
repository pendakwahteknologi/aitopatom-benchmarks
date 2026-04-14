# Benchmark #09: Coding LLM Webpage Generation

Can the ATOM run coding LLMs locally and produce real, working code? This benchmark tests 3 top coding models generating the same complex interactive webpage from a single prompt, matching the GX10 model list.

## Hardware

- GPU: NVIDIA GB10 (Blackwell, SM 12.1)
- Memory: 120GB unified (shared CPU/GPU)
- CUDA: 13.0, Driver 580.142
- Serving engine: Ollama 0.20.6

## Models Tested

| Model | Parameters | VRAM (Q4_K_M) | Architecture |
|-------|----------:|-------:|-------------|
| Qwen3-Coder | 30B | 18 GB | Dense transformer |
| Devstral | 24B | 14 GB | Mistral-based |
| DeepCoder | 14B | 9 GB | DeepSeek-based |

All models run via Ollama with Q4_K_M quantization.

## The Prompt

A single prompt asking each model to generate a complete interactive 3D solar system visualization in pure HTML/CSS/JS — no external libraries.

See [`prompt.txt`](prompt.txt) for the full prompt.

## Results

| Model | Run 1 | Run 2 | Run 3 | Avg tok/s | Avg Tokens |
|-------|------:|------:|------:|----------:|-----------:|
| **Qwen3-Coder:30b** | 72.1 | 70.5 | 142.6* | **71.3** | 4,139 |
| DeepCoder:14b | 22.9 | 23.1 | 22.9 | **22.9** | 3,066 |
| Devstral:24b | 14.1 | 14.1 | 14.1 | **14.1** | 3,283 |

<sub>* Qwen3-Coder run 3 generated only 2 tokens (empty response), excluded from average. Average based on runs 1-2.</sub>

### Comparison with Previous ATOM Run

| Model | New (tok/s) | Previous (tok/s) |
|-------|----------:|-----------------:|
| Qwen3-Coder:30b | 71.3 | 71.1 |
| DeepCoder:14b | 22.9 | 22.4 |
| Devstral:24b | 14.1 | 14.0 |

Results are consistent with the previous run. All models produce valid, complete HTML.

## Key Findings

1. **Qwen3-Coder is 5x faster** than Devstral and **3x faster** than DeepCoder at 71.3 tok/s.

2. **All models produced valid HTML** with DOCTYPE, closing tags, canvas elements, and script blocks.

3. **Qwen3-Coder generates the most code** (~4,100 tokens) with the most features in ~60 seconds.

4. **DeepCoder is the best value** at 22.9 tok/s with only 9GB VRAM — good balance of speed and model size.

5. **Devstral is the slowest** at 14.1 tok/s but produces detailed output (3,283 tokens avg).

## Methodology

- Same prompt for all models (no system prompt variation)
- 3 runs per model
- Temperature: 0.7
- Context window: 16,384 tokens
- Max output: 16,384 tokens
- Models pre-loaded before timing
- Other models unloaded between test sets for clean GPU state

## Output

- `outputs/*.html` — generated webpages (3 per model)
- `results/*.json` — per-run metrics (timing, token counts, validity)
- `prompt.txt` — the exact prompt used

## Date

15 April 2026

## Created by

Pendakwah Teknologi
