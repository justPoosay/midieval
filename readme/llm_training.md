# Locally Trained MIDI Language Model

This branch replaces fixed rhythm snapping with a trainable rhythm language model.
The app now tries a learned model first and falls back to rule-based quantization only if the model is missing.

## What Is Trained

- A local token language model over note-to-note timing intervals.
- Tokens are rhythmic values in MIDI ticks: `120, 240, 360, 480, 720, 960`.
- The trainer learns:
  - unigram penalties (`P(token)`)
  - bigram transition penalties (`P(next_token | prev_token)`)

The Dart converter uses beam search with these learned penalties to snap sung timing into stable musical note lengths.

## Dataset Format

Use pairs of files with the same base name:

- `*.wav` (your recorded voice/humming/singing)
- `*.mid` or `*.midi` (the target clean melody)

Example:

```text
dataset/
  take_001.wav
  take_001.mid
  take_002.wav
  take_002.mid
```

## Local Training Steps

1. Create and activate a Python virtual environment.
2. Install requirements:

```bash
pip install -r tool/ml_midi/requirements.txt
```

3. Train and export the model JSON:

```bash
python tool/ml_midi/train_rhythm_lm.py --dataset path/to/dataset --output assets/models/rhythm_lm.json
```

4. Rebuild or restart Flutter app:

```bash
flutter run
```

The app automatically loads `assets/models/rhythm_lm.json` at startup.

## Practical Training Advice

- Start with at least 100-300 short monophonic examples.
- Include both humming and "la la" singing examples.
- Keep target MIDI quantized cleanly in your DAW (quarter/eighth patterns).
- Cover multiple tempos to avoid overfitting to one BPM.
- Add simple scales/arpeggios and real melodic phrases.

## Current Scope

- Monophonic melody conversion.
- Rhythm snapping is now trainable.
- Pitch detection is still deterministic (YIN), then rhythm is learned/scored.

This setup is a strong baseline for local training and can be upgraded later to a neural seq2seq model (ONNX/TFLite) without changing the app flow.
