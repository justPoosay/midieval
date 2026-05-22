part of 'package:midieval/app.dart';

class MidiEditorDialog extends StatefulWidget {
  const MidiEditorDialog({
    super.key,
    required this.parsed,
    required this.tempoOverrideBpm,
    required this.beatsPerMeasureOverride,
    required this.beatUnitOverride,
    this.keyScaleConstraint,
    this.sourceAudioPath,
    this.sourceAudioPlayer,
    this.tutorialMode = false,
    this.onTutorialCompleted,
  });

  final ParsedMidi parsed;
  final int tempoOverrideBpm;
  final int beatsPerMeasureOverride;
  final int beatUnitOverride;
  final KeyScaleConstraint? keyScaleConstraint;
  final String? sourceAudioPath;
  final AudioPlayer? sourceAudioPlayer;
  final bool tutorialMode;
  final VoidCallback? onTutorialCompleted;

  @override
  State<MidiEditorDialog> createState() => _MidiEditorDialogState();
}

class _MidiEditorDialogState extends State<MidiEditorDialog> {
  late List<EditableMidiNote> _notes;
  late int _rollMinNote;
  late int _rollMaxNote;
  int _selectedIndex = -1;
  int _gridDivider = 4;
  final bool _showConfidenceHeatmap = false;
  final List<List<EditableMidiNote>> _undoStack = [];
  final List<List<EditableMidiNote>> _redoStack = [];
  bool _isPreviewPlaying = false;
  double _playheadTick = 0;
  Timer? _previewTimer;
  AudioPlayer? _previewAudioPlayer;
  bool _ownsPreviewAudioPlayer = false;
  Future<void>? _previewAudioReady;
  Duration _previewAudioLeadingSilence = Duration.zero;
  Duration? _previewAudioDuration;
  late int _timelineTickEnd;
  int? _erasePointer;
  final Set<int> _erasedIndices = <int>{};
  _MoveDragContext? _moveDrag;
  _ResizeDragContext? _resizeDrag;
  int _tutorialEditorStep = 0;

  @override
  void initState() {
    super.initState();
    _notes = widget.parsed.notes.map((n) => EditableMidiNote.copy(n)).toList()
      ..sort((a, b) => a.startTick.compareTo(b.startTick));
    _rollMinNote = _notes.isEmpty
        ? 48
        : (_notes.map((e) => e.note).reduce(math.min) - 2).clamp(0, 127);
    _rollMaxNote = _notes.isEmpty
        ? 72
        : (_notes.map((e) => e.note).reduce(math.max) + 2).clamp(0, 127);
    if (_rollMaxNote <= _rollMinNote) {
      _rollMinNote = 48;
      _rollMaxNote = 72;
    }
    _alignNotesToStart(_notes);
    _timelineTickEnd = _initialTimelineTickEnd(_notes);
    if (widget.keyScaleConstraint != null) {
      _constrainNotesToScale(_notes, widget.keyScaleConstraint!);
    }
    if (widget.sourceAudioPath != null) {
      _previewAudioReady = _preparePreviewAudio(widget.sourceAudioPath!);
    }
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    if (_ownsPreviewAudioPlayer) {
      unawaited(_previewAudioPlayer?.dispose());
    } else {
      unawaited(_previewAudioPlayer?.stop());
    }
    super.dispose();
  }

  void _deleteSelected() {
    if (_selectedIndex < 0 || _selectedIndex >= _notes.length) return;
    _commitUndoState();
    setState(() {
      _notes.removeAt(_selectedIndex);
      _selectedIndex = -1;
      _stopPreviewIfOutOfRange();
    });
  }

  void _quantizeAll() {
    _commitUndoState();
    if (_notes.isEmpty) return;
    setState(() {
      _intelligentQuantize();
      _notes.sort((a, b) => a.startTick.compareTo(b.startTick));
      _ensureTimelineCoversAll();
      _stopPreviewIfOutOfRange();
      if (widget.tutorialMode && _tutorialEditorStep == 0) {
        _tutorialEditorStep = 1;
      }
    });
  }

  void _advanceTutorialEditorStep() {
    if (!widget.tutorialMode) return;
    if (_tutorialEditorStep >= 4) {
      widget.onTutorialCompleted?.call();
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() => _tutorialEditorStep++);
  }

  void _onTutorialEditObserved() {
    if (!widget.tutorialMode) return;
    if (_tutorialEditorStep < 3) {
      _tutorialEditorStep = 3;
    }
  }

