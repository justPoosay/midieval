from __future__ import annotations

import io
from typing import Any

import numpy as np
import soundfile as sf
import torch
import torchcrepe
from fastapi import FastAPI, File, Form, HTTPException, UploadFile

app = FastAPI(title="MIDieval TorchCrepe Bridge", version="1.0.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/pitch-track")
async def pitch_track(
    audio_file: UploadFile = File(...),
    sample_rate: int = Form(44100),
    hop_length: int = Form(512),
    fmin: float = Form(50.0),
    fmax: float = Form(1200.0),
    model: str = Form("full"),
) -> dict[str, Any]:
    try:
        raw = await audio_file.read()
        waveform, sr = sf.read(io.BytesIO(raw), dtype="float32", always_2d=False)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Invalid audio file: {exc}")

    if waveform is None or len(waveform) == 0:
        raise HTTPException(status_code=400, detail="Empty waveform")

    if waveform.ndim > 1:
        waveform = waveform.mean(axis=1)

    if sr != sample_rate:
        # Keep bridge deterministic for now: caller should send expected sample-rate.
        raise HTTPException(
            status_code=400,
            detail=f"Unexpected sample-rate {sr}, expected {sample_rate}",
        )

    device = "cuda" if torch.cuda.is_available() else "cpu"
    audio = torch.from_numpy(waveform).to(device)[None]
    pitch_hz, periodicity = torchcrepe.predict(
        audio,
        sample_rate,
        hop_length,
        fmin,
        fmax,
        model,
        batch_size=1024,
        device=device,
        return_periodicity=True,
    )

    pitch_hz = pitch_hz.squeeze(0).detach().cpu().numpy()
    periodicity = periodicity.squeeze(0).detach().cpu().numpy()

    voiced = periodicity > 0.30
    pitch_hz = np.where(voiced, pitch_hz, 0.0)

    return {
        "sample_rate": sample_rate,
        "hop_length": hop_length,
        "frequencies_hz": pitch_hz.tolist(),
        "periodicity": periodicity.tolist(),
    }
