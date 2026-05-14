# TorchCrepe Clean Integration Route

This project now includes a clean external integration route for TorchCrepe via a local bridge service.

Repository used:
- https://github.com/maxrmorrison/torchcrepe

## Why a Bridge

Flutter cannot run PyTorch models directly on Android/iOS app runtime.
The clean route is:

1. Run TorchCrepe in a dedicated Python process.
2. Expose pitch-track inference over HTTP.
3. Consume results from the app/inference layer.

## Bridge Service

Location:
- `tool/torchcrepe_bridge/server.py`

Endpoint:
- `POST /pitch-track`

Returns:
- `frequencies_hz` (frame-wise F0)
- `periodicity` (voicing confidence)

## Run Locally

From repo root:

```bash
pip install -r tool/torchcrepe_bridge/requirements.txt
uvicorn tool.torchcrepe_bridge.server:app --host 127.0.0.1 --port 8089
```

Health check:

```bash
curl http://127.0.0.1:8089/health
```

## Next Wiring Step

The app currently uses internal/on-device pitch detection.
To fully switch, add a pitch-provider adapter in Dart that:

1. Sends WAV bytes to `/pitch-track`.
2. Converts returned frame F0 into note frames.
3. Reuses existing note-grouping + MIDI quantization logic.

That keeps rhythm/midi logic stable while replacing only pitch estimation.
