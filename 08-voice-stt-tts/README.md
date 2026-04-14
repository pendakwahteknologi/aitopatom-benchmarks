# Benchmark #08: Voice STT & TTS Performance

Measures speech-to-text and text-to-speech performance on the ATOM (Gigabyte GB10).

## Hardware

- GPU: NVIDIA GB10 (Blackwell, SM 12.1)
- CPU: 20 ARM cores (Cortex-X925 + A725)
- Memory: 120GB unified (shared CPU/GPU)
- CUDA: 13.0, Driver 580.142

## Models

| Task | Model | Engine | Precision |
|------|-------|--------|-----------|
| STT | Whisper large-v3 | faster-whisper (CTranslate2) | CPU int8 |
| TTS | MMS-TTS Malay (facebook/mms-tts-zlm) | HuggingFace VITS | GPU |

## Methodology

### TTS (Text-to-Speech)
- 4 text lengths: short (25 chars), medium (~234 chars), long (~558 chars), very long (~1199 chars)
- 3 repetitions each
- Metrics: synthesis time, audio duration, chars/sec

### STT (Speech-to-Text)
- 6 audio durations: 3.6s, 10.9s, 21.8s, 43.5s, 87.1s, 217.7s
- Test audio generated via TTS (Malay sentences)
- 3 repetitions each
- Metrics: transcription time, speed (x realtime)

## Results

### TTS Performance

| Text Length | Chars | Time | Audio Duration | Chars/sec |
|-------------|------:|-----:|--------------:|----------:|
| Short | 25 | 0.44s | 2.2s | 148 |
| Medium | 234 | 0.14s | 16.1s | 1,650 |
| Long | 558 | 0.28s | 37.4s | 1,988 |
| Very Long | 1,199 | 0.60s | 78.0s | **2,012** |

### STT Performance (Whisper large-v3)

| Audio Duration | Transcription Time | Speed | RTF |
|---------------:|-------------------:|------:|----:|
| 3.6s | 6.6s | 0.55x | 1.82 |
| 10.9s | 8.5s | 1.29x | 0.78 |
| 21.8s | 12.7s | 1.72x | 0.59 |
| 43.5s | 25.1s | 1.74x | 0.58 |
| 87.1s | 60.0s | 1.45x | 0.69 |
| 217.7s | 118.1s | **1.84x** | 0.54 |

## Key Findings

1. **TTS peak: 2,012 chars/sec** on long text. Synthesis is near-instant — 1,199 characters generate 78 seconds of audio in just 0.6 seconds.

2. **STT peak: 1.84x realtime** on 300s audio. Whisper large-v3 transcribes a 3.6-minute audio file in under 2 minutes.

3. **STT scales well with audio length.** Short clips (3.6s) have high overhead, but longer files (60s+) consistently hit 1.5-1.8x realtime.

4. **TTS is GPU-accelerated, STT is CPU-only.** The MMS-TTS model runs on GPU (18-39W), while faster-whisper uses CPU int8 quantization (12-18W).

## Output

- `results_20260415_000728.csv` — raw per-run data
- `summary_20260415_000728.csv` — aggregated statistics
- `metadata_20260415_000728.json` — system and model info
- `log_20260415_000728.txt` — full console log
- `samples/` — generated TTS and STT audio files

## Date

15 April 2026

## Created by

Pendakwah Teknologi
