from __future__ import annotations

import argparse
import json
import math
from collections import Counter
from pathlib import Path

import librosa
import numpy as np
import pretty_midi

TICKS_PER_QUARTER = 480
CANDIDATE_TICKS = [120, 240, 360, 480, 720, 960]


def nearest_tick(value: int) -> int:
    return min(CANDIDATE_TICKS, key=lambda x: abs(x - value))


def bpm_from_midi(pm: pretty_midi.PrettyMIDI) -> float:
    tempo_times, tempo_values = pm.get_tempo_changes()
    if len(tempo_values) == 0:
        return 120.0
    return float(np.median(tempo_values))


def iois_from_midi(pm: pretty_midi.PrettyMIDI) -> list[int]:
    notes = []
    for instrument in pm.instruments:
        if instrument.is_drum:
            continue
        notes.extend(instrument.notes)
    if len(notes) < 2:
        return []
    notes.sort(key=lambda n: n.start)
    bpm = bpm_from_midi(pm)
    beat_seconds = 60.0 / bpm
    iois = []
    for i in range(1, len(notes)):
        dt = notes[i].start - notes[i - 1].start
        ticks = int(round((dt / beat_seconds) * TICKS_PER_QUARTER))
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
        pm = pretty_midi.PrettyMIDI(str(midi_path))
        return len(iois_from_midi(pm)) > 0
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
        pm = pretty_midi.PrettyMIDI(str(midi_path))
        seq = iois_from_midi(pm)
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
