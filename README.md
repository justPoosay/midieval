# MIDieval

MIDieval is a Flutter prototype for capturing short hummed melodies and turning them into clean MIDI sketches. The app lets a user record a WAV voice clip, save it to Supabase, play it back, and generate a downloadable `.midi` file that can be opened in a DAW or notation tool.

The core experiment is the audio-to-MIDI engine in `lib/midi_engine.dart`. It decodes mono WAV audio, estimates pitch, smooths unstable humming artifacts, groups the detected melody into notes, and quantizes simple phrases onto a musical grid.

## Problem This Project Tackles

Human voice is not a single pure tone. Even when we hear one clear sung note, the waveform contains many additional harmonic components (overtones), some of which are subtle and not consciously perceived. For audio-to-MIDI conversion, this is a major challenge: a computer can accidentally lock onto one of those harmonics instead of the true fundamental pitch.

That mismatch causes common errors such as:

- wrong detected note (for example octave or semitone mistakes),
- unstable note switching ("wobbling" notes),
- broken rhythm segmentation because pitch tracking is inconsistent.

MIDieval focuses on reducing that problem by stabilizing pitch detection, filtering unstable fragments, and snapping the result into usable musical notes for MIDI output.

### How The Current Algorithm Works (Short Technical Overview)

The current pipeline is hybrid: Flutter handles recording/workflow/editing, and a local Basic Pitch bridge handles transcription.

1. Audio capture and prep:
   - The app records mono WAV (44.1 kHz), which avoids extra codec artifacts from compressed formats.
   - Leading silence and low-energy noise are reduced so pitch detection starts on voiced material.

2. Harmonic handling before transcription:
   - In the bridge, an optional purification step estimates voice F0 (fundamental) over time.
   - The signal is then resynthesized into a cleaner monophonic track, which suppresses many distracting overtones.
   - This is the key defense against “wrong harmonic chosen as note”.

3. Basic Pitch transcription:
   - The purified (or fallback raw) signal is sent to Basic Pitch, which predicts note events (pitch + start/end).
   - Output is serialized to MIDI.

4. Post-transcription stabilization:
   - Very short note fragments are removed.
   - Neighboring near-unison/semitone wobble fragments are merged.
   - Micro-notes between stable notes are absorbed when they look like vocal modulation artifacts.

5. Musical normalization in app:
   - Notes are aligned to start at tick 0 (remove leading timing offset).
   - Optional constraints can be applied: locked tempo, locked meter, key/scale snapping.
   - Quantization in the editor uses meter-aware snapping and rhythm regularization for cleaner note lengths.

In practice, this means the app does not rely on a single raw pitch read. It combines purification, ML transcription, and rule-based post-processing to reduce harmonic confusion and produce usable MIDI sketches.

![MIDieval algorithm pipeline](readme/algorithm_pipeline.svg)

## Features

- Email authentication through Supabase.
- WAV recording at 44.1 kHz.
- Cloud storage for recorded audio clips and generated MIDI files.
- Playback for saved sketches.
- One-tap conversion from hummed audio to MIDI.
- Pitch cleanup for vibrato, scoops, harmonics, and short unstable fragments.
- Phrase quantization for simple monophonic lines such as a C major scale.

## Prototype Versions

The GIF below shows four prototype versions of the MIDI generator, from early rough detection to the cleaner current version.

![MIDieval prototype versions](readme/prototypes.gif)

## Tech Stack

- Flutter and Dart
- Supabase Auth, Database, and Storage
- `record` for audio capture
- `audioplayers` for playback
- `wav` for WAV decoding
- Custom MIDI generation in Dart

## Running The Project

Install dependencies:

```bash
flutter pub get
```

Run the app:

```bash
flutter run
```

Run the MIDI engine tests:

```bash
flutter test test/midi_engine_test.dart
```

## Notes

The converter currently expects WAV/PCM input. Older recordings stored as compressed formats need to be recorded again with the current WAV recording flow before conversion.

## TorchCrepe Route

A clean TorchCrepe integration route (local bridge service) is documented here:

- [readme/torchcrepe_bridge.md](readme/torchcrepe_bridge.md)

## Basic Pitch Route

Audio-to-MIDI conversion currently uses a Basic Pitch bridge service:

- [readme/basic_pitch.md](readme/basic_pitch.md)
