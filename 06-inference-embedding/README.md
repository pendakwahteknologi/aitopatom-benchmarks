# Benchmark #06: Embedding Throughput

Tests how fast the ATOM (Gigabyte GB10) can embed documents for RAG knowledge base building, measuring GPU vs CPU performance across varying workload sizes and batch configurations.

## Hardware

- GPU: NVIDIA GB10 (Blackwell, SM 12.1)
- CPU: 20 ARM cores (Cortex-X925 + A725)
- Memory: 120GB unified (shared CPU/GPU)
- CUDA: 13.0, Driver 580.142

## Model

- **mesolitica/mistral-embedding-191m-8k-contrastive** (191M params, 768-dim)
- Language: Bahasa Melayu
- Max sequence length: 8192

## Methodology

- Devices: CUDA (GPU) and CPU
- Chunk counts: 100, 500, 1000, 5000 (CPU capped at 1000)
- Batch sizes: 32, 64, 128, 256 (CPU capped at 64)
- 3 repetitions per configuration, averaged
- 5 progressive warmup rounds before measurement
- GPU power and temperature monitored during runs

## Results

### GPU Performance (chunks/s)

| Chunks | Batch 32 | Batch 64 | Batch 128 | Batch 256 |
|-------:|---------:|---------:|----------:|----------:|
| 100 | 2,404 | 2,209 | 2,604 | 2,450 |
| 500 | 2,443 | 3,268 | 2,941 | 3,301 |
| 1,000 | 2,625 | 3,261 | **3,417** | 3,364 |
| 5,000 | 2,610 | 3,293 | 3,404 | 3,409 |

### CPU Performance (chunks/s)

| Chunks | Batch 32 | Batch 64 |
|-------:|---------:|---------:|
| 100 | 72.4 | 92.3 |
| 500 | 72.6 | 98.0 |
| 1,000 | 74.5 | **99.4** |

### Peak Performance

| Device | Peak chunks/s | Config | Power |
|--------|-------------:|--------|------:|
| **GPU** | **3,417** | 1000 chunks, batch 128 | 50W |
| **CPU** | **99.4** | 1000 chunks, batch 64 | 13W |
| **GPU speedup** | **34.4x** | over CPU | |

## Key Findings

1. **GPU is 34.4x faster than CPU** for embedding workloads. GPU essential for building large RAG knowledge bases.

2. **Peak throughput: 3,417 chunks/s on GPU** (1000 chunks, batch 128). At this rate, embedding 1 million document chunks takes under 5 minutes.

3. **Batch size 64-128 is optimal.** Below 64, the GPU isn't fully utilized. Above 128, diminishing returns.

4. **Throughput scales well with chunk count.** Stable from 100 to 5000 chunks.

5. **GPU power: 20-58W** depending on batch size. CPU stays at ~13W but 34x slower.

## Output

- `results_20260414_210549.csv` — raw per-run results (66 rows)
- `summary_20260414_210549.csv` — aggregated statistics per config
- `metadata_20260414_210549.json` — system info & parameters
- `report_20260414_210549.html` — interactive HTML report

## Date

14 April 2026

## Created by

Pendakwah Teknologi
