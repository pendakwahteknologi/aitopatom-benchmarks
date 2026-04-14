# Fine-Tuning Benchmark for Gigabyte Grace Blackwell Desktop AI (ATOM)

Compares LLM fine-tuning methods on real hardware. Trains **LoRA**, **QLoRA**, and **Full Fine-Tune** using the same model, dataset, and hyperparameters.

Built and tested on the **Gigabyte Grace Blackwell Desktop AI (ATOM)** — an ARM-based desktop powered by the **NVIDIA GB10** (Blackwell architecture) with **120 GB unified memory**.

---

## Status: Testing Ongoing

This benchmark is currently being re-run with parameters matching the [GX10 benchmark](https://github.com/pendakwahteknologi/gx10-benchmarks) for a fair comparison. Results will be updated once complete.

### Planned Configuration

- **Model:** Llama 3.1 8B (matching GX10)
- **Dataset:** Databricks Dolly 15k
- **Methods:** LoRA, QLoRA, Full Fine-Tune
- **Steps:** Full training run (not dry-run)

### GX10 Reference Results

| Mode | Time | Peak GPU | tok/s |
|------|------|----------|------:|
| LoRA | 4h 47m | 87.4 GB | 164 |
| Full FT | 5h 05m | 93.6 GB | 151 |
| QLoRA | 9h 13m | 12.4 GB | 83 |

---

## Methodology

- Engine: PyTorch + HuggingFace Transformers + PEFT
- Training modes: LoRA (rank 16), QLoRA (4-bit NF4), Full Fine-Tune
- Same hyperparameters across all methods for fair comparison
- GPU memory and power monitored throughout training
- Results evaluated on 80 curated questions

## Usage

```bash
./run_all.sh          # Run all three methods
./run_benchmark.sh    # Run with custom options
```

## Date

15 April 2026

## Created by

Pendakwah Teknologi
