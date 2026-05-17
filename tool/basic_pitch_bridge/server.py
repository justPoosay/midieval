from __future__ import annotations

import tempfile
from pathlib import Path

import librosa
import numpy as np
import soundfile as sf
from basic_pitch.inference import predict
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import Response

app = FastAPI(title="MIDieval Basic Pitch Bridge", version="1.0.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/audio-to-midi")
async def audio_to_midi(
    audio_file: UploadFile = File(...),
    audio_filename: str = Form("input.wav"),
    purify_audio: bool = Form(True),
) -> Response:
    suffix = Path(audio_filename).suffix or ".wav"
    with tempfile.TemporaryDirectory(prefix="midieval_bp_") as temp_dir:
        wav_path = Path(temp_dir) / f"input{suffix}"
        source_for_inference = wav_path
        purified_path = Path(temp_dir) / "purified.wav"
        midi_path = Path(temp_dir) / "output.mid"

        wav_path.write_bytes(await audio_file.read())

        if purify_audio:
            try:
                _purify_voice_to_f0_track(wav_path, purified_path)
                source_for_inference = purified_path
            except Exception as exc:
                # We degrade gracefully to original audio if purification fails.
                print(f"[basic-pitch-bridge] purify_audio failed, fallback to raw: {exc}")

        try:
            _, midi_data, _ = predict(str(source_for_inference))
            _stabilize_midi_notes(midi_data)
        except Exception as exc:
            raise HTTPException(status_code=500, detail=f"Basic Pitch failed: {exc}")

        try:
            midi_data.write(str(midi_path))
            midi_bytes = midi_path.read_bytes()
        except Exception as exc:
            raise HTTPException(
                status_code=500,
                detail=f"Could not serialize MIDI output: {exc}",
            )

    return Response(content=midi_bytes, media_type="audio/midi")


def _purify_voice_to_f0_track(input_path: Path, output_path: Path) -> None:
    y, sr = librosa.load(str(input_path), sr=None, mono=True)
    if y.size == 0:
        raise ValueError("empty input waveform")

    # Mild denoise / normalize before F0 extraction.
    y = librosa.util.normalize(y)

    frame_length = 4096
    hop_length = 256
    f0, voiced_flag, _ = librosa.pyin(
        y,
        fmin=librosa.note_to_hz("F1"),
        fmax=librosa.note_to_hz("C6"),
        sr=sr,
        frame_length=frame_length,
        hop_length=hop_length,
    )

    if f0 is None:
        raise ValueError("pyin returned no F0")

    frame_times = librosa.frames_to_time(
        np.arange(len(f0)),
        sr=sr,
        hop_length=hop_length,
    )
    sample_times = np.arange(len(y)) / sr

    voiced = np.isfinite(f0)
    if voiced_flag is not None:
        voiced = voiced & voiced_flag.astype(bool)
    if voiced.sum() < 4:
        raise ValueError("too few voiced frames")

    voiced_f0 = f0[voiced]
    voiced_t = frame_times[voiced]
    interpolated_f0 = np.interp(sample_times, voiced_t, voiced_f0)

    # Estimate global detune (in semitones) and compensate before snapping.
    voiced_midi = librosa.hz_to_midi(voiced_f0)
    nearest = np.round(voiced_midi)
    semitone_offsets = voiced_midi - nearest
    detune = float(np.median(semitone_offsets)) if semitone_offsets.size else 0.0
    corrected_midi = librosa.hz_to_midi(interpolated_f0) - detune
    snapped_midi = np.round(corrected_midi)
    snapped_f0 = librosa.midi_to_hz(snapped_midi)

    # Gate to voiced regions to avoid hallucinations in silence.
    voiced_env = np.interp(
        sample_times,
        frame_times,
        voiced.astype(np.float32),
        left=0.0,
        right=0.0,
    )
    # Smooth gate to avoid clicks.
    win = np.hanning(129)
    win /= win.sum()
    voiced_env = np.convolve(voiced_env, win, mode="same")
    voiced_env = np.clip(voiced_env, 0.0, 1.0)

    # Monophonic resynthesis: strong fundamental + tiny second harmonic.
    phase = 2 * np.pi * np.cumsum(snapped_f0) / sr
    purified = (
        np.sin(phase) * 0.92 +
        np.sin(2.0 * phase) * 0.08
    ) * voiced_env
    purified = librosa.util.normalize(purified).astype(np.float32)

    sf.write(str(output_path), purified, sr, subtype="PCM_16")


