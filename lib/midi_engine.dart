import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';

import 'package:wav/wav.dart';

class MidiEngine {
  static const int _ticksPerQuarter = 480;
  static const int _defaultTempoBpm = 120;
  static const double _minPitchHz = 75;
  static const double _maxPitchHz = 1100;
  static const double _yinThreshold = 0.12;
  static const double _minNoteSeconds = 0.20;
  static const double _minNoteSwitchSeconds = 0.18;
  static const double _maxGapSeconds = 0.14;
  static const int _smoothingRadius = 5;
  static const double _minSmoothingVoteRatio = 0.56;
  static const double _maxFragmentSeconds = 0.30;
  static const double _fragmentMedianRatio = 0.58;
  static const int _beatsPerMeasure = 4;
  static const int _ticksPerBar = _ticksPerQuarter * _beatsPerMeasure;
  static const int _quantizeTicks = _ticksPerQuarter ~/ 4;
  static const double _maxSteadyRhythmDeviation = 0.42;
  static const List<int> _steadyRhythmNoteTicks = [
    _ticksPerQuarter ~/ 4,
    _ticksPerQuarter ~/ 2,
    (_ticksPerQuarter * 3) ~/ 4,
    _ticksPerQuarter,
    (_ticksPerQuarter * 3) ~/ 2,
    _ticksPerQuarter * 2,
  ];
  static const List<double> _musicalBeatIntervals = [
    0.25,
    0.5,
    0.75,
    1,
    1.5,
    2,
    3,
    4,
  ];
  static const List<int> _commonTempos = [
    60,
    66,
    70,
    72,
    75,
    80,
    84,
    90,
    96,
    100,
    108,
    110,
    112,
    120,
    128,
    130,
    140,
    150,
    160,
    180,
  ];
  static _RhythmLanguageModel? _rhythmLanguageModel;

