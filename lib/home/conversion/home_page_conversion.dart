part of 'package:midieval/app.dart';

class _HomePageConversionFlow {
  static Future<void> convertAudioToMidi(
    _MyHomePageState state,
    String audioUrl,
    int sketchId,
  ) async {
    _enqueueConversionJob(state, sketchId, audioUrl);
  }

  static void _enqueueConversionJob(
    _MyHomePageState state,
    int sketchId,
    String audioUrl,
  ) {
    final active = state._conversionJobs[sketchId];
    if (active != null &&
        (active.status == _ConversionStatus.queued ||
            active.status == _ConversionStatus.running)) {
      return;
    }
    state._applyState(() {
      state._conversionJobs[sketchId] = const _ConversionJobState(
        status: _ConversionStatus.queued,
        message: 'Queued',
        progress: 0.0,
      );
      state._conversionQueue.add(
        _ConversionRequest(sketchId: sketchId, audioUrl: audioUrl),
      );
    });
    unawaited(_processConversionQueue(state));
  }

  static Future<void> _processConversionQueue(_MyHomePageState state) async {
    if (state._isProcessingConversionQueue) return;
    state._isProcessingConversionQueue = true;
    state._applyState(() => state._isGeneratingMidiPreview = true);
    try {
      while (state._conversionQueue.isNotEmpty) {
        await _runConversionJob(state, state._conversionQueue.removeFirst());
      }
    } finally {
      state._isProcessingConversionQueue = false;
      state._applyState(() => state._isGeneratingMidiPreview = false);
    }
  }

