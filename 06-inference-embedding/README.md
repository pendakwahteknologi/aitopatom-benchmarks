# Benchmark #06: Embedding Throughput

Tests how fast the ATOM can embed documents for RAG knowledge base building, measuring
GPU vs CPU performance across varying workload sizes and batch configurations.

## Hardware

- **GPU:** NVIDIA GB10 (Blackwell, SM 12.1)
- **CPU:** 20 ARM cores (Cortex-X925 + A725)
- **Memory:** 128GB unified (120GB usable, shared CPU/GPU)
- **CUDA:** 13.0, Driver 580.142
- **OS:** Ubuntu 24.04 aarch64

## Model

- **Mesolitica Mistral-Embedding 191M**
  - 768 embedding dimensions
  - 8K max sequence length
  - Optimized for Bahasa Melayu
  - Pre-normalized embeddings for cosine similarity

## Methodology

### Test Matrix

| Parameter | Values |
|-----------|--------|
| Devices | CUDA (GPU), CPU (ARM) |
| Chunk counts | 100, 500, 1000, 5000 |
| Batch sizes | 32, 64, 128, 256 |
| Repetitions | 3 per configuration |

### Metrics Collected

| Metric | Description |
|--------|-------------|
| chunks/sec | Throughput (primary metric) |
| time_s | Wall-clock time per run |
| gpu_temp_c | GPU temperature after each run |
| gpu_power_w | GPU power draw (watts) |

## Key Results

| Device | Batch Size | Chunks/s | Power |
|--------|----------:|---------:|------:|
| CPU | 64 | 103 | 14W |
| **GPU** | 32 | 2,620 | 49W |
| **GPU** | 128 | **3,365** | 58W |
| **GPU** | 256 | 3,252 | 59W |

GPU speedup: **32.7x** over CPU at optimal batch size.

> Batch 128 is the sweet spot — beyond that, throughput plateaus while power increases.

## Output Files

| File | Description |
|------|-------------|
| `results/embedding-throughput-results.csv` | Raw per-run measurements |
| `results/embedding-throughput-summary.csv` | Aggregated statistics per config |
| `results/embedding-throughput-metadata.json` | Full system info, test parameters |
| `results/embedding-throughput-log.txt` | Complete console output |
| `results/embedding-throughput-report.html` | Interactive HTML report |

## Date

13 April 2026

## Created by

Pendakwah Teknologi