  static void configureRhythmLanguageModel(Uint8List jsonBytes) {
    final decoded = jsonDecode(utf8.decode(jsonBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid rhythm language model JSON');
    }
    _rhythmLanguageModel = _RhythmLanguageModel.fromJson(decoded);
  }

  static Uint8List generateSineSequenceWav({
    List<int> midiNotes = const [72, 74, 76, 77, 79, 81, 83, 84],
    int sampleRate = 44100,
    double noteSeconds = 0.52,
    double gapSeconds = 0,
  }) {
    final noteSampleCount = (sampleRate * noteSeconds).round();
    final gapSampleCount = (sampleRate * gapSeconds).round();
    final totalSampleCount =
        midiNotes.length * noteSampleCount +
        math.max(0, midiNotes.length - 1) * gapSampleCount;
    final samples = Float64List(totalSampleCount);

    var offset = 0;
    for (var noteIndex = 0; noteIndex < midiNotes.length; noteIndex++) {
      final frequency = _midiToFrequency(midiNotes[noteIndex]);
      for (var i = 0; i < noteSampleCount; i++) {
        final envelope = _sineEnvelope(i, noteSampleCount);
        samples[offset + i] =
            math.sin(2 * math.pi * frequency * i / sampleRate) *
            0.75 *
            envelope;
      }
      offset += noteSampleCount + gapSampleCount;
    }

    return Wav([samples], sampleRate).write();
  }

  static Uint8List generateMidiFromAudio(
    Uint8List audioBytes, {
    int? tempoBpm,
  }) {
    final audio = _decodeWav(audioBytes);
    final samples = _prepareSignal(audio.samples);
    final notes = _detectNotes(samples, audio.sampleRate);

    if (notes.isEmpty) {
      throw const FormatException(
        'Nie znaleziono stabilnej wysokosci dzwieku. Nagraj pojedyncza, wyrazna melodie bez dlugiej ciszy.',
      );
    }

    final detectedTempoBpm = _normalizeTempoBpm(
      tempoBpm ?? _estimateTempoBpm(notes),
    );
    final quantizedNotes = _quantizeNotes(notes, tempoBpm: detectedTempoBpm);

    return _buildMidi(quantizedNotes, tempoBpm: detectedTempoBpm);
  }

  static _AudioData _decodeWav(Uint8List audioBytes) {
    if (audioBytes.length < 12 ||
        String.fromCharCodes(audioBytes.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(audioBytes.sublist(8, 12)) != 'WAVE') {
      throw const FormatException(
        'Konwersja wymaga pliku WAV/PCM. Starsze nagrania m4a/opus trzeba nagrac ponownie po aktualizacji aplikacji.',
      );
    }

    final wav = Wav.read(audioBytes);
    return _AudioData(wav.toMono(), wav.samplesPerSecond);
  }

  static Float64List _prepareSignal(Float64List input) {
    if (input.isEmpty) return input;

    var mean = 0.0;
    for (final sample in input) {
      mean += sample;
    }
    mean /= input.length;

    var peak = 0.0;
    final output = Float64List(input.length);
    for (var i = 0; i < input.length; i++) {
      final value = input[i] - mean;
      output[i] = value;
      peak = math.max(peak, value.abs());
    }

    if (peak > 0) {
      for (var i = 0; i < output.length; i++) {
        output[i] /= peak;
      }
    }

    return output;
  }

  static List<_DetectedNote> _detectNotes(Float64List samples, int sampleRate) {
    if (samples.length < 1024) return const [];

    final frameSize = math.min(
      4096,
      math.max(2048, _nextPowerOfTwo(sampleRate ~/ 12)),
    );
    final hopSize = frameSize ~/ 4;
    final frameCount = 1 + ((samples.length - frameSize) ~/ hopSize);
    if (frameCount <= 0) return const [];

    final rmsValues = List<double>.filled(frameCount, 0);
    for (var frame = 0; frame < frameCount; frame++) {
      rmsValues[frame] = _rms(samples, frame * hopSize, frameSize);
    }

    final strongestRms = _percentile(rmsValues, 0.90);
    final silenceGate = math.max(0.020, strongestRms * 0.25);
    final rawFrames = List<_PitchFrame?>.filled(frameCount, null);

    for (var frame = 0; frame < frameCount; frame++) {
      final rms = rmsValues[frame];
      if (rms < silenceGate) continue;

      final start = frame * hopSize;
      final pitch = _estimatePitchYin(samples, start, frameSize, sampleRate);
      if (pitch == null || pitch.confidence < 0.78) continue;

      final note = _frequencyToMidi(pitch.frequency);
      if (note < 24 || note > 108) continue;

      rawFrames[frame] = _PitchFrame(note, pitch.confidence, rms);
    }

    final smoothedFrames = _smoothFrames(rawFrames);
    return _framesToNotes(
      smoothedFrames,
      hopSize: hopSize,
      frameSize: frameSize,
      sampleRate: sampleRate,
      maxRms: math.max(strongestRms, silenceGate),
    );
  }

  static List<_PitchFrame?> _smoothFrames(List<_PitchFrame?> frames) {
    final smoothed = List<_PitchFrame?>.filled(frames.length, null);

    for (var i = 0; i < frames.length; i++) {
      final frame = frames[i];
      if (frame == null) continue;

      final counts = <int, int>{};
      var rms = 0.0;
      var confidence = 0.0;
      var seen = 0;

      for (
        var j = math.max(0, i - _smoothingRadius);
        j <= math.min(frames.length - 1, i + _smoothingRadius);
        j++
      ) {
        final neighbor = frames[j];
        if (neighbor == null) continue;
        counts[neighbor.note] = (counts[neighbor.note] ?? 0) + 1;
        rms += neighbor.rms;
        confidence += neighbor.confidence;
        seen++;
      }

      if (seen == 0) continue;

      final noteEntry = counts.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      if (noteEntry.value / seen < _minSmoothingVoteRatio && seen >= 5) {
        continue;
      }

      smoothed[i] = _PitchFrame(noteEntry.key, confidence / seen, rms / seen);
    }

    return smoothed;
  }

  static List<_DetectedNote> _framesToNotes(
    List<_PitchFrame?> frames, {
    required int hopSize,
    required int frameSize,
    required int sampleRate,
    required double maxRms,
  }) {
    final notes = <_DetectedNote>[];
    final hopSeconds = hopSize / sampleRate;
    final frameSeconds = frameSize / sampleRate;

    int? currentNote;
    int? pendingNote;
    var startSeconds = 0.0;
    var pendingStartSeconds = 0.0;
    var lastPitchedSeconds = 0.0;
    var rmsSum = 0.0;
    var frameSum = 0;

    void closeNote(double endSeconds) {
      if (currentNote == null || frameSum == 0) return;

      final duration = endSeconds - startSeconds;
      if (duration >= _minNoteSeconds) {
        final averageRms = rmsSum / frameSum;
        final velocity = (42 + (averageRms / maxRms).clamp(0.0, 1.0) * 70)
            .round();
        notes.add(
          _DetectedNote(
            note: currentNote!,
            startSeconds: startSeconds,
            durationSeconds: duration,
            velocity: velocity.clamp(35, 112),
          ),
        );
      }

      currentNote = null;
      pendingNote = null;
      rmsSum = 0;
      frameSum = 0;
    }

    for (var i = 0; i < frames.length; i++) {
      final timeSeconds = i * hopSeconds;
      final frame = frames[i];

      if (frame == null) {
        if (currentNote != null &&
            timeSeconds - lastPitchedSeconds > _maxGapSeconds) {
          closeNote(lastPitchedSeconds + frameSeconds);
        }
        pendingNote = null;
        continue;
      }

      if (currentNote == null) {
        currentNote = frame.note;
        startSeconds = timeSeconds;
        pendingNote = null;
      } else if (frame.note != currentNote) {
        if (frame.note != pendingNote) {
          pendingNote = frame.note;
          pendingStartSeconds = timeSeconds;
        }

        if (timeSeconds - pendingStartSeconds >= _minNoteSwitchSeconds) {
          closeNote(pendingStartSeconds);
          currentNote = frame.note;
          startSeconds = pendingStartSeconds;
          pendingNote = null;
          rmsSum = 0;
          frameSum = 0;
        } else {
          lastPitchedSeconds = timeSeconds;
          rmsSum += frame.rms;
          frameSum++;
          continue;
        }
      } else {
        pendingNote = null;
      }

      lastPitchedSeconds = timeSeconds;
      rmsSum += frame.rms;
      frameSum++;
    }

    if (currentNote != null) {
      closeNote(lastPitchedSeconds + frameSeconds);
    }

    return _cleanupUnstableNotes(_mergeCloseNotes(notes));
  }

  static List<_DetectedNote> _mergeCloseNotes(List<_DetectedNote> notes) {
    if (notes.length < 2) return notes;

    final merged = <_DetectedNote>[];
    for (final note in notes) {
      if (merged.isEmpty) {
        merged.add(note);
        continue;
      }

      final previous = merged.last;
      final previousEnd = previous.startSeconds + previous.durationSeconds;
      final gap = note.startSeconds - previousEnd;

      if (previous.note == note.note && gap >= 0 && gap <= _maxGapSeconds) {
        merged[merged.length - 1] = previous.copyWith(
          durationSeconds:
              note.startSeconds + note.durationSeconds - previous.startSeconds,
          velocity: math.max(previous.velocity, note.velocity),
        );
      } else {
        merged.add(note);
      }
    }

    return merged;
  }

  static List<_DetectedNote> _cleanupUnstableNotes(List<_DetectedNote> notes) {
    if (notes.length < 2) return notes;

    var cleaned = notes;
    for (var pass = 0; pass < 3; pass++) {
      final nextPass = _absorbShortFragments(cleaned);
      if (nextPass.length == cleaned.length) return nextPass;
      cleaned = _mergeCloseNotes(nextPass);
    }

    return cleaned;
  }

  static List<_DetectedNote> _absorbShortFragments(List<_DetectedNote> notes) {
    if (notes.length < 2) return notes;

    final medianDuration = _medianDurationSeconds(notes);
    final fragmentLimit = math
        .min(_maxFragmentSeconds, medianDuration * _fragmentMedianRatio)
        .clamp(_minNoteSeconds, _maxFragmentSeconds);
    final cleaned = <_DetectedNote>[];

    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];
      final previous = cleaned.isEmpty ? null : cleaned.last;
      final next = i < notes.length - 1 ? notes[i + 1] : null;

      if (!_isUnstableFragment(note, previous, next, fragmentLimit)) {
        cleaned.add(note);
        continue;
      }

      if (previous != null &&
          (next == null || previous.durationSeconds >= next.durationSeconds)) {
        cleaned[cleaned.length - 1] = previous.copyWith(
          durationSeconds: _noteEndSeconds(note) - previous.startSeconds,
          velocity: math.max(previous.velocity, note.velocity),
        );
      } else if (next != null) {
        notes[i + 1] = next.copyWith(
          startSeconds: note.startSeconds,
          durationSeconds: _noteEndSeconds(next) - note.startSeconds,
          velocity: math.max(next.velocity, note.velocity),
        );
      }
    }

    return cleaned;
  }

