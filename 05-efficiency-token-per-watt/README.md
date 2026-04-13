# Benchmark #05: Token per Watt Efficiency

Measures energy efficiency of LLM inference on the ATOM, calculating tokens generated per watt across model sizes.

## Method

- Engine: Ollama
- Models: Qwen2.5-7B, Qwen3-8B, Qwen2.5-Coder-32B, Qwen2.5-72B
- 512 tokens generated per run
- GPU power sampled via nvidia-smi during generation
- Electricity cost: RM 0.55/kWh (Malaysian tariff)

## Results

| Model | tok/s | Avg Power | tok/W | RM/1M tokens |
|-------|------:|----------:|------:|-------------:|
| Qwen2.5-7B | 39.1 | 44.6W | **0.879** | RM 0.17 |
| Qwen3-8B | 36.3 | 48.5W | 0.748 | RM 0.21 |
| Qwen2.5-Coder-32B | 9.1 | 47.7W | 0.191 | RM 0.80 |
| Qwen2.5-72B | 3.9 | 36.8W | 0.105 | RM 1.46 |

## Key Findings

- Best efficiency: **Qwen2.5-7B at 0.879 tok/W**
- Qwen3-8B draws more power (48.5W) than Qwen2.5-7B (44.6W) despite similar model size
- The 72B model is surprisingly power-efficient per watt (36.8W) — it's just slow
- Running a million tokens on the most efficient config costs about RM 0.17 in electricity

## Output

- `results/token-per-watt-results.csv` — raw data
- `results/token-per-watt-log.txt` — run log
