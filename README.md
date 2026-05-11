# MIDieval

MIDieval is a Flutter prototype for capturing short hummed melodies and turning them into clean MIDI sketches. The app lets a user record a WAV voice clip, save it to Supabase, play it back, and generate a downloadable `.midi` file that can be opened in a DAW or notation tool.

The core experiment is the audio-to-MIDI engine in `lib/midi_engine.dart`. It decodes mono WAV audio, estimates pitch, smooths unstable humming artifacts, groups the detected melody into notes, and quantizes simple phrases onto a musical grid.

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
