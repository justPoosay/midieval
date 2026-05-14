# Basic Pitch Integration

This project now converts audio to MIDI through Spotify Basic Pitch, replacing the previous in-app heuristic converter path.

Repository:
- https://github.com/spotify/basic-pitch

## Bridge Service

Location:
- `tool/basic_pitch_bridge/server.py`

Endpoint used by app:
- `POST http://127.0.0.1:8090/audio-to-midi`

Default behavior:
- `purify_audio=true` (pitch-guided preprocessing via `librosa.pyin` + monophonic resynthesis before Basic Pitch)
- MIDI post-processing note stabilizer:
  - removes micro-fragments
  - merges semitone wobble blips
  - fuses near-unison notes with tiny gaps

## Run

From repo root:

```bash
pip install -r tool/basic_pitch_bridge/requirements.txt
uvicorn tool.basic_pitch_bridge.server:app --host 127.0.0.1 --port 8090
```

Health:

```bash
curl http://127.0.0.1:8090/health
```

## App Behavior

`convertAudioToMidi` in `lib/main.dart` sends WAV bytes to the bridge and uploads returned MIDI bytes to Supabase.
