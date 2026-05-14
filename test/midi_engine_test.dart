import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:midieval/midi_engine.dart';
import 'package:wav/wav.dart';

void main() {
  test('converts a 440 Hz WAV tone into MIDI note A4', () {
    final wavBytes = _sineWav(frequency: 440, seconds: 1.0);

    final midiBytes = MidiEngine.generateMidiFromAudio(wavBytes);

    expect(String.fromCharCodes(midiBytes.sublist(0, 4)), 'MThd');
    expect(_noteOns(midiBytes), contains(69));
  });

  test('converts the synthetic C5-C6 sine scale into the expected notes', () {
    final wavBytes = MidiEngine.generateSineSequenceWav();

    final midiBytes = MidiEngine.generateMidiFromAudio(wavBytes);
    final events = _noteOnEvents(midiBytes);
    final noteDurations = _noteDurations(midiBytes);

    expect(_tempoBpm(midiBytes), 120);
    expect(events.map((event) => event.note), [72, 74, 76, 77, 79, 81, 83, 84]);
    expect(events.map((event) => event.tick), [
      0,
      480,
      960,
      1440,
      1920,
      2400,
      2880,
      3360,
    ]);
    expect(noteDurations, everyElement(480));
    expect(events.last.tick + noteDurations.last, 3840);
  });

  test('converts a hummed C4-C5 scale without vibrato fragments', () {
    final wavBytes = _hummedMajorScaleWav();

    final midiBytes = MidiEngine.generateMidiFromAudio(wavBytes);
    final events = _noteOnEvents(midiBytes);

    expect(events.map((event) => event.note), [60, 62, 64, 65, 67, 69, 71, 72]);
  });

  test('absorbs short chromatic scoops in a hummed C4-C5 scale', () {
    final wavBytes = _hummedMajorScaleWav(includeScoops: true);

    final midiBytes = MidiEngine.generateMidiFromAudio(wavBytes);
    final events = _noteOnEvents(midiBytes);

    expect(events.map((event) => event.note), [60, 62, 64, 65, 67, 69, 71, 72]);
  });

  test('bar-aligns an uneven hummed C4-C5 scale across two bars', () {
    final wavBytes = _hummedMajorScaleWav(unevenTiming: true);

    final midiBytes = MidiEngine.generateMidiFromAudio(wavBytes);
    final events = _noteOnEvents(midiBytes);
    final noteDurations = _noteDurations(midiBytes);

    expect(events.map((event) => event.note), [60, 62, 64, 65, 67, 69, 71, 72]);
    expect(events.map((event) => event.tick), [
      0,
      480,
      960,
      1440,
      1920,
      2400,
      2880,
      3360,
    ]);
    expect(noteDurations, everyElement(480));
    expect(events.last.tick + noteDurations.last, 3840);
  });

  test('snaps a steady sung phrase with leaps to quarter-note timing', () {
    final wavBytes = _steadySungPhraseWav();

    final midiBytes = MidiEngine.generateMidiFromAudio(wavBytes);
    final events = _noteOnEvents(midiBytes);
    final noteDurations = _noteDurations(midiBytes);

    expect(events.map((event) => event.note), [60, 64, 67, 72, 67, 64]);
    expect(events.map((event) => event.tick), [0, 480, 960, 1440, 1920, 2400]);
    expect(noteDurations.every((ticks) => ticks <= 480), isTrue);
  });

  test('preserves staccato spacing for steady eighth-note phrases', () {
    final wavBytes = _steadyStaccatoEighthPhraseWav();

    final midiBytes = MidiEngine.generateMidiFromAudio(wavBytes, tempoBpm: 120);
    final events = _noteOnEvents(midiBytes);
    final noteDurations = _noteDurations(midiBytes);

    expect(events.length, greaterThanOrEqualTo(7));
    expect(events.take(7).map((event) => event.note), [60, 62, 64, 65, 67, 69, 71]);
    expect(events.take(7).map((event) => event.tick), [0, 240, 480, 720, 960, 1200, 1440]);
    expect(noteDurations.isNotEmpty, isTrue);
  });

  test('keeps mixed-rhythm phrase without cutting the second half', () {
    final wavBytes = _mixedRhythmPhraseWav();

    final midiBytes = MidiEngine.generateMidiFromAudio(wavBytes, tempoBpm: 150);
    final events = _noteOnEvents(midiBytes);

    expect(events.length, greaterThanOrEqualTo(10));
    expect(events.last.tick, greaterThan(2400));
  });

  test(
    'rejects compressed audio bytes instead of guessing from container data',
    () {
      final fakeM4aBytes = Uint8List.fromList([
        0,
        0,
        0,
        24,
        102,
        116,
        121,
        112,
      ]);

      expect(
        () => MidiEngine.generateMidiFromAudio(fakeM4aBytes),
        throwsA(isA<FormatException>()),
      );
    },
  );
}

