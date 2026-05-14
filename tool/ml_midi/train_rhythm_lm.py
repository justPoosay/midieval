from __future__ import annotations

import argparse
import json
import math
from collections import Counter
from pathlib import Path

import librosa
import mido
import numpy as np

TICKS_PER_QUARTER = 480
CANDIDATE_TICKS = [120, 240, 360, 480, 720, 960]


def nearest_tick(value: int) -> int:
    return min(CANDIDATE_TICKS, key=lambda x: abs(x - value))


def tempo_from_meta(mid: mido.MidiFile) -> int:
    # Default MIDI tempo is 500000 microseconds per beat = 120 BPM.
    tempos = []
    for track in mid.tracks:
        for msg in track:
            if msg.type == "set_tempo":
                tempos.append(int(msg.tempo))
    if not tempos:
        return 500000
    return int(np.median(np.array(tempos, dtype=np.int64)))


def note_on_ticks_from_midi(mid: mido.MidiFile) -> list[int]:
    merged = mido.merge_tracks(mid.tracks)
    absolute_tick = 0
    note_on_ticks = []
    for msg in merged:
        absolute_tick += msg.time
        if msg.type == "note_on" and msg.velocity > 0:
            note_on_ticks.append(int(absolute_tick))
    return note_on_ticks


def iois_from_midi(mid: mido.MidiFile) -> list[int]:
    note_on_ticks = note_on_ticks_from_midi(mid)
    if len(note_on_ticks) < 2:
        return []

    midi_ticks_per_beat = mid.ticks_per_beat if mid.ticks_per_beat > 0 else 480
    tempo_us_per_beat = tempo_from_meta(mid)
    beat_seconds = tempo_us_per_beat / 1_000_000.0
    target_beat_seconds = beat_seconds
    iois = []
    for i in range(1, len(note_on_ticks)):
        dt_ticks = note_on_ticks[i] - note_on_ticks[i - 1]
        dt_beats = dt_ticks / midi_ticks_per_beat
        ticks = int(round((dt_beats * target_beat_seconds / beat_seconds) * TICKS_PER_QUARTER))
        if ticks <= 0:
            continue
        iois.append(nearest_tick(ticks))
    return iois


def validate_pair(audio_path: Path, midi_path: Path) -> bool:
    try:
        # We run a light check to ensure the clip is readable and voiced.
        y, sr = librosa.load(audio_path, sr=22050, mono=True)
        if y.size < 2048:
            return False
        f0, _, _ = librosa.pyin(
            y,
            sr=sr,
            fmin=librosa.note_to_hz("C2"),
            fmax=librosa.note_to_hz("C7"),
            frame_length=2048,
            hop_length=256,
        )
        voiced_ratio = np.isfinite(f0).mean()
        if voiced_ratio < 0.12:
            return False
        mid = mido.MidiFile(str(midi_path))
        return len(iois_from_midi(mid)) > 0
    except Exception:
        return False


def gather_pairs(dataset_dir: Path) -> list[tuple[Path, Path]]:
    pairs = []
    for midi_path in dataset_dir.rglob("*.mid*"):
        audio_path = midi_path.with_suffix(".wav")
        if audio_path.exists():
            pairs.append((audio_path, midi_path))
    return pairs


def build_model(pairs: list[tuple[Path, Path]]) -> dict:
    unigram_counts = Counter()
    bigram_counts = Counter()
    prev_counts = Counter()

    total_sequences = 0
    for audio_path, midi_path in pairs:
        if not validate_pair(audio_path, midi_path):
            continue
        mid = mido.MidiFile(str(midi_path))
        seq = iois_from_midi(mid)
        if not seq:
            continue
        total_sequences += 1
        for token in seq:
            unigram_counts[token] += 1
        for a, b in zip(seq[:-1], seq[1:]):
            bigram_counts[(a, b)] += 1
            prev_counts[a] += 1

    if total_sequences == 0:
        raise RuntimeError("No valid dataset pairs found.")

    # Additive smoothing.
    alpha = 0.5
    vocab = CANDIDATE_TICKS
    uni_total = sum(unigram_counts.values()) + alpha * len(vocab)
    unigram_penalty = {}
    for token in vocab:
        p = (unigram_counts[token] + alpha) / uni_total
        unigram_penalty[str(token)] = -math.log(p)

    bigram_penalty = {}
    for prev in vocab:
        denom = prev_counts[prev] + alpha * len(vocab)
        for nxt in vocab:
            p = (bigram_counts[(prev, nxt)] + alpha) / denom
            bigram_penalty[f"{prev}->{nxt}"] = -math.log(p)

    return {
        "unigram_penalty": unigram_penalty,
        "bigram_penalty": bigram_penalty,
        "meta": {
            "model_type": "rhythm_bigram_lm",
            "ticks_per_quarter": TICKS_PER_QUARTER,
            "candidate_ticks": CANDIDATE_TICKS,
            "num_pairs": len(pairs),
            "num_sequences": total_sequences,
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", required=True, help="Folder with .wav/.mid pairs")
    parser.add_argument(
        "--output",
        required=True,
        help="Output JSON path, e.g. assets/models/rhythm_lm.json",
    )
    args = parser.parse_args()

    dataset_dir = Path(args.dataset)
    output_path = Path(args.output)
    pairs = gather_pairs(dataset_dir)
    if not pairs:
        raise RuntimeError(f"No wav/mid pairs found in {dataset_dir}")

    model = build_model(pairs)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(model, indent=2), encoding="utf-8")
    print(f"Saved model to: {output_path}")
    print(f"Pairs scanned: {len(pairs)}")
    print(f"Valid sequences: {model['meta']['num_sequences']}")


if __name__ == "__main__":
    main()