def _stabilize_midi_notes(midi_data: object) -> None:
    """Merge pitch wobble fragments into stable monophonic notes."""
    instruments = getattr(midi_data, "instruments", None)
    if instruments is None:
        return
    for instrument in instruments:
        notes = sorted(getattr(instrument, "notes", []), key=lambda n: n.start)
        if not notes:
            continue

        # Pass 1: remove tiny fragments.
        cleaned = [n for n in notes if (n.end - n.start) >= 0.04]
        if not cleaned:
            cleaned = notes

        # Pass 2: merge adjacent near-unison wobble into stable notes.
        merged: list = []
        for note in cleaned:
            if not merged:
                merged.append(note)
                continue

            prev = merged[-1]
            gap = note.start - prev.end
            pitch_diff = abs(note.pitch - prev.pitch)
            note_dur = note.end - note.start
            prev_dur = prev.end - prev.start

            if gap <= 0.08 and pitch_diff == 0 and note_dur <= 0.12:
                prev.end = max(prev.end, note.end)
                prev.velocity = max(prev.velocity, note.velocity)
                continue

            if gap <= 0.12 and pitch_diff == 0:
                prev.end = max(prev.end, note.end)
                prev.velocity = max(prev.velocity, note.velocity)
                continue

            if gap <= 0.06 and pitch_diff == 0 and note_dur <= 0.08 and prev_dur >= 0.06:
                prev.end = max(prev.end, note.end)
                continue

            merged.append(note)

        # Pass 3: absorb micro-notes between same surrounding pitch.
        stabilized: list = []
        for idx, note in enumerate(merged):
            if idx == 0 or idx == len(merged) - 1:
                stabilized.append(note)
                continue

            prev = stabilized[-1]
            nxt = merged[idx + 1]
            note_dur = note.end - note.start
            if note_dur <= 0.08 and prev.pitch == nxt.pitch and note.pitch == prev.pitch:
                prev.end = max(prev.end, nxt.end)
                continue

            stabilized.append(note)

        # Pass 4: remove ultra-short connector blips between two stronger notes.
        final_notes: list = []
        for idx, note in enumerate(stabilized):
            if idx == 0 or idx == len(stabilized) - 1:
                final_notes.append(note)
                continue

            prev = final_notes[-1]
            nxt = stabilized[idx + 1]
            note_dur = note.end - note.start
            prev_dur = prev.end - prev.start
            next_dur = nxt.end - nxt.start
            gap_prev = note.start - prev.end
            gap_next = nxt.start - note.end
            d_prev = abs(note.pitch - prev.pitch)
            d_next = abs(nxt.pitch - note.pitch)
            d_outer = abs(nxt.pitch - prev.pitch)

            is_short_blip = note_dur <= 0.10
            tightly_connected = gap_prev <= 0.10 and gap_next <= 0.10
            neighbors_stronger = prev_dur >= 0.14 and next_dur >= 0.14
            local_connector_shape = d_prev <= 2 and d_next <= 2 and d_outer >= 4

            if is_short_blip and tightly_connected and neighbors_stronger and local_connector_shape:
                prev.end = max(prev.end, note.end)
                continue

            final_notes.append(note)

        # Pass 5: suppress micro-notes (<=90ms) unless likely intentional.
        filtered: list = []
        for idx, note in enumerate(final_notes):
            dur = note.end - note.start
            if dur > 0.09:
                filtered.append(note)
                continue

            prev = filtered[-1] if filtered else None
            nxt = final_notes[idx + 1] if idx + 1 < len(final_notes) else None

            prev_gap = (note.start - prev.end) if prev is not None else 999.0
            next_gap = (nxt.start - note.end) if nxt is not None else 999.0
            same_as_prev = prev is not None and note.pitch == prev.pitch
            same_as_next = nxt is not None and note.pitch == nxt.pitch
            neighbor_motion = (
                abs(note.pitch - prev.pitch) if prev is not None else 99
            ) + (abs(nxt.pitch - note.pitch) if nxt is not None else 99)
            strong_velocity = getattr(note, "velocity", 0) >= 95

            isolated_onset = prev_gap >= 0.11 or next_gap >= 0.11
            repeated_pitch_anchor = same_as_prev or same_as_next
            melodic_anchor = neighbor_motion >= 5 and prev_gap >= 0.06 and next_gap >= 0.06

            if repeated_pitch_anchor or isolated_onset or melodic_anchor or strong_velocity:
                filtered.append(note)
                continue
            # else: drop unanchored micro blip

        instrument.notes = filtered if filtered else final_notes