  static bool _isUnstableFragment(
    _DetectedNote note,
    _DetectedNote? previous,
    _DetectedNote? next,
    double fragmentLimit,
  ) {
    if (note.durationSeconds > fragmentLimit) return false;
    if (previous == null && next == null) return false;

    final previousIsStable =
        previous != null &&
        previous.durationSeconds >= note.durationSeconds * 1.35;
    final nextIsStable =
        next != null && next.durationSeconds >= note.durationSeconds * 1.35;
    if (!previousIsStable && !nextIsStable) return false;

    final betweenStableNotes =
        previous != null &&
        next != null &&
        previous.durationSeconds > note.durationSeconds &&
        next.durationSeconds > note.durationSeconds;
    if (betweenStableNotes) return true;

    final previousSemitoneWobble =
        previous != null && (previous.note - note.note).abs() == 1;
    final nextSemitoneWobble =
        next != null && (next.note - note.note).abs() == 1;
    return previousSemitoneWobble || nextSemitoneWobble;
  }

  static double _medianDurationSeconds(List<_DetectedNote> notes) {
    final durations = notes.map((note) => note.durationSeconds).toList()
      ..sort();
    return durations[durations.length ~/ 2];
  }

  static double _noteEndSeconds(_DetectedNote note) {
    return note.startSeconds + note.durationSeconds;
  }

