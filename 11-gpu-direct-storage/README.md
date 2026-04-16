# Benchmark #11: GPU Direct Storage (GDSIO)

Tests NVMe-to-GPU transfer speeds using NVIDIA GDSIO, matching the [StorageReview Gigabyte AI TOP ATOM review](https://www.storagereview.com/review/gigabyte-ai-top-atom-review) methodology.

## Status: Pending

## Hardware

- GPU: NVIDIA GB10 (Blackwell, SM 12.1)
- Storage: 3.7TB NVMe SSD
- CUDA: 13.0, Driver 580.142
- GDS Tools: gds-tools-13-0

## Test Matrix

| Operation | Block Size | Thread Counts |
|-----------|-----------|---------------|
| Read | 16K | 1, 2, 4, 8, 16, 32, 64, 128 |
| Read | 1M | 1, 2, 4, 8, 16, 32, 64, 128 |
| Write | 16K | 1, 2, 4, 8, 16, 32, 64, 128 |
| Write | 1M | 1, 2, 4, 8, 16, 32, 64, 128 |

- 4 configs x 8 thread counts x 3 reps = 96 measurements
- Metrics: throughput (GiB/s), latency (ms)

## StorageReview Reference Results

| Test | Peak Throughput |
|------|---------------:|
| Read 16K | 6.84 GiB/s |
| Read 1M | 11.60 GiB/s |
| Write 16K | 6.54 GiB/s |
| Write 1M | 12.23 GiB/s |

## Usage

```bash
sudo ./run.sh
```

## Date

Created: 16 April 2026

## Created by

Pendakwah Teknologi