  void _intelligentQuantize() {
    final tpq = widget.parsed.ticksPerQuarter;
    final measureTicks =
        ((tpq * 4 * widget.beatsPerMeasureOverride) / widget.beatUnitOverride)
            .round()
            .clamp(1, 1 << 30);
    final beatTicks = ((tpq * 4) / widget.beatUnitOverride).round().clamp(
      1,
      1 << 30,
    );
    final candidateSteps = _candidateOnsetSteps(tpq);
    final onsetStep = _bestOnsetStep(candidateSteps);
    final gridPhase = _bestGridPhase(
      onsetStep: onsetStep,
      measureTicks: measureTicks,
      beatTicks: beatTicks,
    );
    final durationValues = _candidateDurations(tpq);

    for (var i = 0; i < _notes.length; i++) {
      final note = _notes[i];
      final quantizedStart = _snapToGridWithPhase(
        note.startTick,
        onsetStep,
        gridPhase,
      );

      final rawEnd = note.startTick + note.durationTicks;
      final suggestedEnd = i < _notes.length - 1
          ? _snapToGridWithPhase(_notes[i + 1].startTick, onsetStep, gridPhase)
          : _snapToGridWithPhase(rawEnd, onsetStep, gridPhase);
      var targetDuration = math.max(1, suggestedEnd - quantizedStart);
      targetDuration = _closestDuration(targetDuration, durationValues);

      if (i < _notes.length - 1) {
        final nextStart = _snapToGridWithPhase(
          _notes[i + 1].startTick,
          onsetStep,
          gridPhase,
        );
        targetDuration = math.min(
          targetDuration,
          math.max(1, nextStart - quantizedStart),
        );
      }

      note.startTick = math.max(0, quantizedStart);
      note.durationTicks = math.max(onsetStep, targetDuration);
    }

    _regularizeSteadyRuns(
      onsetStep: onsetStep,
      durationValues: durationValues,
      gridPhase: gridPhase,
    );

    // Keep measure boundaries clean.
    for (final note in _notes) {
      final barStart = (note.startTick ~/ measureTicks) * measureTicks;
      final barEnd = barStart + measureTicks;
      if (note.startTick + note.durationTicks > barEnd + onsetStep) {
        note.durationTicks = math.max(onsetStep, barEnd - note.startTick);
      }
    }
  }

  void _regularizeSteadyRuns({
    required int onsetStep,
    required List<int> durationValues,
    required int gridPhase,
  }) {
    if (_notes.length < 3) return;
    if (_hasStrongPolyphony()) return;

    final intervals = <int>[];
    for (var i = 1; i < _notes.length; i++) {
      intervals.add(
        math.max(onsetStep, _notes[i].startTick - _notes[i - 1].startTick),
      );
    }
    if (intervals.isEmpty) return;

    final snappedIntervals = intervals
        .map((i) => _closestDuration(i, durationValues))
        .toList();
    final dominantInterval = _modeInt(snappedIntervals);
    if (dominantInterval <= 0) return;

    final tolerance = math.max(onsetStep, (dominantInterval * 0.35).round());
    var runStart = 0;
    for (var i = 1; i < _notes.length; i++) {
      final gap = _notes[i].startTick - _notes[i - 1].startTick;
      final inRun = (gap - dominantInterval).abs() <= tolerance;
      if (!inRun) {
        _regularizeRun(runStart, i - 1, dominantInterval, onsetStep, gridPhase);
        runStart = i;
      }
    }
    _regularizeRun(
      runStart,
      _notes.length - 1,
      dominantInterval,
      onsetStep,
      gridPhase,
    );
  }

  bool _hasStrongPolyphony() {
    var overlaps = 0;
    for (var i = 1; i < _notes.length; i++) {
      final prevEnd = _notes[i - 1].startTick + _notes[i - 1].durationTicks;
      if (_notes[i].startTick < prevEnd - _gridTick()) overlaps++;
    }
    return overlaps > (_notes.length * 0.2).round();
  }

  void _regularizeRun(
    int startIndex,
    int endIndex,
    int step,
    int onsetStep,
    int gridPhase,
  ) {
    final runLength = endIndex - startIndex + 1;
    if (runLength < 3) return;
    final anchor = _snapToGridWithPhase(
      _notes[startIndex].startTick,
      onsetStep,
      gridPhase,
    );
    for (var i = 0; i < runLength; i++) {
      final note = _notes[startIndex + i];
      note.startTick = anchor + (i * step);
      note.durationTicks = step;
    }
  }

  int _bestGridPhase({
    required int onsetStep,
    required int measureTicks,
    required int beatTicks,
  }) {
    final phases = <int>{0};
    final slotsPerBar = math.max(1, measureTicks ~/ onsetStep);
    for (var i = 0; i < slotsPerBar; i++) {
      phases.add(i * onsetStep);
    }

    var bestPhase = 0;
    var bestScore = double.infinity;
    for (final phase in phases) {
      var score = 0.0;
      for (final note in _notes) {
        final snapped = _snapToGridWithPhase(note.startTick, onsetStep, phase);
        score += (note.startTick - snapped).abs();

        // Prefer beat-aligned subdivisions inside the selected meter.
        final snappedInBar =
            ((snapped % measureTicks) + measureTicks) % measureTicks;
        final beatDistance = _distanceToNearestMultiple(
          snappedInBar,
          beatTicks,
        );
        score += beatDistance * 0.08;
      }
      if (score < bestScore) {
        bestScore = score;
        bestPhase = phase;
      }
    }
    return bestPhase;
  }

  int _distanceToNearestMultiple(int value, int step) {
    if (step <= 0) return 0;
    final down = (value ~/ step) * step;
    final up = down + step;
    return math.min((value - down).abs(), (up - value).abs());
  }

  int _snapToGridWithPhase(int value, int grid, int phase) {
    if (grid <= 0) return value;
    final shifted = value - phase;
    return ((shifted / grid).round() * grid) + phase;
  }

  int _modeInt(List<int> values) {
    final buckets = <int, int>{};
    for (final v in values) {
      buckets[v] = (buckets[v] ?? 0) + 1;
    }
    var bestValue = values.first;
    var bestCount = -1;
    for (final entry in buckets.entries) {
      if (entry.value > bestCount) {
        bestValue = entry.key;
        bestCount = entry.value;
      }
    }
    return bestValue;
  }