  static _PitchEstimate? _estimatePitchYin(
    Float64List samples,
    int start,
    int frameSize,
    int sampleRate,
  ) {
    final tauMin = math.max(2, (sampleRate / _maxPitchHz).floor());
    final tauMax = math.min(frameSize - 2, (sampleRate / _minPitchHz).ceil());
    if (tauMax <= tauMin) return null;

    final difference = List<double>.filled(tauMax + 1, 0);
    for (var tau = 1; tau <= tauMax; tau++) {
      var sum = 0.0;
      final limit = frameSize - tau;
      for (var i = 0; i < limit; i++) {
        final delta = samples[start + i] - samples[start + i + tau];
        sum += delta * delta;
      }
      difference[tau] = sum;
    }

    final cumulativeMean = List<double>.filled(tauMax + 1, 1);
    var runningSum = 0.0;
    for (var tau = 1; tau <= tauMax; tau++) {
      runningSum += difference[tau];
      cumulativeMean[tau] = runningSum == 0
          ? 1
          : difference[tau] * tau / runningSum;
    }

    int? bestTau;
    for (var tau = tauMin; tau <= tauMax; tau++) {
      if (cumulativeMean[tau] < _yinThreshold) {
        while (tau + 1 <= tauMax &&
            cumulativeMean[tau + 1] < cumulativeMean[tau]) {
          tau++;
        }
        bestTau = tau;
        break;
      }
    }

    bestTau ??= _lowestIndex(cumulativeMean, tauMin, tauMax);
    final confidence = 1 - cumulativeMean[bestTau];
    if (confidence < 0.55) return null;

    final betterTau = _parabolicTau(cumulativeMean, bestTau);
    final frequency = sampleRate / betterTau;
    if (frequency < _minPitchHz || frequency > _maxPitchHz || frequency.isNaN) {
      return null;
    }

    return _PitchEstimate(frequency, confidence.clamp(0.0, 1.0));
  }

  static int _lowestIndex(List<double> values, int start, int end) {
    var bestIndex = start;
    var bestValue = values[start];
    for (var i = start + 1; i <= end; i++) {
      if (values[i] < bestValue) {
        bestIndex = i;
        bestValue = values[i];
      }
    }
    return bestIndex;
  }

  static double _parabolicTau(List<double> values, int tau) {
    if (tau <= 1 || tau >= values.length - 1) return tau.toDouble();

    final left = values[tau - 1];
    final center = values[tau];
    final right = values[tau + 1];
    final denominator = left - 2 * center + right;
    if (denominator.abs() < 1e-12) return tau.toDouble();

    return tau + 0.5 * (left - right) / denominator;
  }

  static double _rms(Float64List samples, int start, int frameSize) {
    var sum = 0.0;
    for (var i = 0; i < frameSize; i++) {
      final sample = samples[start + i];
      sum += sample * sample;
    }
    return math.sqrt(sum / frameSize);
  }