Uint8List _sineWav({required double frequency, required double seconds}) {
  const sampleRate = 16000;
  final sampleCount = (sampleRate * seconds).round();
  final samples = Float64List(sampleCount);

  for (var i = 0; i < sampleCount; i++) {
    samples[i] = math.sin(2 * math.pi * frequency * i / sampleRate) * 0.8;
  }

  return Wav([samples], sampleRate).write();
}

Uint8List _hummedMajorScaleWav({
  bool includeScoops = false,
  bool unevenTiming = false,
}) {
  const sampleRate = 44100;
  const noteSeconds = 0.52;
  const gapSeconds = 0.02;
  const notes = [60, 62, 64, 65, 67, 69, 71, 72];
  final noteLengths = unevenTiming
      ? [0.63, 0.38, 0.54, 0.48, 0.68, 0.43, 0.52, 0.58]
      : List<double>.filled(notes.length, noteSeconds);
  final gapSamples = (sampleRate * gapSeconds).round();
  final totalNoteSamples = noteLengths.fold<int>(
    0,
    (sum, seconds) => sum + (sampleRate * seconds).round(),
  );
  final samples = Float64List(
    totalNoteSamples + (notes.length - 1) * gapSamples,
  );

  var offset = 0;
  double? previousFrequency;
  for (var noteIndex = 0; noteIndex < notes.length; noteIndex++) {
    final note = notes[noteIndex];
    final noteSamples = (sampleRate * noteLengths[noteIndex]).round();
    final targetFrequency = _midiFrequency(note);
    var phase = 0.0;
    var secondPhase = 0.0;
    var thirdPhase = 0.0;

    for (var i = 0; i < noteSamples; i++) {
      final absoluteSeconds = (offset + i) / sampleRate;
      final progress = i / noteSamples;
      final approachFrequency = includeScoops
          ? _midiFrequency(note - 1)
          : targetFrequency;
      final settledFrequency = includeScoops && progress < 0.32
          ? _lerp(
              approachFrequency,
              targetFrequency,
              _smoothStep(progress / 0.32),
            )
          : targetFrequency;
      final vibratoCents =
          30 * math.sin(2 * math.pi * 5.1 * absoluteSeconds) +
          7 * math.sin(2 * math.pi * 8.3 * absoluteSeconds);
      final glide = previousFrequency == null || progress > 0.15
          ? settledFrequency
          : _lerp(
              previousFrequency,
              settledFrequency,
              _smoothStep(progress / 0.15),
            );
      final frequency = glide * math.pow(2, vibratoCents / 1200);
      final envelope = _testEnvelope(i, noteSamples);

      phase += 2 * math.pi * frequency / sampleRate;
      secondPhase += 2 * math.pi * frequency * 2 / sampleRate;
      thirdPhase += 2 * math.pi * frequency * 3 / sampleRate;
      samples[offset + i] =
          (math.sin(phase) * 0.58 +
              math.sin(secondPhase) * 0.34 +
              math.sin(thirdPhase) * 0.16) *
          envelope *
          0.82;
    }

    previousFrequency = targetFrequency;
    offset += noteSamples;
    for (var i = 0; i < gapSamples && offset + i < samples.length; i++) {
      samples[offset + i] = 0;
    }
    offset += gapSamples;
  }

  return Wav([samples], sampleRate).write();
}