  List<int> _candidateOnsetSteps(int tpq) {
    final whole = tpq * 4;
    final steps = <int>{
      math.max(1, (whole / 32).round()),
      math.max(1, (whole / 24).round()),
      math.max(1, (whole / 16).round()),
      math.max(1, (whole / 12).round()),
      math.max(1, (whole / 8).round()),
      math.max(1, (whole / 6).round()),
      math.max(1, (whole / 4).round()),
    };
    return steps.toList()..sort();
  }

  int _bestOnsetStep(List<int> candidates) {
    if (_notes.length < 2) return candidates.first;
    var bestStep = candidates.first;
    var bestScore = double.infinity;
    for (final step in candidates) {
      var score = 0.0;
      for (final note in _notes) {
        final snapped = _snapToGrid(note.startTick, step);
        score += (note.startTick - snapped).abs();
      }
      for (var i = 1; i < _notes.length; i++) {
        final interval = _notes[i].startTick - _notes[i - 1].startTick;
        final snappedInterval = _snapToGrid(interval, step);
        score += (interval - snappedInterval).abs() * 0.75;
      }
      if (score < bestScore) {
        bestScore = score;
        bestStep = step;
      }
    }
    return bestStep;
  }

  List<int> _candidateDurations(int tpq) {
    final whole = tpq * 4;
    final fractions = <double>[
      1 / 32,
      1 / 16,
      3 / 32,
      1 / 8,
      3 / 16,
      1 / 4,
      3 / 8,
      1 / 2,
      3 / 4,
      1.0,
    ];
    final durations =
        fractions.map((f) => math.max(1, (whole * f).round())).toSet().toList()
          ..sort();
    return durations;
  }

  int _closestDuration(int value, List<int> candidates) {
    var best = candidates.first;
    var bestDist = (value - best).abs();
    for (final c in candidates.skip(1)) {
      final dist = (value - c).abs();
      if (dist < bestDist) {
        best = c;
        bestDist = dist;
      }
    }
    return best;
  }

  int _snapToGrid(int value, int grid) {
    if (grid <= 0) return value;
    return (value / grid).round() * grid;
  }

  int _gridTick() {
    return math.max(1, (widget.parsed.ticksPerQuarter / _gridDivider).round());
  }

  int _snapTick(int tick) {
    final grid = _gridTick();
    return (tick / grid).round() * grid;
  }

  int _newNoteDurationTicks() {
    final grid = _gridTick();
    if (_selectedIndex < 0 || _selectedIndex >= _notes.length) {
      return grid;
    }
    return math.max(grid, _notes[_selectedIndex].durationTicks);
  }

  int _noteIndexAtPosition(
    Offset localPosition, {
    required int maxNote,
    required double laneHeight,
    required double tickScale,
  }) {
    final tick = (localPosition.dx / tickScale).round();
    final noteValue = (maxNote - (localPosition.dy / laneHeight).floor()).clamp(
      0,
      127,
    );
    return _notes.indexWhere((n) {
      final end = n.startTick + n.durationTicks;
      return noteValue == n.note && tick >= n.startTick && tick <= end;
    });
  }

  void _addNoteAtPosition(
    Offset localPosition, {
    required int maxNote,
    required double laneHeight,
    required double tickScale,
  }) {
    final hitIndex = _noteIndexAtPosition(
      localPosition,
      maxNote: maxNote,
      laneHeight: laneHeight,
      tickScale: tickScale,
    );
    if (hitIndex >= 0) {
      _selectedIndex = hitIndex;
      return;
    }

    _commitUndoState();
    final startTick = _snapTick(
      math.max(0, (localPosition.dx / tickScale).round()),
    );
    final noteValue = (maxNote - (localPosition.dy / laneHeight).floor()).clamp(
      0,
      127,
    );
    final newNote = EditableMidiNote(
      note: noteValue,
      startTick: startTick,
      durationTicks: _newNoteDurationTicks(),
      velocity: 100,
    );
    _notes.add(newNote);
    _notes.sort((a, b) => a.startTick.compareTo(b.startTick));
    _selectedIndex = _notes.indexOf(newNote);
    _ensureTimelineCoversAll();
    _onTutorialEditObserved();
  }

  String _tutorialEditorHint(BuildContext context) {
    switch (_tutorialEditorStep) {
      case 0:
        return 'MIDI Preview: top toolbar actions (delete/undo/redo/grid)';
      case 1:
        return 'MIDI Preview: play/rewind transport controls';
      case 2:
        return 'MIDI Preview: piano roll grid and timeline';
      case 3:
        return 'MIDI Preview: note blocks (drag, resize, double-click add)';
      default:
        return 'MIDI Preview: press Apply when your edits are done';
    }
  }

  int _initialTimelineTickEnd(List<EditableMidiNote> notes) {
    final defaultTicks = widget.parsed.ticksPerQuarter * 4;
    if (notes.isEmpty) return defaultTicks;
    final noteEnd = notes
        .map((e) => e.startTick + e.durationTicks)
        .reduce(math.max);
    return math.max(defaultTicks, noteEnd + widget.parsed.ticksPerQuarter);
  }

  void _ensureTimelineCoversAll() {
    final computed = _initialTimelineTickEnd(_notes);
    if (computed > _timelineTickEnd) {
      _timelineTickEnd = computed;
    }
  }

  void _stopPreviewIfOutOfRange() {
    if (_playheadTick <= _timelineTickEnd) return;
    _previewTimer?.cancel();
    _isPreviewPlaying = false;
    _playheadTick = _timelineTickEnd.toDouble();
  }