  static double _percentile(List<double> values, double percentile) {
    final sorted = values.toList()..sort();
    final index = ((sorted.length - 1) * percentile).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  static int _nextPowerOfTwo(int value) {
    var result = 1;
    while (result < value) {
      result <<= 1;
    }
    return result;
  }

  static int _frequencyToMidi(double frequency) {
    return (69 + 12 * (math.log(frequency / 440) / math.ln2)).round();
  }

  static double _midiToFrequency(int note) {
    return (440 * math.pow(2, (note - 69) / 12)).toDouble();
  }

  static double _sineEnvelope(int index, int sampleCount) {
    final fadeSamples = math.min(sampleCount ~/ 8, 256);
    if (fadeSamples <= 0) return 1;
    if (index < fadeSamples) return index / fadeSamples;

    final samplesFromEnd = sampleCount - 1 - index;
    if (samplesFromEnd < fadeSamples) return samplesFromEnd / fadeSamples;

    return 1;
  }

  static int _estimateTempoBpm(List<_DetectedNote> notes) {
    if (notes.length < 2) return _defaultTempoBpm;

    final intervals = <double>[];
    for (var i = 1; i < notes.length; i++) {
      final interval = notes[i].startSeconds - notes[i - 1].startSeconds;
      if (interval >= 0.08 && interval <= 4.0) {
        intervals.add(interval);
      }
    }

    if (intervals.isEmpty) return _defaultTempoBpm;

    var bestTempo = _defaultTempoBpm;
    var bestScore = double.infinity;

    for (var tempo = 50; tempo <= 200; tempo++) {
      final beatSeconds = 60 / tempo;
      var score = 0.0;

      for (final interval in intervals) {
        final beats = interval / beatSeconds;
        final closest = _closestBeatInterval(beats);
        final timingError = (beats - closest).abs() / math.max(closest, 0.25);
        score += timingError + _beatIntervalPenalty(closest);
      }

      score /= intervals.length;
      score += (tempo - _defaultTempoBpm).abs() * 0.0008;

      if (score < bestScore) {
        bestScore = score;
        bestTempo = tempo;
      }
    }

    return _snapToCommonTempo(bestTempo);
  }

  static double _closestBeatInterval(double beats) {
    var closest = _musicalBeatIntervals.first;
    var bestDistance = double.infinity;

    for (final interval in _musicalBeatIntervals) {
      final distance = (beats - interval).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        closest = interval;
      }
    }

    return closest;
  }

  static double _beatIntervalPenalty(double beats) {
    if (beats == 1) return 0;
    if (beats == 0.5 || beats == 2) return 0.06;
    if (beats == 0.75 || beats == 1.5) return 0.09;
    if (beats == 0.25 || beats == 3 || beats == 4) return 0.14;
    return 0.18;
  }

  static int _snapToCommonTempo(int tempo) {
    var closest = tempo;
    var bestDistance = 5;

    for (final commonTempo in _commonTempos) {
      final distance = (tempo - commonTempo).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        closest = commonTempo;
      }
    }