Uint8List _steadySungPhraseWav() {
  const sampleRate = 44100;
  const notes = [60, 64, 67, 72, 67, 64];
  final noteLengths = [0.38, 0.47, 0.40, 0.52, 0.43, 0.50];
  final gapLengths = [0.16, 0.09, 0.18, 0.08, 0.13];
  final totalSamples =
      noteLengths.fold<int>(
        0,
        (sum, seconds) => sum + (sampleRate * seconds).round(),
      ) +
      gapLengths.fold<int>(
        0,
        (sum, seconds) => sum + (sampleRate * seconds).round(),
      );
  final samples = Float64List(totalSamples);

  var offset = 0;
  double? previousFrequency;
  for (var noteIndex = 0; noteIndex < notes.length; noteIndex++) {
    final note = notes[noteIndex];
    final noteSamples = (sampleRate * noteLengths[noteIndex]).round();
    final targetFrequency = _midiFrequency(note);
    var phase = 0.0;
    var secondPhase = 0.0;
    var thirdPhase = 0.0;

    for (var i = 0; i < noteSamples; i++) {
      final absoluteSeconds = (offset + i) / sampleRate;
      final progress = i / noteSamples;
      final consonantEnvelope = progress < 0.04
          ? math.pow(1 - progress / 0.04, 2).toDouble()
          : 0.0;
      final vibratoCents = 18 * math.sin(2 * math.pi * 5.4 * absoluteSeconds);
      final glide = previousFrequency == null || progress > 0.10
          ? targetFrequency
          : _lerp(
              previousFrequency,
              targetFrequency,
              _smoothStep(progress / 0.10),
            );
      final frequency = glide * math.pow(2, vibratoCents / 1200);
      final envelope = _testEnvelope(i, noteSamples);

      phase += 2 * math.pi * frequency / sampleRate;
      secondPhase += 2 * math.pi * frequency * 2 / sampleRate;
      thirdPhase += 2 * math.pi * frequency * 3 / sampleRate;
      final vowel =
          math.sin(phase) * 0.54 +
          math.sin(secondPhase) * 0.28 +
          math.sin(thirdPhase) * 0.14;
      final consonant =
          math.sin(2 * math.pi * 1900 * absoluteSeconds) *
          0.18 *
          consonantEnvelope;
      samples[offset + i] = (vowel * envelope + consonant) * 0.78;
    }

    previousFrequency = targetFrequency;
    offset += noteSamples;
    if (noteIndex < gapLengths.length) {
      offset += (sampleRate * gapLengths[noteIndex]).round();
    }
  }

  return Wav([samples], sampleRate).write();
}

Uint8List _steadyStaccatoEighthPhraseWav() {
  const sampleRate = 44100;
  const notes = [60, 62, 64, 65, 67, 69, 71, 72];
  final noteLengths = List<double>.filled(notes.length, 0.11);
  final gapLengths = List<double>.filled(notes.length - 1, 0.14);
  final totalSamples =
      noteLengths.fold<int>(
        0,
        (sum, seconds) => sum + (sampleRate * seconds).round(),
      ) +
      gapLengths.fold<int>(
        0,
        (sum, seconds) => sum + (sampleRate * seconds).round(),
      );
  final samples = Float64List(totalSamples);

  var offset = 0;
  for (var i = 0; i < notes.length; i++) {
    final noteSamples = (sampleRate * noteLengths[i]).round();
    final frequency = _midiFrequency(notes[i]);
    var phase = 0.0;
    var phase2 = 0.0;
    for (var j = 0; j < noteSamples; j++) {
      final env = _testEnvelope(j, noteSamples);
      phase += 2 * math.pi * frequency / sampleRate;
      phase2 += 2 * math.pi * frequency * 2 / sampleRate;
      samples[offset + j] = (math.sin(phase) * 0.65 + math.sin(phase2) * 0.24) * env * 0.85;
    }
    offset += noteSamples;
    if (i < gapLengths.length) {
      offset += (sampleRate * gapLengths[i]).round();
    }
  }

  return Wav([samples], sampleRate).write();
}

Uint8List _mixedRhythmPhraseWav() {
  const sampleRate = 44100;
  const notes = [60, 64, 67, 65, 64, 62, 60, 62, 64, 65, 67, 69, 71, 72];
  final noteLengths = [
    0.24,
    0.15,
    0.20,
    0.20,
    0.20,
    0.20,
    0.18,
    0.18,
    0.14,
    0.14,
    0.14,
    0.14,
    0.24,
    0.16,
  ];
  final gaps = [
    0.06,
    0.04,
    0.06,
    0.05,
    0.05,
    0.05,
    0.05,
    0.05,
    0.04,
    0.04,
    0.04,
    0.04,
    0.06,
  ];
  final totalSamples =
      noteLengths.fold<int>(
        0,
        (sum, seconds) => sum + (sampleRate * seconds).round(),
      ) +
      gaps.fold<int>(0, (sum, seconds) => sum + (sampleRate * seconds).round());
  final samples = Float64List(totalSamples);

  var offset = 0;
  for (var i = 0; i < notes.length; i++) {
    final noteSamples = (sampleRate * noteLengths[i]).round();
    final frequency = _midiFrequency(notes[i]);
    var phase = 0.0;
    var phase2 = 0.0;
    for (var j = 0; j < noteSamples; j++) {
      final env = _testEnvelope(j, noteSamples);
      phase += 2 * math.pi * frequency / sampleRate;
      phase2 += 2 * math.pi * frequency * 2 / sampleRate;
      samples[offset + j] = (math.sin(phase) * 0.62 + math.sin(phase2) * 0.22) * env * 0.82;
    }
    offset += noteSamples;
    if (i < gaps.length) {
      offset += (sampleRate * gaps[i]).round();
    }
  }
  return Wav([samples], sampleRate).write();
}