  void _startMoveDrag(
    int index,
    DragStartDetails details,
    double tickScale,
    double laneHeight,
  ) {
    _commitUndoState();
    _moveDrag = _MoveDragContext(
      index: index,
      startGlobal: details.globalPosition,
      startTick: _notes[index].startTick,
      startNote: _notes[index].note,
      tickScale: tickScale,
      laneHeight: laneHeight,
    );
  }

  void _updateMoveDrag(int index, DragUpdateDetails details) {
    final ctx = _moveDrag;
    if (ctx == null || ctx.index != index) return;
    final note = _notes[index];
    final rawTickDelta =
        ((details.globalPosition.dx - ctx.startGlobal.dx) / ctx.tickScale)
            .round();
    final rawPitchDelta =
        ((details.globalPosition.dy - ctx.startGlobal.dy) / ctx.laneHeight)
            .round();
    note.startTick = math.max(0, ctx.startTick + rawTickDelta);
    note.note = (ctx.startNote - rawPitchDelta).clamp(0, 127);
    _ensureTimelineCoversAll();
    _onTutorialEditObserved();
  }

  void _endMoveDrag(int index) {
    final ctx = _moveDrag;
    if (ctx == null || ctx.index != index) return;
    final note = _notes[index];
    note.startTick = _snapTick(math.max(0, note.startTick));
    _moveDrag = null;
  }

  void _startResizeDrag(
    int index,
    DragStartDetails details,
    _ResizeEdge edge,
    double tickScale,
  ) {
    _commitUndoState();
    _resizeDrag = _ResizeDragContext(
      index: index,
      edge: edge,
      startGlobal: details.globalPosition,
      startTick: _notes[index].startTick,
      startDuration: _notes[index].durationTicks,
      tickScale: tickScale,
    );
  }

  void _updateResizeDrag(int index, DragUpdateDetails details) {
    final ctx = _resizeDrag;
    if (ctx == null || ctx.index != index) return;
    final note = _notes[index];
    final grid = _gridTick();
    final tickDelta =
        ((details.globalPosition.dx - ctx.startGlobal.dx) / ctx.tickScale)
            .round();
    if (ctx.edge == _ResizeEdge.left) {
      final originalEnd = ctx.startTick + ctx.startDuration;
      var newStart = math.max(0, ctx.startTick + tickDelta);
      if (originalEnd - newStart < grid) {
        newStart = originalEnd - grid;
      }
      note.startTick = math.max(0, newStart);
      note.durationTicks = math.max(grid, originalEnd - note.startTick);
    } else {
      final newDuration = math.max(grid, ctx.startDuration + tickDelta);
      note.durationTicks = newDuration;
    }
    _ensureTimelineCoversAll();
    _onTutorialEditObserved();
  }

  void _endResizeDrag(int index) {
    final ctx = _resizeDrag;
    if (ctx == null || ctx.index != index) return;
    final note = _notes[index];
    final grid = _gridTick();
    if (ctx.edge == _ResizeEdge.left) {
      final endTick = note.startTick + note.durationTicks;
      var snappedStart = _snapTick(note.startTick);
      if (endTick - snappedStart < grid) {
        snappedStart = endTick - grid;
      }
      note.startTick = math.max(0, snappedStart);
      note.durationTicks = math.max(grid, endTick - note.startTick);
    } else {
      note.durationTicks = math.max(grid, _snapTick(note.durationTicks));
    }
    _resizeDrag = null;
  }