    return closest;
  }

  static int _normalizeTempoBpm(int tempoBpm) {
    return tempoBpm.clamp(40, 240).toInt();
  }

  static List<_QuantizedNote> _quantizeNotes(
    List<_DetectedNote> notes, {
    required int tempoBpm,
  }) {
    final languageModelQuantized = _quantizeWithLanguageModel(
      notes,
      tempoBpm: tempoBpm,
    );
    if (languageModelQuantized != null) {
      return languageModelQuantized;
    }

    final steadyPhrase = _quantizeSteadyRhythmPhrase(notes, tempoBpm: tempoBpm);
    if (steadyPhrase != null) return steadyPhrase;

    final beatSeconds = 60 / tempoBpm;
    final quantized = <_QuantizedNote>[];
    var currentStartTick = 0;

    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];
      final beatDuration = note.durationSeconds / beatSeconds;
      final durationTick = math.max(
        _quantizeTicks,
        _roundToGrid((beatDuration * _ticksPerQuarter).round(), _quantizeTicks),
      );

      quantized.add(
        _QuantizedNote(
          note: note.note,
          startTick: currentStartTick,
          durationTicks: durationTick,
          velocity: note.velocity,
        ),
      );

      if (i < notes.length - 1) {
        final intervalSeconds = notes[i + 1].startSeconds - note.startSeconds;
        final intervalBeats = intervalSeconds / beatSeconds;
        final intervalTicks =
            (_closestBeatInterval(intervalBeats) * _ticksPerQuarter).round();
        currentStartTick += _roundToGrid(intervalTicks, _quantizeTicks);
      }
    }

    quantized.sort((a, b) => a.startTick.compareTo(b.startTick));

    for (var i = 0; i < quantized.length; i++) {
      final current = quantized[i];
      final availableTicks = i < quantized.length - 1
          ? quantized[i + 1].startTick - current.startTick
          : _lastNoteAvailableTicks(quantized, i);
      if (availableTicks <= 0) continue;

      final maxDuration = math.max(_quantizeTicks, availableTicks);
      if (current.durationTicks > maxDuration) {
        quantized[i] = current.copyWith(durationTicks: maxDuration);
      }
    }

    return quantized;
  }

  static List<_QuantizedNote>? _quantizeWithLanguageModel(
    List<_DetectedNote> notes, {
    required int tempoBpm,
  }) {
    final model = _rhythmLanguageModel;
    if (model == null || notes.length < 2) return null;

    final beatSeconds = 60 / tempoBpm;
    if (beatSeconds <= 0) return null;

    final intervalTicks = <int>[];
    for (var i = 1; i < notes.length; i++) {
      final interval = notes[i].startSeconds - notes[i - 1].startSeconds;
      if (interval <= 0) return null;
      final rawTicks = (interval / beatSeconds * _ticksPerQuarter).round();
      intervalTicks.add(rawTicks.clamp(_quantizeTicks, _ticksPerQuarter * 4));
    }

    final candidateTicks = _steadyRhythmNoteTicks;
    var beams = <_RhythmBeam>[
      const _RhythmBeam(tokens: [], score: 0, totalTicks: 0),
    ];
    const beamSize = 12;

    for (var i = 0; i < intervalTicks.length; i++) {
      final observed = intervalTicks[i];
      final nextBeams = <_RhythmBeam>[];
      for (final beam in beams) {
        for (final tick in candidateTicks) {
          final timingError = (observed - tick).abs() / math.max(tick, 1);
          if (timingError > 0.65) continue;
          final lmPenalty = model.transitionPenalty(
            beam.tokens.isEmpty ? null : beam.tokens.last,
            tick,
          );
          final dottedPenalty =
              tick == (_ticksPerQuarter * 3) ~/ 4 ||
                  tick == (_ticksPerQuarter * 3) ~/ 2
              ? 0.10
              : 0.0;
          final score = beam.score + timingError + lmPenalty + dottedPenalty;
          nextBeams.add(
            _RhythmBeam(
              tokens: [...beam.tokens, tick],
              score: score,
              totalTicks: beam.totalTicks + tick,
            ),
          );
        }
      }

      if (nextBeams.isEmpty) return null;
      nextBeams.sort((a, b) => a.score.compareTo(b.score));
      beams = nextBeams.take(math.min(beamSize, nextBeams.length)).toList();
    }

    if (beams.isEmpty) return null;
    final best = beams.first;
    if (best.tokens.length != notes.length - 1) return null;

    final quantized = <_QuantizedNote>[];
    var startTick = 0;
    for (var i = 0; i < notes.length; i++) {
      final durationTick = i < best.tokens.length
          ? best.tokens[i]
          : best.tokens.last;
      quantized.add(
        _QuantizedNote(
          note: notes[i].note,
          startTick: startTick,
          durationTicks: durationTick,
          velocity: notes[i].velocity,
        ),
      );
      if (i < best.tokens.length) {
        startTick += best.tokens[i];
      }
    }

    return quantized;
  }

  static List<_QuantizedNote>? _quantizeSteadyRhythmPhrase(
    List<_DetectedNote> notes, {
    required int tempoBpm,
  }) {
    if (notes.length < 3 || notes.length > 32) return null;

    final intervals = <double>[];
    for (var i = 1; i < notes.length; i++) {
      final interval = notes[i].startSeconds - notes[i - 1].startSeconds;
      if (interval <= 0) return null;
      intervals.add(interval);
    }

    final intervalMedian = _medianDouble(intervals);
    if (intervalMedian <= 0) return null;

    final relativeDeviations = [
      for (final interval in intervals)
        (interval - intervalMedian).abs() / intervalMedian,
    ];
    final averageDeviation =
        relativeDeviations.reduce((a, b) => a + b) / relativeDeviations.length;
    final medianDeviation = _medianDouble(relativeDeviations);
    if (averageDeviation > _maxSteadyRhythmDeviation ||
        medianDeviation > _maxSteadyRhythmDeviation * 0.75) {
      return null;
    }

    final noteTicks = _bestSteadyRhythmTicks(
      intervalMedian,
      tempoBpm: tempoBpm,
      noteCount: notes.length,
    );
    if (noteTicks == null) return null;

    return [
      for (var i = 0; i < notes.length; i++)
        _QuantizedNote(
          note: notes[i].note,
          startTick: i * noteTicks,
          durationTicks: noteTicks,
          velocity: notes[i].velocity,
        ),
    ];
  }

  static int? _bestSteadyRhythmTicks(
    double intervalMedian, {
    required int tempoBpm,
    required int noteCount,
  }) {
    final beatSeconds = 60 / tempoBpm;
    if (beatSeconds <= 0) return null;

    final observedBeats = intervalMedian / beatSeconds;
    int? bestTicks;
    var bestScore = double.infinity;

    for (final ticks in _steadyRhythmNoteTicks) {
      final candidateBeats = ticks / _ticksPerQuarter;
      final timingError =
          (observedBeats - candidateBeats).abs() / candidateBeats;
      if (timingError > 0.48) continue;

      final phraseTicks = noteCount * ticks;
      final barRemainder = phraseTicks % _ticksPerBar;
      final barDistance = math.min(
        barRemainder,
        barRemainder == 0 ? 0 : _ticksPerBar - barRemainder,
      );
      final barPenalty = barDistance / _ticksPerBar * 0.16;
      final dottedPenalty =
          ticks == (_ticksPerQuarter * 3) ~/ 4 ||
              ticks == (_ticksPerQuarter * 3) ~/ 2
          ? 0.08
          : 0.0;
      final sixteenthPenalty = ticks == _ticksPerQuarter ~/ 4 ? 0.04 : 0.0;
      final score = timingError + barPenalty + dottedPenalty + sixteenthPenalty;

      if (score < bestScore) {
        bestScore = score;
        bestTicks = ticks;
      }
    }

    return bestScore <= 0.40 ? bestTicks : null;
  }

  static double _medianDouble(List<double> values) {
    final sorted = values.toList()..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];

    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  static int _lastNoteAvailableTicks(List<_QuantizedNote> notes, int index) {
    if (index == 0) return notes[index].durationTicks;

    return notes[index].startTick - notes[index - 1].startTick;
  }

  static int _roundToGrid(int value, int grid) {
    return (value / grid).round() * grid;
  }

  static Uint8List _buildMidi(
    List<_QuantizedNote> notes, {
    required int tempoBpm,
  }) {
    final events = <_MidiEvent>[];

    for (final note in notes) {
      final durationTick = math.max(_ticksPerQuarter ~/ 16, note.durationTicks);
      events
        ..add(_MidiEvent(note.startTick, true, note.note, note.velocity))
        ..add(_MidiEvent(note.startTick + durationTick, false, note.note, 0));
    }

    events.sort((a, b) {
      final tickCompare = a.tick.compareTo(b.tick);
      if (tickCompare != 0) return tickCompare;
      if (a.isNoteOn == b.isNoteOn) return 0;
      return a.isNoteOn ? 1 : -1;
    });

    final track = <int>[];
    final microsecondsPerQuarter = 60000000 ~/ tempoBpm;
    track.addAll([
      0x00,
      0xFF,
      0x51,
      0x03,
      (microsecondsPerQuarter >> 16) & 0xFF,
      (microsecondsPerQuarter >> 8) & 0xFF,
      microsecondsPerQuarter & 0xFF,
      0x00,
      0xFF,
      0x58,
      0x04,
      _beatsPerMeasure,
      0x02,
      0x18,
      0x08,
      0x00,
      0xC0,
      0x00,
    ]);

    var previousTick = 0;
    for (final event in events) {
      track.addAll(_encodeVariableLength(event.tick - previousTick));
      track.add(event.isNoteOn ? 0x90 : 0x80);
      track.add(event.note.clamp(0, 127));
      track.add(event.velocity.clamp(0, 127));
      previousTick = event.tick;
    }

    track.addAll([0x00, 0xFF, 0x2F, 0x00]);

    return Uint8List.fromList([
      0x4D,
      0x54,
      0x68,
      0x64,
      ..._encodeInt32(6),
      ..._encodeInt16(0),
      ..._encodeInt16(1),
      ..._encodeInt16(_ticksPerQuarter),
      0x4D,
      0x54,
      0x72,
      0x6B,
      ..._encodeInt32(track.length),
      ...track,
    ]);
  }

  static List<int> _encodeVariableLength(int value) {
    var buffer = value & 0x7F;
    while ((value >>= 7) > 0) {
      buffer <<= 8;
      buffer |= ((value & 0x7F) | 0x80);
    }

    final bytes = <int>[];
    while (true) {
      bytes.add(buffer & 0xFF);
      if ((buffer & 0x80) != 0) {
        buffer >>= 8;
      } else {
        break;
      }
    }
    return bytes;
  }

  static List<int> _encodeInt16(int value) {
    return [(value >> 8) & 0xFF, value & 0xFF];
  }

  static List<int> _encodeInt32(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }
}

