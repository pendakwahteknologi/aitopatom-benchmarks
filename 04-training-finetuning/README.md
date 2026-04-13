# Fine-Tuning Benchmark for Gigabyte Grace Blackwell Desktop AI (ATOM)

Compares LLM fine-tuning methods on real hardware. Trains **LoRA**, **QLoRA**, and **Full Fine-Tune** using the same model, dataset, and hyperparameters.

Built and tested on the **Gigabyte Grace Blackwell Desktop AI (ATOM)** — an ARM-based desktop powered by the **NVIDIA GB10** (Blackwell architecture) with **128 GB unified memory**.

---

## Results at a Glance

All three fine-tuning methods trained **Qwen2.5-7B-Instruct** for 5 steps (dry run) on the Databricks Dolly 15k dataset.

### Training Performance

| Metric | LoRA | QLoRA | Full Fine-Tune |
|--------|-----:|------:|---------------:|
| **Total Time** | 2m 25s | 4m 59s | 2m 44s |
| **Avg Step Time** | 28.6s | 59.8s | 32.7s |
| **Peak GPU Memory** | 83.3 GB | 12.8 GB | 90.9 GB |
| **Final Loss** | 1.83 | 1.88 | 1.57 |
| **Tokens/sec** | 156 | 75 | 137 |

## Key Findings

### LoRA: Fastest Training
- **2m 25s total** — fastest of all methods
- 156 tok/s throughput, 28.6s per step
- Uses 83.3 GB memory (fits comfortably in 128 GB unified pool)
- Good balance of speed and quality

### QLoRA: Lowest Memory
- Only **12.8 GB peak memory** — 7x less than Full FT
- Trade-off: 2x slower (59.8s/step) and highest loss (1.88)
- Essential for memory-constrained environments, but the GB10's 128 GB makes this less critical

### Full Fine-Tune: Best Quality
- **Lowest loss at 1.57** — trains all parameters
- Uses **90.9 GB** of the 128 GB unified memory pool
- Only possible because of GB10's shared CPU+GPU memory architecture
- Most consumer GPUs cannot run full fine-tuning of 7B models

## Output

- `results/all_runs_summary.csv` — summary of all runs
- `results/atom_*/` — individual run directories with metrics

## Date

13 April 2026

## Created by

Pendakwah Teknologi