  Future<void> _togglePreviewPlayback(int tickEnd) async {
    if (_isPreviewPlaying) {
      _previewTimer?.cancel();
      await _previewAudioPlayer?.stop();
      if (mounted) {
        setState(() => _isPreviewPlaying = false);
      }
      return;
    }
    final ticksPerSecond =
        (widget.parsed.ticksPerQuarter * widget.tempoOverrideBpm) / 60.0;
    if (ticksPerSecond <= 0) return;
    final maxTick = math.max(1, tickEnd);
    if (_playheadTick >= maxTick) _playheadTick = 0;
    if (_previewAudioReady != null) {
      await _previewAudioReady;
    }
    _previewTimer?.cancel();
    final audioStarted = await _startPreviewAudio(ticksPerSecond);
    if (widget.sourceAudioPath != null && !audioStarted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not play the source recording preview.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _isPreviewPlaying = true;
    });
    _previewTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        final previousTick = _playheadTick;
        _playheadTick += ticksPerSecond * 0.016;
        if (_previewAudioPlayer == null) {
          _triggerNotesBetween(previousTick, _playheadTick);
        }
        if (_playheadTick >= maxTick) {
          _playheadTick = maxTick.toDouble();
          _isPreviewPlaying = false;
          timer.cancel();
          unawaited(_previewAudioPlayer?.stop());
        }
      });
    });
  }

  Future<void> _rewindPreview() async {
    _previewTimer?.cancel();
    await _previewAudioPlayer?.stop();
    if (!mounted) return;
    setState(() {
      _isPreviewPlaying = false;
      _playheadTick = 0;
    });
  }

  Future<void> _preparePreviewAudio(String sourceAudioPath) async {
    try {
      final audioFile = File(sourceAudioPath);
      if (!await audioFile.exists()) return;
      final trim = await _detectLeadingSilence(sourceAudioPath);
      if (!mounted) return;
      _previewAudioPlayer = widget.sourceAudioPlayer ?? AudioPlayer();
      _ownsPreviewAudioPlayer = widget.sourceAudioPlayer == null;
      await _previewAudioPlayer!.setReleaseMode(ReleaseMode.stop);
      _previewAudioLeadingSilence = trim.leadingSilence;
      _previewAudioDuration = trim.duration;
    } catch (e) {
      debugPrint('Could not prepare audio-backed MIDI preview: $e');
    }
  }

  Future<bool> _startPreviewAudio(double ticksPerSecond) async {
    final player = _previewAudioPlayer;
    final sourceAudioPath = widget.sourceAudioPath;
    if (sourceAudioPath == null) return true;
    if (player == null) return false;

    final playheadSeconds = _playheadTick / ticksPerSecond;
    var position =
        _previewAudioLeadingSilence +
        Duration(milliseconds: (playheadSeconds * 1000).round());
    final duration = _previewAudioDuration;
    if (duration != null && position >= duration) {
      position = _previewAudioLeadingSilence;
      _playheadTick = 0;
    }
    try {
      await player.stop();
      await player.setPlayerMode(PlayerMode.mediaPlayer);
      await player.setVolume(1);
      await player.setSourceDeviceFile(sourceAudioPath);
      if (position > Duration.zero) {
        await player.seek(position);
      }
      await player.resume();
      return true;
    } catch (e) {
      debugPrint('Could not start audio-backed MIDI preview: $e');
      await player.stop();
      _previewAudioPlayer = null;
      return false;
    }
  }

  void _triggerNotesBetween(double fromTick, double toTick) {
    for (final note in _notes) {
      final start = note.startTick.toDouble();
      if (start > fromTick && start <= toTick) {
        unawaited(_playLiveNote(note));
      }
    }
  }

  Future<void> _playLiveNote(EditableMidiNote note) async {
    // Disabled for now: experimental live preview synthesis on Windows.
    // Keeping implementation for future iteration.
    return;
  }

  Future<_PreviewAudioTrim> _detectLeadingSilence(String path) async {
    final bytes = await File(path).readAsBytes();
    final wav = _PreviewWavData.tryParse(bytes);
    if (wav == null || wav.frameCount <= 0) {
      return const _PreviewAudioTrim(
        leadingSilence: Duration.zero,
        duration: null,
      );
    }

    final totalDuration = Duration(
      microseconds: ((wav.frameCount / wav.sampleRate) * 1000000).round(),
    );
    final windowFrames = math.max(1, (wav.sampleRate * 0.015).round());
    final hopFrames = math.max(1, (wav.sampleRate * 0.005).round());
    final rmsValues = <double>[];
    var peakRms = 0.0;

    for (
      var startFrame = 0;
      startFrame < wav.frameCount;
      startFrame += hopFrames
    ) {
      final endFrame = math.min(wav.frameCount, startFrame + windowFrames);
      var sumSquares = 0.0;
      var sampleCount = 0;
      for (var frame = startFrame; frame < endFrame; frame++) {
        for (var channel = 0; channel < wav.channels; channel++) {
          final sample = wav.sampleAt(frame, channel);
          sumSquares += sample * sample;
          sampleCount++;
        }
      }
      final rms = sampleCount == 0 ? 0.0 : math.sqrt(sumSquares / sampleCount);
      rmsValues.add(rms);
      peakRms = math.max(peakRms, rms);
    }

    if (peakRms <= 0.0001 || rmsValues.isEmpty) {
      return _PreviewAudioTrim(
        leadingSilence: Duration.zero,
        duration: totalDuration,
      );
    }

    final noiseWindowCount = math.max(
      1,
      math.min(rmsValues.length, (0.25 / 0.005).round()),
    );
    final noiseFloor = rmsValues
        .take(noiseWindowCount)
        .fold<double>(0.0, math.max);
    final threshold = math.max(noiseFloor * 3.0, peakRms * 0.035);
    final sustainWindows = math.max(2, (0.030 / 0.005).round());
    var onsetWindow = 0;

    for (var i = 0; i < rmsValues.length; i++) {
      var sustained = true;
      for (var j = 0; j < sustainWindows; j++) {
        final index = i + j;
        if (index >= rmsValues.length || rmsValues[index] < threshold) {
          sustained = false;
          break;
        }
      }
      if (sustained) {
        onsetWindow = i;
        break;
      }
    }

    final onsetFrame = (onsetWindow * hopFrames).clamp(0, wav.frameCount);
    final leadingSilence = Duration(
      microseconds: ((onsetFrame / wav.sampleRate) * 1000000).round(),
    );
    return _PreviewAudioTrim(
      leadingSilence: leadingSilence,
      duration: totalDuration,
    );
  }

  // ignore: unused_element
  Future<void> _playLiveNoteExperimentalWindowsTone(
    EditableMidiNote note,
  ) async {
    // Windows fallback preview synth without plugin channels:
    // trigger a simple tone per note in a detached process.
    if (!Platform.isWindows) return;
    final freq = (440.0 * math.pow(2.0, (note.note - 69) / 12.0)).round().clamp(
      37,
      32767,
    );
    final durationMs =
        (((note.durationTicks / widget.parsed.ticksPerQuarter) *
                    (60.0 / widget.tempoOverrideBpm)) *
                1000)
            .round()
            .clamp(30, 900);
    try {
      await Process.start('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-WindowStyle',
        'Hidden',
        '-Command',
        '[console]::beep($freq,$durationMs)',
      ]);
    } catch (_) {
      // Keep transport alive if tone triggering fails.
    }
  }

  void _eraseAtPosition(
    Offset localPosition, {
    required int maxNote,
    required double laneHeight,
    required double tickScale,
  }) {
    final tick = (localPosition.dx / tickScale).round();
    final noteValue = maxNote - (localPosition.dy / laneHeight).floor();
    final idx = _notes.indexWhere((n) {
      final end = n.startTick + n.durationTicks;
      return noteValue == n.note && tick >= n.startTick && tick <= end;
    });
    if (idx < 0 || _erasedIndices.contains(idx)) return;
    _erasedIndices.add(idx);
    _notes.removeAt(idx);
    if (_selectedIndex == idx) _selectedIndex = -1;
  }

  void _commitUndoState() {
    _undoStack.add(_notes.map((n) => EditableMidiNote.copy(n)).toList());
    if (_undoStack.length > 80) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(_notes.map((n) => EditableMidiNote.copy(n)).toList());
      _notes = _undoStack
          .removeLast()
          .map((n) => EditableMidiNote.copy(n))
          .toList();
      _ensureTimelineCoversAll();
      _stopPreviewIfOutOfRange();
      if (_selectedIndex >= _notes.length) _selectedIndex = -1;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_notes.map((n) => EditableMidiNote.copy(n)).toList());
      _notes = _redoStack
          .removeLast()
          .map((n) => EditableMidiNote.copy(n))
          .toList();
      _ensureTimelineCoversAll();
      _stopPreviewIfOutOfRange();
      if (_selectedIndex >= _notes.length) _selectedIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final isCompact = screen.width < 700;
    final dialogWidth = isCompact ? screen.width * 0.92 : 760.0;
    final dialogHeight = isCompact ? screen.height * 0.62 : 420.0;
    final minNote = _rollMinNote;
    final maxNote = _rollMaxNote;
    final tickEnd = _timelineTickEnd;

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyZ, control: true): UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
            RedoIntent(),
        SingleActivator(LogicalKeyboardKey.space): PlayPreviewIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (intent) {
              _undo();
              return null;
            },
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (intent) {
              _redo();
              return null;
            },
          ),
          PlayPreviewIntent: CallbackAction<PlayPreviewIntent>(
            onInvoke: (intent) {
              unawaited(_togglePreviewPlayback(tickEnd));
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: AlertDialog(
            insetPadding: isCompact
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 16)
                : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            title: const Text('Edit MIDI'),
            content: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _selectedIndex >= 0
                              ? _deleteSelected
                              : null,
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete note',
                        ),
                        IconButton(
                          onPressed: _undoStack.isNotEmpty ? _undo : null,
                          icon: const Icon(Icons.undo),
                          tooltip: 'Undo',
                        ),
                        IconButton(
                          onPressed: _redoStack.isNotEmpty ? _redo : null,
                          icon: const Icon(Icons.redo),
                          tooltip: 'Redo',
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: _gridDivider,
                          items: const [
                            DropdownMenuItem(value: 4, child: Text('1/4')),
                            DropdownMenuItem(value: 3, child: Text('1/3')),
                            DropdownMenuItem(value: 6, child: Text('1/6')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _gridDivider = value);
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () =>
                              unawaited(_togglePreviewPlayback(tickEnd)),
                          icon: Icon(
                            _isPreviewPlaying ? Icons.stop : Icons.play_arrow,
                          ),
                          tooltip: 'Play/Pause (Space)',
                        ),
                        IconButton(
                          onPressed: () => unawaited(_rewindPreview()),
                          icon: const Icon(Icons.replay),
                          tooltip: 'Rewind to start',
                        ),
                        const SizedBox(width: 4),
                        FilledButton.tonal(
                          onPressed: _quantizeAll,
                          child: const Text('Quantize'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: AbsorbPointer(
                      absorbing: widget.tutorialMode,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final noteSpan = math.max(12, maxNote - minNote + 1);
                          final laneHeight = constraints.maxHeight / noteSpan;
                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF111216),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: LayoutBuilder(
                              builder: (context, inner) {
                                final tickScale =
                                    inner.maxWidth / math.max(1, tickEnd);
                                final barTicks =
                                    ((widget.parsed.ticksPerQuarter *
                                                4 *
                                                widget
                                                    .beatsPerMeasureOverride) /
                                            widget.beatUnitOverride)
                                        .round();
                                final beatTicks =
                                    ((widget.parsed.ticksPerQuarter * 4) /
                                            widget.beatUnitOverride)
                                        .round();
                                return Listener(
                                  onPointerDown: (event) {
                                    if ((event.buttons &
                                            kSecondaryMouseButton) !=
                                        0) {
                                      _commitUndoState();
                                      setState(() {
                                        _erasePointer = event.pointer;
                                        _erasedIndices.clear();
                                        _eraseAtPosition(
                                          event.localPosition,
                                          maxNote: maxNote,
                                          laneHeight: laneHeight,
                                          tickScale: tickScale,
                                        );
                                      });
                                    }
                                  },
                                  onPointerMove: (event) {
                                    if (_erasePointer == event.pointer &&
                                        (event.buttons &
                                                kSecondaryMouseButton) !=
                                            0) {
                                      setState(() {
                                        _eraseAtPosition(
                                          event.localPosition,
                                          maxNote: maxNote,
                                          laneHeight: laneHeight,
                                          tickScale: tickScale,
                                        );
                                      });
                                    }
                                  },
                                  onPointerUp: (event) {
                                    if (_erasePointer == event.pointer) {
                                      setState(() {
                                        _erasePointer = null;
                                        _erasedIndices.clear();
                                      });
                                    }
                                  },
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onDoubleTapDown: (details) {
                                      setState(() {
                                        _addNoteAtPosition(
                                          details.localPosition,
                                          maxNote: maxNote,
                                          laneHeight: laneHeight,
                                          tickScale: tickScale,
                                        );
                                      });
                                    },
                                    child: Stack(
                                      children: [
                                        for (
                                          var tick = 0;
                                          tick <= tickEnd;
                                          tick += _gridTick()
                                        )
                                          Positioned(
                                            left: tick * tickScale,
                                            top: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: tick % barTicks == 0
                                                  ? 2
                                                  : 1,
                                              color: tick % barTicks == 0
                                                  ? const Color(0xFF3A3F4D)
                                                  : tick % beatTicks == 0
                                                  ? const Color(0xFF2A2D36)
                                                  : const Color(0xFF1A1C22),
                                            ),
                                          ),
                                        for (var i = 0; i <= noteSpan; i++)
                                          Positioned(
                                            top: i * laneHeight,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              height: 1,
                                              color: const Color(0xFF1E2128),
                                            ),
                                          ),
                                        if (_isPreviewPlaying ||
                                            _playheadTick > 0)
                                          Positioned(
                                            left: (_playheadTick * tickScale)
                                                .clamp(0.0, inner.maxWidth - 1),
                                            top: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 2,
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        for (var i = 0; i < _notes.length; i++)
                                          _buildNoteRect(
                                            i,
                                            _notes[i],
                                            maxNote: maxNote,
                                            laneHeight: laneHeight,
                                            tickScale: tickScale,
                                            showConfidenceHeatmap:
                                                _showConfidenceHeatmap,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (widget.tutorialMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.cyanAccent.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lightbulb_outline,
                              size: 18,
                              color: Colors.cyanAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _tutorialEditorHint(context),
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _advanceTutorialEditorStep,
                              child: const Text('Next ->'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              if (!widget.tutorialMode)
                FilledButton(
                  onPressed: () {
                    final output = widget.parsed.rebuild(
                      _notes,
                      tempoOverrideBpm: widget.tempoOverrideBpm,
                      beatsPerMeasureOverride: widget.beatsPerMeasureOverride,
                      beatUnitOverride: widget.beatUnitOverride,
                    );
                    Navigator.pop(context, output);
                  },
                  child: const Text('Apply'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteRect(
    int index,
    EditableMidiNote note, {
    required int maxNote,
    required double laneHeight,
    required double tickScale,
    required bool showConfidenceHeatmap,
  }) {
    final top = (maxNote - note.note);
    final rectTop = (math.max(0, top.toDouble())) * laneHeight;
    final left = note.startTick * tickScale;
    final width = math.max(6.0, note.durationTicks * tickScale);
    final confidence = _confidenceFromVelocity(note.velocity);
    final noteColor = showConfidenceHeatmap
        ? _confidenceColor(confidence, selected: _selectedIndex == index)
        : (_selectedIndex == index
              ? const Color(0xFFF39C12)
              : const Color(0xFF57C86A));
    return Positioned(
      top: rectTop + 1,
      left: left,
      width: width,
      height: math.max(8, laneHeight - 2),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = index),
              onPanStart: (details) {
                setState(() {
                  _selectedIndex = index;
                  _startMoveDrag(index, details, tickScale, laneHeight);
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  _selectedIndex = index;
                  _updateMoveDrag(index, details);
                });
              },
              onPanEnd: (_) {
                setState(() => _endMoveDrag(index));
              },
              child: Container(
                decoration: BoxDecoration(
                  color: noteColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  _midiToLabel(note.note),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 10,
            child: GestureDetector(
              onHorizontalDragStart: (details) {
                setState(() {
                  _selectedIndex = index;
                  _startResizeDrag(index, details, _ResizeEdge.left, tickScale);
                });
              },
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _selectedIndex = index;
                  _updateResizeDrag(index, details);
                });
              },
              onHorizontalDragEnd: (_) {
                setState(() => _endResizeDrag(index));
              },
              child: Container(color: const Color(0x33FFFFFF)),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 10,
            child: GestureDetector(
              onHorizontalDragStart: (details) {
                setState(() {
                  _selectedIndex = index;
                  _startResizeDrag(
                    index,
                    details,
                    _ResizeEdge.right,
                    tickScale,
                  );
                });
              },
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _selectedIndex = index;
                  _updateResizeDrag(index, details);
                });
              },
              onHorizontalDragEnd: (_) {
                setState(() => _endResizeDrag(index));
              },
              child: Container(color: const Color(0x33FFFFFF)),
            ),
          ),
        ],
      ),
    );
  }

  String _midiToLabel(int midiNote) {
    const names = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    return '${names[midiNote % 12]}${(midiNote ~/ 12) - 1}';
  }

  double _confidenceFromVelocity(int velocity) {
    return (velocity.clamp(1, 127) - 1) / 126.0;
  }

  Color _confidenceColor(double confidence, {required bool selected}) {
    if (selected) return const Color(0xFFF39C12);
    final clamped = confidence.clamp(0.0, 1.0);
    if (clamped <= 0.5) {
      return Color.lerp(
            const Color(0xFFE65A5A),
            const Color(0xFFF4C04A),
            clamped / 0.5,
          ) ??
          const Color(0xFFE65A5A);
    }
    return Color.lerp(
          const Color(0xFFF4C04A),
          const Color(0xFF57C86A),
          (clamped - 0.5) / 0.5,
        ) ??
        const Color(0xFF57C86A);
  }

  void _constrainNotesToScale(
    List<EditableMidiNote> notes,
    KeyScaleConstraint constraint,
  ) {
    final allowedPitchClasses = constraint.isMinor
        ? <int>{0, 2, 3, 5, 7, 8, 10}
        : <int>{0, 2, 4, 5, 7, 9, 11};
    int? previousRaw;
    int? previousConstrained;
    for (final n in notes) {
      final raw = n.note;
      final constrained = _closestNoteInScale(
        raw,
        constraint.tonic,
        allowedPitchClasses,
        previousRaw: previousRaw,
        previousConstrained: previousConstrained,
      );
      n.note = constrained;
      previousRaw = raw;
      previousConstrained = constrained;
    }
  }

  int _closestNoteInScale(
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

  void _alignNotesToStart(List<EditableMidiNote> notes) {
    if (notes.isEmpty) return;
    final firstTick = notes.map((n) => n.startTick).reduce(math.min);
    if (firstTick <= 0) return;
    for (final note in notes) {
      note.startTick = math.max(0, note.startTick - firstTick);
    }
  }
}

class _MoveDragContext {
  const _MoveDragContext({
    required this.index,
    required this.startGlobal,
    required this.startTick,
    required this.startNote,
    required this.tickScale,
    required this.laneHeight,
  });

  final int index;
  final Offset startGlobal;
  final int startTick;
  final int startNote;
  final double tickScale;
  final double laneHeight;
}

enum _ResizeEdge { left, right }

class _ResizeDragContext {
  const _ResizeDragContext({
    required this.index,
    required this.edge,
    required this.startGlobal,
    required this.startTick,
    required this.startDuration,
    required this.tickScale,
  });

  final int index;
  final _ResizeEdge edge;
  final Offset startGlobal;
  final int startTick;
  final int startDuration;
  final double tickScale;
}

class _PreviewAudioTrim {
  const _PreviewAudioTrim({
    required this.leadingSilence,
    required this.duration,
  });

  final Duration leadingSilence;
  final Duration? duration;
}

class _PreviewWavData {
  const _PreviewWavData({
    required this.bytes,
    required this.dataOffset,
    required this.dataSize,
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.audioFormat,
    required this.blockAlign,
  });

  final Uint8List bytes;
  final int dataOffset;
  final int dataSize;
  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  final int audioFormat;
  final int blockAlign;

  int get frameCount => blockAlign <= 0 ? 0 : dataSize ~/ blockAlign;

  static _PreviewWavData? tryParse(Uint8List bytes) {
    if (bytes.length < 44 ||
        String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
      return null;
    }

    int? audioFormat;
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    int? blockAlign;
    int? dataOffset;
    int? dataSize;
    var offset = 12;

    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = _readUint32(bytes, offset + 4);
      final chunkDataOffset = offset + 8;
      if (chunkDataOffset + chunkSize > bytes.length) break;

      if (chunkId == 'fmt ' && chunkSize >= 16) {
        audioFormat = _readUint16(bytes, chunkDataOffset);
        channels = _readUint16(bytes, chunkDataOffset + 2);
        sampleRate = _readUint32(bytes, chunkDataOffset + 4);
        blockAlign = _readUint16(bytes, chunkDataOffset + 12);
        bitsPerSample = _readUint16(bytes, chunkDataOffset + 14);
      } else if (chunkId == 'data') {
        dataOffset = chunkDataOffset;
        dataSize = chunkSize;
      }

      offset = chunkDataOffset + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (audioFormat == null ||
        channels == null ||
        sampleRate == null ||
        bitsPerSample == null ||
        blockAlign == null ||
        dataOffset == null ||
        dataSize == null ||
        channels <= 0 ||
        sampleRate <= 0 ||
        blockAlign <= 0) {
      return null;
    }

    return _PreviewWavData(
      bytes: bytes,
      dataOffset: dataOffset,
      dataSize: math.min(dataSize, bytes.length - dataOffset),
      channels: channels,
      sampleRate: sampleRate,
      bitsPerSample: bitsPerSample,
      audioFormat: audioFormat,
      blockAlign: blockAlign,
    );
  }

  double sampleAt(int frame, int channel) {
    final bytesPerSample = bitsPerSample ~/ 8;
    if (bytesPerSample <= 0) return 0;
    final offset =
        dataOffset + (frame * blockAlign) + (channel * bytesPerSample);
    if (offset < dataOffset ||
        offset + bytesPerSample > dataOffset + dataSize) {
      return 0;
    }

    if (audioFormat == 3 && bitsPerSample == 32) {
      final data = ByteData.sublistView(bytes, offset, offset + 4);
      return data.getFloat32(0, Endian.little).clamp(-1.0, 1.0);
    }
    if (audioFormat != 1) return 0;

    switch (bitsPerSample) {
      case 8:
        return (bytes[offset] - 128) / 128.0;
      case 16:
        final value = _readInt16(bytes, offset);
        return value / 32768.0;
      case 24:
        var value =
            bytes[offset] |
            (bytes[offset + 1] << 8) |
            (bytes[offset + 2] << 16);
        if ((value & 0x800000) != 0) value |= ~0xFFFFFF;
        return value / 8388608.0;
      case 32:
        final value = _readInt32(bytes, offset);
        return value / 2147483648.0;
      default:
        return 0;
    }
  }

  static int _readUint16(Uint8List bytes, int offset) {
    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  static int _readUint32(Uint8List bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  static int _readInt16(Uint8List bytes, int offset) {
    final value = _readUint16(bytes, offset);
    return value >= 0x8000 ? value - 0x10000 : value;
  }

  static int _readInt32(Uint8List bytes, int offset) {
    final value = _readUint32(bytes, offset);
    return value >= 0x80000000 ? value - 0x100000000 : value;
  }
}