class _AudioData {
  const _AudioData(this.samples, this.sampleRate);

  final Float64List samples;
  final int sampleRate;
}

class _PitchEstimate {
  const _PitchEstimate(this.frequency, this.confidence);

  final double frequency;
  final double confidence;
}

class _PitchFrame {
  const _PitchFrame(this.note, this.confidence, this.rms);

  final int note;
  final double confidence;
  final double rms;
}

class _DetectedNote {
  const _DetectedNote({
    required this.note,
    required this.startSeconds,
    required this.durationSeconds,
    required this.velocity,
  });

  final int note;
  final double startSeconds;
  final double durationSeconds;
  final int velocity;

  _DetectedNote copyWith({
    double? startSeconds,
    double? durationSeconds,
    int? velocity,
  }) {
    return _DetectedNote(
      note: note,
      startSeconds: startSeconds ?? this.startSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      velocity: velocity ?? this.velocity,
    );
  }
}

class _QuantizedNote {
  const _QuantizedNote({
    required this.note,
    required this.startTick,
    required this.durationTicks,
    required this.velocity,
  });

  final int note;
  final int startTick;
  final int durationTicks;
  final int velocity;

  _QuantizedNote copyWith({int? durationTicks}) {
    return _QuantizedNote(
      note: note,
      startTick: startTick,
      durationTicks: durationTicks ?? this.durationTicks,
      velocity: velocity,
    );
  }
}

