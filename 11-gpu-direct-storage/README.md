# Benchmark #11: GPU Direct Storage (GDSIO)

Tests NVMe-to-GPU transfer speeds using NVIDIA GDSIO, matching the [StorageReview Gigabyte AI TOP ATOM review](https://www.storagereview.com/review/gigabyte-ai-top-atom-review) methodology.

## Status: Done

## Results Summary

| Test | Peak GiB/s | StorageReview Ref |
|------|----------:|------------------:|
| Read 1M | **10.73** | 11.60 |
| Write 1M | **8.19** | 12.23 |
| Read 16K | **7.83** | 6.84 |
| Write 16K | **9.06** | 6.54 |

> **Note:** GPU Direct Storage (GDS, x=0) is not functional on the GB10 desktop Blackwell — the nvidia-fs driver loads but `cuFile` buffer registration fails. All results use the **CPU->GPU (x=2)** transfer path. StorageReview results likely used GPU Direct on a server-class Blackwell, explaining the difference on 1M sequential reads/writes.

### Read Throughput by Thread Count

| Threads | 16K GiB/s | 1M GiB/s |
|--------:|----------:|---------:|
| 1 | 0.05 | 6.23 |
| 2 | 0.10 | 5.90 |
| 4 | 0.21 | 8.04 |
| 8 | 0.49 | 10.59 |
| 16 | 0.88 | **10.73** |
| 32 | 1.45 | 10.63 |
| 64 | 4.16 | 9.64 |
| 128 | **7.78** | 9.03 |

### Write Throughput by Thread Count

| Threads | 16K GiB/s | 1M GiB/s |
|--------:|----------:|---------:|
| 1 | 0.06 | 3.82 |
| 2 | 0.11 | 5.80 |
| 4 | 0.22 | 7.38 |
| 8 | 0.45 | 8.01 |
| 16 | 0.96 | 8.02 |
| 32 | 1.57 | 7.96 |
| 64 | 6.20 | 7.70 |
| 128 | **8.59** | 7.45 |

### Key Findings

- **1M reads peak at 16 threads** (10.73 GiB/s) — throughput saturates and slightly drops beyond 32 threads due to contention
- **16K reads scale linearly** with threads up to 128 (7.83 GiB/s) — small IO benefits from parallelism
- **1M writes peak at 8-16 threads** (8.19 GiB/s) — write throughput is ~24% lower than reads
- **16K writes at 128 threads** achieve 9.06 GiB/s — surprisingly competitive with 1M sequential
- Samsung MZALC4T0HBL1-00B07 (3.7TB) performs well for AI workloads

## Hardware

- GPU: NVIDIA GB10 (Blackwell, SM 12.1)
- Storage: 3.7TB Samsung NVMe SSD (MZALC4T0HBL1-00B07)
- CUDA: 13.0, Driver 580.142
- GDS Tools: gds-tools-13-0 (gdsio v1.12)

## Test Matrix

- Operations: Read, Write
- Block sizes: 16K, 1M
- Thread counts: 1, 2, 4, 8, 16, 32, 64, 128
- Repetitions: 3 per configuration
- Transfer mode: CPU->GPU (x=2)
- Data size: 1 GB test file (`/dev/urandom`)
- Total: 96 measurements

## Usage

```bash
./run.sh
```

## Date

Completed: 16 April 2026

## Created by

Pendakwah Teknologi