double _midiFrequency(int note) {
  return (440 * math.pow(2, (note - 69) / 12)).toDouble();
}

double _lerp(double? start, double end, double amount) {
  return start! + (end - start) * amount.clamp(0.0, 1.0);
}

double _smoothStep(double value) {
  final x = value.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

double _testEnvelope(int index, int sampleCount) {
  final fadeSamples = (sampleCount * 0.08).round();
  if (index < fadeSamples) return index / fadeSamples;

  final samplesFromEnd = sampleCount - 1 - index;
  if (samplesFromEnd < fadeSamples) return samplesFromEnd / fadeSamples;

  return 1;
}

List<int> _noteOns(Uint8List midiBytes) {
  return _noteOnEvents(midiBytes).map((event) => event.note).toList();
}

int _tempoBpm(Uint8List midiBytes) {
  final cursor = _Cursor(22);

  while (cursor.index < midiBytes.length) {
    _readVariableLength(midiBytes, cursor);
    final status = midiBytes[cursor.index++];

    if (status == 0xFF) {
      final type = midiBytes[cursor.index++];
      final length = _readVariableLength(midiBytes, cursor);
      if (type == 0x51 && length == 3) {
        final microsecondsPerQuarter =
            (midiBytes[cursor.index] << 16) |
            (midiBytes[cursor.index + 1] << 8) |
            midiBytes[cursor.index + 2];
        return (60000000 / microsecondsPerQuarter).round();
      }
      cursor.index += length;
    } else if (status == 0xC0 || status == 0xD0) {
      cursor.index += 1;
    } else {
      cursor.index += 2;
    }
  }

  throw StateError('Tempo meta event not found.');
}

List<_MidiNoteEvent> _noteOnEvents(Uint8List midiBytes) {
  return _midiEvents(midiBytes).where((event) => event.isNoteOn).toList();
}

List<int> _noteDurations(Uint8List midiBytes) {
  final startsByNote = <int, List<int>>{};
  final durations = <int>[];

  for (final event in _midiEvents(midiBytes)) {
    if (event.isNoteOn) {
      startsByNote.putIfAbsent(event.note, () => <int>[]).add(event.tick);
    } else {
      final starts = startsByNote[event.note];
      if (starts == null || starts.isEmpty) continue;
      durations.add(event.tick - starts.removeAt(0));
    }
  }

  return durations;
}

List<_MidiNoteEvent> _midiEvents(Uint8List midiBytes) {
  final events = <_MidiNoteEvent>[];
  final cursor = _Cursor(22);
  var tick = 0;

  while (cursor.index < midiBytes.length) {
    tick += _readVariableLength(midiBytes, cursor);
    final status = midiBytes[cursor.index++];

    if (status == 0xFF) {
      cursor.index++;
      final length = _readVariableLength(midiBytes, cursor);
      cursor.index += length;
      continue;
    }

    if (status == 0xC0 || status == 0xD0) {
      cursor.index += 1;
      continue;
    }

    final note = midiBytes[cursor.index++];
    final velocity = midiBytes[cursor.index++];
    if (status == 0x90 && velocity > 0) {
      events.add(_MidiNoteEvent(note, tick, isNoteOn: true));
    } else if (status == 0x80 || status == 0x90) {
      events.add(_MidiNoteEvent(note, tick, isNoteOn: false));
    }
  }

  return events;
}

int _readVariableLength(Uint8List bytes, _Cursor cursor) {
  var value = 0;
  int byte;

  do {
    byte = bytes[cursor.index++];
    value = (value << 7) | (byte & 0x7F);
  } while ((byte & 0x80) != 0);

  return value;
}

class _Cursor {
  _Cursor(this.index);

  int index;
}

class _MidiNoteEvent {
  const _MidiNoteEvent(this.note, this.tick, {required this.isNoteOn});

  final int note;
  final int tick;
  final bool isNoteOn;
}