class _MidiEvent {
  const _MidiEvent(this.tick, this.isNoteOn, this.note, this.velocity);

  final int tick;
  final bool isNoteOn;
  final int note;
  final int velocity;
}

class _RhythmLanguageModel {
  _RhythmLanguageModel({
    required this.unigramPenalty,
    required this.bigramPenalty,
  });

  factory _RhythmLanguageModel.fromJson(Map<String, dynamic> json) {
    final unigram = <int, double>{};
    final bigram = <String, double>{};

    final unigramJson = json['unigram_penalty'];
    if (unigramJson is Map) {
      unigramJson.forEach((key, value) {
        final tick = int.tryParse(key.toString());
        final penalty = (value as num?)?.toDouble();
        if (tick != null && penalty != null) {
          unigram[tick] = penalty;
        }
      });
    }

    final bigramJson = json['bigram_penalty'];
    if (bigramJson is Map) {
      bigramJson.forEach((key, value) {
        final penalty = (value as num?)?.toDouble();
        if (penalty != null) {
          bigram[key.toString()] = penalty;
        }
      });
    }

    return _RhythmLanguageModel(
      unigramPenalty: unigram,
      bigramPenalty: bigram,
    );
  }

  final Map<int, double> unigramPenalty;
  final Map<String, double> bigramPenalty;

  double transitionPenalty(int? previousTick, int tick) {
    if (previousTick == null) {
      return unigramPenalty[tick] ?? 0.85;
    }
    final key = '$previousTick->$tick';
    return bigramPenalty[key] ?? (unigramPenalty[tick] ?? 0.85);
  }
}

class _RhythmBeam {
  const _RhythmBeam({
    required this.tokens,
    required this.score,
    required this.totalTicks,
  });

  final List<int> tokens;
  final double score;
  final int totalTicks;
}
