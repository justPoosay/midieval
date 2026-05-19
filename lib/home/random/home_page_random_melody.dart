part of 'package:midieval/app.dart';

class _RandomMelodyGenerator {
  static Future<void> generate(_MyHomePageState state) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final meter = state._parseMeter();
      final bpm = state._lockTempo ? state._parseTempoBpm() : 120;
      final bars = 2;
      const tpq = 480;
      final ticksPerBeat = ((tpq * 4) / meter.beatUnit).round().clamp(
        1,
        1 << 30,
      );
      final totalTicks = ticksPerBeat * meter.beatsPerMeasure * bars;

      final keyPc = state._keyNameToPitchClass(state._selectedKey);
      final scale = state._selectedScale == 'Minor'
          ? <int>{0, 2, 3, 5, 7, 8, 10}
          : <int>{0, 2, 4, 5, 7, 9, 11};
      final rand = math.Random();

      final notes = <EditableMidiNote>[];
      var cursor = 0;
      final allowedDurations = <int>[
        ticksPerBeat ~/ 2,
        ticksPerBeat,
        ticksPerBeat + (ticksPerBeat ~/ 2),
        ticksPerBeat * 2,
      ].where((d) => d > 0).toList();

      while (cursor < totalTicks) {
        final remaining = totalTicks - cursor;
        var duration = allowedDurations[rand.nextInt(allowedDurations.length)];
        if (duration > remaining) duration = remaining;
        if (duration <= 0) break;

        final octave = 4 + rand.nextInt(2);
        final pitchClass = scale.elementAt(rand.nextInt(scale.length));
        final midi = ((octave + 1) * 12) + ((keyPc + pitchClass) % 12);

        notes.add(
          EditableMidiNote(
            note: midi.clamp(0, 127),
            startTick: cursor,
            durationTicks: duration,
            velocity: 88 + rand.nextInt(28),
          ),
        );

        cursor += duration;
      }

      final parsed = ParsedMidi(
        ticksPerQuarter: tpq,
        tempoBpm: bpm,
        beatsPerMeasure: meter.beatsPerMeasure,
        beatUnit: meter.beatUnit,
        notes: const [],
      );
      final midiBytes = parsed.rebuild(
        notes,
        tempoOverrideBpm: bpm,
        beatsPerMeasureOverride: meter.beatsPerMeasure,
        beatUnitOverride: meter.beatUnit,
      );

      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      final midiFileName = 'random_melody_$ts.midi';
      final midiStoragePath = state._storagePathForUserFile(
        midiFileName,
        userId: user.id,
      );
      await Supabase.instance.client.storage
          .from('audio-samples')
          .uploadBinary(
            midiStoragePath,
            midiBytes,
            fileOptions: const FileOptions(
              contentType: 'audio/midi',
              upsert: true,
            ),
          );
      final midiUrl = Supabase.instance.client.storage
          .from('audio-samples')
          .getPublicUrl(midiStoragePath);

      await Supabase.instance.client.from('sketches').insert({
        'user_id': user.id,
        'title': '🎲 Random ${state._selectedKey} ${state._selectedScale}',
        'audio_path': midiUrl,
      });

      if (state.mounted) {
        state._refreshSketches();
        ScaffoldMessenger.of(state.context).showSnackBar(
          const SnackBar(content: Text('Random melody generated')),
        );
      }
    } catch (e) {
      if (state.mounted) {
        ScaffoldMessenger.of(state.context).showSnackBar(
          SnackBar(
            content: Text('Random melody failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
