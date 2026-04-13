# Benchmark #08: Voice STT & TTS Performance

Measures speech-to-text and text-to-speech performance on the ATOM.

## Models

| Task | Model | Engine | Precision |
|------|-------|--------|-----------|
| STT | Whisper large-v3 | faster-whisper (CTranslate2) | CPU int8 |
| TTS | MMS-TTS Malay (facebook/mms-tts-zlm) | HuggingFace VITS | GPU |

## Test Matrix

### TTS (Text-to-Speech)
- 4 text lengths: short (25 chars), medium (~234 chars), long (~558 chars), very long (~1199 chars)
- 3 repetitions each
- Metrics: synthesis time, audio duration, chars/sec, real-time factor

### STT (Speech-to-Text)
- 6 audio durations: 3.6s, 10.9s, 21.8s, 43.5s, 87.1s, 217.7s
- Test audio generated via TTS (Malay sentences)
- 3 repetitions each
- Metrics: transcription time, speed (x realtime), real-time factor

## Usage

```bash
./run.sh
```

## Output

- `results/voice-stt-tts-results.csv` — raw per-run data
- `results/voice-stt-tts-summary.csv` — aggregated statistics
- `results/voice-stt-tts-metadata.json` — system and model info
- `results/voice-stt-tts-log.txt` — full console log
- `results/voice-stt-tts-report.html` — visual HTML report
- `samples/` — generated TTS audio files
