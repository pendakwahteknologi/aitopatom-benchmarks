# Benchmark #10: vLLM Online Serving (Multi-Batch)

Tests production-level serving throughput across batch sizes 1-64 using vLLM, matching the [StorageReview Gigabyte AI TOP ATOM review](https://www.storagereview.com/review/gigabyte-ai-top-atom-review) methodology.

## Status: Pending (script ready, not yet run)

## Hardware

- GPU: NVIDIA GB10 (Blackwell, SM 12.1)
- Memory: 120GB unified (shared CPU/GPU)
- CUDA: 13.0, Driver 580.142
- vLLM: nvcr.io/nvidia/vllm:26.01-py3

## Models

| Model | Parameters | Type |
|-------|----------:|------|
| GPT-OSS-120B | 120B | Dense |
| GPT-OSS-20B | 20B | Dense |
| Qwen2.5-7B-Instruct | 7B | Dense |
| Llama-3.1-8B-Instruct | 8B | Dense |

## Workload Profiles

| Profile | Input Seq Len | Output Seq Len | Tests |
|---------|-------------:|---------------:|-------|
| Prefill Heavy | 2048 | 1 | GPU compute bound |
| Equal | 512 | 512 | Balanced |
| Decode Heavy | 1 | 2048 | Memory bandwidth bound |

## Methodology

- Batch sizes: 1, 2, 4, 8, 16, 32, 64
- 3 workload profiles x 7 batch sizes x 4 models = 84 test configurations
- Metrics: tokens/sec, average latency, GPU temp/power

## Usage

```bash
./run.sh
```

## Date

Created: 16 April 2026

## Created by

Pendakwah Teknologi