  static Future<void> _runConversionJob(
    _MyHomePageState state,
    _ConversionRequest request,
  ) async {
    try {
      if (_isMidiSource(request.audioUrl)) {
        _setJobState(
          state,
          request.sketchId,
          const _ConversionJobState(
            status: _ConversionStatus.running,
            message: 'Editing existing MIDI...',
            progress: 0.40,
          ),
        );
        final midiBytes = await _downloadOrReadBytes(request.audioUrl);
        final editedMidiBytes = await state._openMidiEditor(
          midiBytes,
          tempoOverrideBpm: state._lockTempo ? state._parseTempoBpm() : null,
          meterOverride: state._lockMeter ? (state._parseMeter()) : null,
          keyScaleConstraint: state._constrainToScale
              ? KeyScaleConstraint(
                  tonic: state._keyNameToPitchClass(state._selectedKey),
                  isMinor: state._selectedScale == 'Minor',
                )
              : null,
        );
        if (editedMidiBytes == null) {
          _setJobState(
            state,
            request.sketchId,
            const _ConversionJobState(
              status: _ConversionStatus.failed,
              message: 'Canceled in preview',
              progress: 1.0,
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 900));
          if (state.mounted) {
            state._applyState(
              () => state._conversionJobs.remove(request.sketchId),
            );
          }
          return;
        }
        _setJobState(
          state,
          request.sketchId,
          const _ConversionJobState(
            status: _ConversionStatus.running,
            message: 'Uploading edited MIDI...',
            progress: 0.82,
          ),
        );
        final midiFileName = state._storageMidiFileName(
          sketchId: request.sketchId,
        );
        final midiStoragePath = state._storagePathForUserFile(midiFileName);
        await Supabase.instance.client.storage
            .from('audio-samples')
            .uploadBinary(
              midiStoragePath,
              editedMidiBytes,
              fileOptions: const FileOptions(
                contentType: 'audio/midi',
                upsert: true,
              ),
            );
        final midiUrl = Supabase.instance.client.storage
            .from('audio-samples')
            .getPublicUrl(midiStoragePath);
        await Supabase.instance.client
            .from('sketches')
            .update({
              'title':
                  '🎵 MIDI: ${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}',
              'audio_path': midiUrl,
            })
            .match(state._ownedSketchFilter(request.sketchId));
        await Supabase.instance.client
            .from('sketches')
            .update({
              'title':
                  state._sketchTitleById(request.sketchId) ??
                  'Recording ${request.sketchId}',
              'status': 'ready',
              'last_error': null,
            })
            .match(state._ownedSketchFilter(request.sketchId));

        _setJobState(
          state,
          request.sketchId,
          const _ConversionJobState(
            status: _ConversionStatus.done,
            message: 'MIDI updated',
            progress: 1.0,
          ),
        );
        state._triggerJumpingNotes();
        if (state.mounted) {
          state._refreshSketches();
        }
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (state.mounted) {
          state._applyState(
            () => state._conversionJobs.remove(request.sketchId),
          );
        }
        return;
      }

      _setJobState(
        state,
        request.sketchId,
        const _ConversionJobState(
          status: _ConversionStatus.running,
          message: 'Preparing audio...',
          progress: 0.10,
        ),
      );
      final sourcePath = await state._resolveLocalAudioPath(
        request.sketchId,
        request.audioUrl,
      );
      final audioBytes = await File(sourcePath).readAsBytes();

      _setJobState(
        state,
        request.sketchId,
        const _ConversionJobState(
          status: _ConversionStatus.running,
          message: 'Converting to MIDI...',
          progress: 0.45,
        ),
      );
      final midiBytes = await state._convertWithBasicPitch(audioBytes);
      _setJobState(
        state,
        request.sketchId,
        const _ConversionJobState(
          status: _ConversionStatus.running,
          message: 'Waiting for preview confirmation...',
          progress: 0.60,
        ),
      );
      final editedMidiBytes = await state._openMidiEditor(
        midiBytes,
        tempoOverrideBpm: state._lockTempo ? state._parseTempoBpm() : null,
        meterOverride: state._lockMeter ? (state._parseMeter()) : null,
        keyScaleConstraint: state._constrainToScale
            ? KeyScaleConstraint(
                tonic: state._keyNameToPitchClass(state._selectedKey),
                isMinor: state._selectedScale == 'Minor',
              )
            : null,
        sourceAudioPath: sourcePath,
      );
      if (editedMidiBytes == null) {
        _setJobState(
          state,
          request.sketchId,
          const _ConversionJobState(
            status: _ConversionStatus.failed,
            message: 'Canceled in preview',
            progress: 1.0,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (state.mounted) {
          state._applyState(
            () => state._conversionJobs.remove(request.sketchId),
          );
        }
        return;
      }
      final processedMidiBytes = _postProcessGeneratedMidi(
        state,
        editedMidiBytes,
      );

      _setJobState(
        state,
        request.sketchId,
        const _ConversionJobState(
          status: _ConversionStatus.running,
          message: 'Uploading result...',
          progress: 0.82,
        ),
      );
      final midiFileName = state._storageMidiFileName(
        sketchId: request.sketchId,
      );
      final midiStoragePath = state._storagePathForUserFile(midiFileName);
      await Supabase.instance.client.storage
          .from('audio-samples')
          .uploadBinary(
            midiStoragePath,
            processedMidiBytes,
            fileOptions: const FileOptions(
              contentType: 'audio/midi',
              upsert: true,
            ),
          );
      final midiUrl = Supabase.instance.client.storage
          .from('audio-samples')
          .getPublicUrl(midiStoragePath);
      await Supabase.instance.client
          .from('sketches')
          .update({
            'title':
                '🎵 MIDI: ${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}',
            'audio_path': midiUrl,
          })
          .match(state._ownedSketchFilter(request.sketchId));
      await Supabase.instance.client
          .from('sketches')
          .update({
            'title':
                state._sketchTitleById(request.sketchId) ??
                'Recording ${request.sketchId}',
            'status': 'ready',
            'last_error': null,
          })
          .match(state._ownedSketchFilter(request.sketchId));

      _setJobState(
        state,
        request.sketchId,
        const _ConversionJobState(
          status: _ConversionStatus.done,
          message: 'Conversion complete',
          progress: 1.0,
        ),
      );
      state._triggerJumpingNotes();
      if (state.mounted) {
        final sessionIndex = state._sessionSketches.indexWhere(
          (item) => item['id'] == request.sketchId,
        );
        if (sessionIndex >= 0) {
          state._sessionSketches[sessionIndex] = {
            ...state._sessionSketches[sessionIndex],
            'audio_path': request.audioUrl,
            '_local_audio_path': sourcePath,
            'status': 'ready',
            'last_error': null,
          };
          state._cachedAudioPathBySketchId[request.sketchId] = sourcePath;
          state._showSessionSketches();
          unawaited(
            state.getSketches().then((_) => state._showSessionSketches()),
          );
        } else {
          state._refreshSketches();
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (state.mounted) {
        state._applyState(() => state._conversionJobs.remove(request.sketchId));
      }
    } catch (e) {
      unawaited(
        Supabase.instance.client
            .from('sketches')
            .update({'status': 'failed', 'last_error': e.toString()})
            .match(state._ownedSketchFilter(request.sketchId)),
      );
      _setJobState(
        state,
        request.sketchId,
        _ConversionJobState(
          status: _ConversionStatus.failed,
          message: 'Failed: $e',
          progress: 1.0,
        ),
      );
    }
  }

  static bool _isMidiSource(String pathOrUrl) {
    final value = pathOrUrl.toLowerCase();
    return value.endsWith('.mid') || value.endsWith('.midi');
  }

  static Future<Uint8List> _downloadOrReadBytes(String pathOrUrl) async {
    final localFile = File(pathOrUrl);
    if (await localFile.exists()) {
      return localFile.readAsBytes();
    }
    final response = await http.get(Uri.parse(pathOrUrl));
    if (response.statusCode != 200) {
      throw Exception('Could not fetch file (${response.statusCode})');
    }
    return response.bodyBytes;
  }

  static Uint8List _postProcessGeneratedMidi(
    _MyHomePageState state,
    Uint8List midiBytes,
  ) {
    final parsed = ParsedMidi.tryParse(midiBytes);
    if (parsed == null || parsed.notes.isEmpty) return midiBytes;
    final notes = parsed.notes.map((n) => EditableMidiNote.copy(n)).toList()
      ..sort((a, b) => a.startTick.compareTo(b.startTick));
    final firstTick = notes.map((n) => n.startTick).reduce(math.min);
    for (final note in notes) {
      note.startTick = math.max(0, note.startTick - firstTick);
    }
    if (state._constrainToScale) {
      final tonic = state._keyNameToPitchClass(state._selectedKey);
      final allowed = state._selectedScale == 'Minor'
          ? <int>{0, 2, 3, 5, 7, 8, 10}
          : <int>{0, 2, 4, 5, 7, 9, 11};
      int? previousRaw;
      int? previousConstrained;
      for (final note in notes) {
        final raw = note.note;
        final constrained = _closestNoteInScale(
          raw,
          tonic,
          allowed,
          previousRaw: previousRaw,
          previousConstrained: previousConstrained,
        );
        note.note = constrained;
        previousRaw = raw;
        previousConstrained = constrained;
      }
    }
    final meter = state._lockMeter ? state._parseMeter() : null;
    final tempo = state._lockTempo ? state._parseTempoBpm() : null;
    return parsed.rebuild(
      notes,
      tempoOverrideBpm: tempo,
      beatsPerMeasureOverride: meter?.beatsPerMeasure,
      beatUnitOverride: meter?.beatUnit,
    );
  }

  static int _closestNoteInScale(
    int midiNote,
    int tonic,
    Set<int> scale, {
    int? previousRaw,
    int? previousConstrained,
  }) {
    var best = midiNote;
    var bestScore = 1 << 30;
    for (var delta = -6; delta <= 6; delta++) {
      final candidate = (midiNote + delta).clamp(0, 127);
      final pitchClass = ((candidate - tonic) % 12 + 12) % 12;
      if (!scale.contains(pitchClass)) continue;

      var score = (candidate - midiNote).abs() * 10;
      if (previousRaw != null && previousConstrained != null) {
        final rawDir = (midiNote - previousRaw).sign;
        final constrainedDir = (candidate - previousConstrained).sign;
        if (rawDir != 0 && constrainedDir != 0 && rawDir != constrainedDir) {
          score += 8;
        }
        if ((candidate - previousConstrained).abs() > 12) {
          score += 5;
        }
      }

      if (score < bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    return best;
  }

  static void _setJobState(
    _MyHomePageState state,
    int sketchId,
    _ConversionJobState jobState,
  ) {
    if (!state.mounted) return;
    state._applyState(() => state._conversionJobs[sketchId] = jobState);
  }
}
