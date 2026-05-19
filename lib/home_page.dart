part of 'app.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

enum _ConversionStatus { queued, running, done, failed }

class _ConversionRequest {
  const _ConversionRequest({required this.sketchId, required this.audioUrl});

  final int sketchId;
  final String audioUrl;
}

class _ConversionJobState {
  const _ConversionJobState({
    required this.status,
    required this.message,
    required this.progress,
  });

  final _ConversionStatus status;
  final String message;
  final double progress;
}

// ignore: unused_element
class _JumpingNotesOverlay extends StatelessWidget {
  // ignore: unused_element_parameter
  const _JumpingNotesOverlay({super.key});

  // ignore: unused_field
  static const _particles =
      <(double x, double delay, double size, String note, Color color)>[
        (0.12, 0.00, 30, '♪', Color(0xFF6EE7FF)),
        (0.22, 0.10, 38, '♫', Color(0xFFC084FC)),
        (0.31, 0.18, 34, '♬', Color(0xFFFFD166)),
        (0.43, 0.06, 28, '♩', Color(0xFF6EE7FF)),
        (0.56, 0.14, 42, '♪', Color(0xFFC084FC)),
        (0.66, 0.02, 30, '♫', Color(0xFFFFD166)),
        (0.78, 0.20, 36, '♬', Color(0xFF6EE7FF)),
        (0.88, 0.08, 32, '♩', Color(0xFFC084FC)),
      ];

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1900),
      curve: Curves.easeOutQuart,
      builder: (context, value, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            final centerX = width * 0.5;
            final centerY = height * 0.56;
            const glyphs = ['♪', '♫', '♬', '♩', '✦', '•', '+', '*'];
            const colors = <Color>[
              Color(0xFF6EE7FF),
              Color(0xFFC084FC),
              Color(0xFFFFD166),
              Color(0xFF8BFFB7),
              Color(0xFFFF7AC6),
            ];
            return Stack(
              children: List<Widget>.generate(86, (i) {
                final localDelay = (i % 14) * 0.018;
                final p = ((value - localDelay) / (1 - localDelay)).clamp(
                  0.0,
                  1.0,
                );
                if (p <= 0) return const SizedBox.shrink();
                final angle = ((i * 29) % 360) * (math.pi / 180.0);
                final speed = 165.0 + ((i * 23) % 180);
                final flight = Curves.easeOut.transform(p);
                final dx = math.cos(angle) * speed * flight;
                final dy = math.sin(angle) * speed * flight + (235.0 * p * p);
                final spin = (i.isEven ? 1 : -1) * (p * math.pi * 3.4);
                final alpha = (1.1 - p).clamp(0.0, 1.0);
                final size = 12.0 + (i % 6) * 4.0;
                final glyph = glyphs[i % glyphs.length];
                final color = colors[i % colors.length];
                return Positioned(
                  left: centerX + dx,
                  top: centerY + dy,
                  child: Opacity(
                    opacity: alpha,
                    child: Transform.rotate(
                      angle: spin,
                      child: Transform.scale(
                        scale: 0.95 + ((1 - p) * 0.45),
                        child: Text(
                          glyph,
                          style: TextStyle(
                            fontSize: size,
                            fontWeight: FontWeight.w900,
                            color: color,
                            shadows: [
                              Shadow(
                                color: color.withValues(alpha: 0.70),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }
}

class _FullScreenConfettiOverlay extends StatelessWidget {
  const _FullScreenConfettiOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 2100),
      curve: Curves.easeOutQuart,
      builder: (context, value, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final shortestSide = math.min(width, height);
            const glyphs = <String>[
              '\u266A',
              '\u266B',
              '\u266C',
              '\u2669',
              '\u2736',
              '\u2022',
              '+',
              '*',
            ];
            const colors = <Color>[
              Color(0xFF6EE7FF),
              Color(0xFFC084FC),
              Color(0xFFFFD166),
              Color(0xFF8BFFB7),
              Color(0xFFFF7AC6),
            ];
            const burstOrigins = <(double x, double y)>[
              (0.50, 0.52),
              (0.20, 0.42),
              (0.80, 0.42),
              (0.34, 0.68),
              (0.66, 0.68),
            ];

            return Stack(
              children: List<Widget>.generate(260, (i) {
                final burst = burstOrigins[i % burstOrigins.length];
                final centerX = width * burst.$1;
                final centerY = height * burst.$2;
                final ring = i % 5;
                final localDelay = (i % 26) * 0.012 + ring * 0.018;
                final p = ((value - localDelay) / (1 - localDelay)).clamp(
                  0.0,
                  1.0,
                );
                if (p <= 0) return const SizedBox.shrink();

                final angle = ((i * 137) % 360) * (math.pi / 180.0);
                final speed =
                    shortestSide * (0.28 + (ring * 0.09)) + ((i * 17) % 90);
                final flight = Curves.easeOut.transform(p);
                final dx = math.cos(angle) * speed * flight;
                final dy =
                    math.sin(angle) * speed * flight +
                    (shortestSide * 0.22 * p * p);
                final spin = (i.isEven ? 1 : -1) * (p * math.pi * (3.0 + ring));
                final alpha = (1.12 - p).clamp(0.0, 1.0);
                final size = 10.0 + (i % 8) * 4.0;
                final glyph = glyphs[i % glyphs.length];
                final color = colors[i % colors.length];

                return Positioned(
                  left: centerX + dx,
                  top: centerY + dy,
                  child: Opacity(
                    opacity: alpha,
                    child: Transform.rotate(
                      angle: spin,
                      child: Transform.scale(
                        scale: 0.95 + ((1 - p) * 0.45),
                        child: Text(
                          glyph,
                          style: TextStyle(
                            fontSize: size,
                            fontWeight: FontWeight.w900,
                            color: color,
                            shadows: [
                              Shadow(
                                color: color.withValues(alpha: 0.70),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  static const int _recordingSampleRate = 44100;
  static const String _basicPitchBridgeHostDesktop = '127.0.0.1';
  static const String _basicPitchBridgeHostAndroidEmulator = '10.0.2.2';

  final AudioRecorder audioRecorder = AudioRecorder();
  final AudioPlayer audioPlayer = AudioPlayer();
  StreamSubscription<void>? _playerCompleteSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  Timer? _playbackResetTimer;
  final List<Map<String, dynamic>> _sessionSketches = [];
  List<Map<String, dynamic>> _remoteSketches = [];
  late Future<List<Map<String, dynamic>>> _sketchesFuture;
  int _nextLocalSketchId = -1;
  int? _playingSketchId;
  int? _loadingSketchId;
  final Map<String, String> _playbackCacheByUrl = {};
  final Map<int, String> _cachedAudioPathBySketchId = {};
  bool isRecording = false;
  bool _isSavingRecording = false;
  DateTime? _recordingStartedAt;
  Duration _recordingElapsed = Duration.zero;
  Timer? _recordingTicker;
  final TextEditingController _timeSigTopController = TextEditingController(
    text: '4',
  );
  final TextEditingController _timeSigBottomController = TextEditingController(
    text: '4',
  );
  final TextEditingController _tempoController = TextEditingController(
    text: '120',
  );
  bool _lockTempo = false;
  bool _lockMeter = false;
  bool _constrainToScale = false;
  String _selectedKey = 'C';
  String _selectedScale = 'Major';
  bool _tutorialActive = false;
  int _tutorialStep = 0;
  static const int _tutorialStepRecord = 0;
  static const int _tutorialStepPlayRename = 1;
  static const int _tutorialStepConversion = 2;
  static const int _tutorialStepTopActions = 3;
  static const int _tutorialStepSettings = 4;
  final GlobalKey _recordCardKey = GlobalKey();
  final GlobalKey _conversionCardKey = GlobalKey();
  final GlobalKey _topActionsKey = GlobalKey();
  final GlobalKey _settingsIconKey = GlobalKey();
  final GlobalKey _firstSketchActionsKey = GlobalKey();
  static bool _tutorialShownThisSession = false;
  bool _isGeneratingMidiPreview = false;
  bool _showJumpingNotes = false;
  int _jumpingNotesSeed = 0;
  Timer? _jumpingNotesTimer;
  final Queue<_ConversionRequest> _conversionQueue =
      Queue<_ConversionRequest>();
  final Map<int, _ConversionJobState> _conversionJobs = {};
  bool _isProcessingConversionQueue = false;

  @override
  void initState() {
    super.initState();
    _sketchesFuture = getSketches();
    unawaited(_configureAudioPlayer());
    // Tutorial runtime is intentionally disabled for now.
    // if (!_tutorialShownThisSession) {
    //   _tutorialShownThisSession = true;
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     if (mounted) _startTutorial();
    //   });
    // }
    _playerCompleteSubscription = audioPlayer.onPlayerComplete.listen((_) {
      _clearPlayingSketch();
    });
    _playerStateSubscription = audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        _clearPlayingSketch();
      }
    });
  }

  void _clearPlayingSketch() {
    _playbackResetTimer?.cancel();
    _playbackResetTimer = null;

    if (!mounted) {
      _playingSketchId = null;
      _loadingSketchId = null;
      return;
    }

    if (_playingSketchId != null || _loadingSketchId != null) {
      setState(() {
        _playingSketchId = null;
        _loadingSketchId = null;
      });
    }
  }

  void _triggerJumpingNotes() {
    _jumpingNotesTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _jumpingNotesSeed++;
      _showJumpingNotes = true;
    });
    _jumpingNotesTimer = Timer(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      setState(() => _showJumpingNotes = false);
    });
  }

  Future<void> _configureAudioPlayer({
    PlayerMode mode = PlayerMode.mediaPlayer,
  }) async {
    await audioPlayer.setPlayerMode(mode);
    await audioPlayer.setReleaseMode(ReleaseMode.stop);
    try {
      await audioPlayer.setAudioContext(
        const AudioContext(
          android: AudioContextAndroid(
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
            stayAwake: true,
          ),
        ),
      );
    } on MissingPluginException {
      // Can happen on desktop during hot restart; playback still works without this.
    } catch (_) {
      // Best-effort only; ignore platform-specific context failures.
    }
  }

  Future<List<Map<String, dynamic>>> getSketches() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _remoteSketches = [];
      return _mergedSketches();
    }
    final data = await Supabase.instance.client
        .from('sketches')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    _remoteSketches = List<Map<String, dynamic>>.from(data);
    return _mergedSketches();
  }

  void _refreshSketches() {
    if (!mounted) return;
    setState(() {
      _sketchesFuture = getSketches();
    });
  }

  void _showSessionSketches() {
    if (!mounted) return;
    setState(() {
      _sketchesFuture = Future.value(_mergedSketches());
    });
  }

  List<Map<String, dynamic>> _mergedSketches() {
    final sessionIds = _sessionSketches.map((sketch) => sketch['id']).toSet();
    final sessionPaths = _sessionSketches
        .map((sketch) => sketch['audio_path'])
        .toSet();
    return [
      ..._sessionSketches,
      ..._remoteSketches.where(
        (sketch) =>
            !sessionIds.contains(sketch['id']) &&
            !sessionPaths.contains(sketch['audio_path']),
      ),
    ];
  }

  Map<String, Object> _ownedSketchFilter(int sketchId) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return {'id': sketchId};
    }
    return {'id': sketchId, 'user_id': userId};
  }

  void _startTutorial() {
    if (!mounted) return;
    setState(() {
      _tutorialActive = true;
      _tutorialStep = _tutorialStepRecord;
    });
  }

  void _finishTutorial() {
    if (!mounted) return;
    setState(() {
      _tutorialActive = false;
      _tutorialStep = 0;
    });
  }

  void _advanceTutorial() {
    if (!_tutorialActive) return;
    if (_tutorialStep >= _tutorialStepSettings) {
      _finishTutorial();
      return;
    }
    setState(() => _tutorialStep++);
  }

  String _tutorialHint() {
    switch (_tutorialStep) {
      case _tutorialStepRecord:
        return 'Record a melody here. Tap once to start and once to stop.';
      case _tutorialStepPlayRename:
        return 'Use these actions on a sketch card to rename and play clips.';
      case _tutorialStepConversion:
        return 'Open conversion settings to control tempo, meter, and key/scale.';
      case _tutorialStepTopActions:
        return 'Top actions: generate a random melody and refresh the list.';
      case _tutorialStepSettings:
        return 'Open profile/settings from here.';
      default:
        return '';
    }
  }

  GlobalKey? _tutorialTargetKey() {
    switch (_tutorialStep) {
      case _tutorialStepRecord:
        return _recordCardKey;
      case _tutorialStepPlayRename:
        return _firstSketchActionsKey;
      case _tutorialStepConversion:
        return _conversionCardKey;
      case _tutorialStepTopActions:
        return _topActionsKey;
      case _tutorialStepSettings:
        return _settingsIconKey;
      default:
        return null;
    }
  }

  int _nextRecordingIndex() {
    final matcher = RegExp(r'^Recording\s+(\d+)$', caseSensitive: false);
    var maxIndex = 0;
    for (final sketch in _mergedSketches()) {
      final title = sketch['title']?.toString() ?? '';
      final match = matcher.firstMatch(title.trim());
      if (match == null) continue;
      final value = int.tryParse(match.group(1) ?? '');
      if (value != null && value > maxIndex) {
        maxIndex = value;
      }
    }
    return maxIndex + 1;
  }

  Future<String?> _promptRecordingTitle({
    required String initialValue,
    required bool isNewRecording,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(isNewRecording ? 'Name the recording' : 'Rename recording'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
          decoration: const InputDecoration(
            hintText: 'Recording name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final trimmed = result?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<void> _renameSketch({
    required int sketchId,
    required String currentTitle,
  }) async {
    final nextTitle = await _promptRecordingTitle(
      initialValue: currentTitle,
      isNewRecording: false,
    );
    if (nextTitle == null || nextTitle == currentTitle) {
      return;
    }

    if (sketchId < 0) {
      final index = _sessionSketches.indexWhere((s) => s['id'] == sketchId);
      if (index >= 0) {
        _sessionSketches[index] = {
          ..._sessionSketches[index],
          'title': nextTitle,
        };
        _showSessionSketches();
      }
      return;
    }

    try {
      await Supabase.instance.client
          .from('sketches')
          .update({'title': nextTitle})
          .match(_ownedSketchFilter(sketchId));
      final index = _sessionSketches.indexWhere((s) => s['id'] == sketchId);
      if (index >= 0) {
        _sessionSketches[index] = {
          ..._sessionSketches[index],
          'title': nextTitle,
        };
      }
      _refreshSketches();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rename failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _storageStemFromTitle(String rawTitle) {
    final normalized = rawTitle
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (normalized.isEmpty) return 'recording';
    return normalized;
  }

  String _storageMidiFileName({required int sketchId}) {
    final title = _sketchTitleById(sketchId) ?? 'recording_$sketchId';
    final stem = _storageStemFromTitle(title);
    return '$stem.midi';
  }

  String _storagePathForUserFile(String fileName, {String? userId}) {
    final uid =
        userId ?? Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';
    return '$uid/$fileName';
  }

  String _storagePathFromPublicUrl(String publicUrl) {
    final uri = Uri.tryParse(publicUrl);
    if (uri == null) return publicUrl.split('/').last;
    final bucketIndex = uri.pathSegments.indexOf('audio-samples');
    if (bucketIndex >= 0 && bucketIndex + 1 < uri.pathSegments.length) {
      return uri.pathSegments.sublist(bucketIndex + 1).join('/');
    }
    return uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : publicUrl.split('/').last;
  }

  String? _sketchTitleById(int sketchId) {
    for (final sketch in _sessionSketches) {
      if (sketch['id'] == sketchId) return sketch['title']?.toString();
    }
    for (final sketch in _remoteSketches) {
      if (sketch['id'] == sketchId) return sketch['title']?.toString();
    }
    return null;
  }

  void _upsertSessionSketch(Map<String, dynamic> sketch) {
    final index = _sessionSketches.indexWhere(
      (item) => item['id'] == sketch['id'],
    );
    if (index >= 0) {
      _sessionSketches[index] = sketch;
    } else {
      _sessionSketches.insert(0, sketch);
    }
    _showSessionSketches();
  }

  void _replaceSessionSketch(int previousId, Map<String, dynamic> replacement) {
    final index = _sessionSketches.indexWhere(
      (item) => item['id'] == previousId,
    );
    if (index >= 0) {
      final existing = _sessionSketches[index];
      final localPath = existing['_local_audio_path']?.toString();
      final merged = <String, dynamic>{...replacement};
      if (localPath != null) {
        merged['_local_audio_path'] = localPath;
      }
      _sessionSketches[index] = merged;
    } else {
      _sessionSketches.insert(0, replacement);
    }
    _showSessionSketches();
  }

  void _removeSessionSketch(int id) {
    _sessionSketches.removeWhere((item) => item['id'] == id);
    _cachedAudioPathBySketchId.remove(id);
    _showSessionSketches();
  }

  Future<void> startRecording() async {
    try {
      if (_isSavingRecording) return;
      if (_playingSketchId != null) {
        await audioPlayer.stop();
        _clearPlayingSketch();
      }

      if (await audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final String path =
            '${directory.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
        await audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: _recordingSampleRate,
            numChannels: 1,
          ),
          path: path,
        );
        setState(() {
          isRecording = true;
          _recordingStartedAt = DateTime.now();
          _recordingElapsed = Duration.zero;
        });
        _recordingTicker?.cancel();
        _recordingTicker = Timer.periodic(const Duration(milliseconds: 200), (
          _,
        ) {
          if (!mounted || !isRecording || _recordingStartedAt == null) return;
          setState(() {
            _recordingElapsed = DateTime.now().difference(_recordingStartedAt!);
          });
        });
      }
    } catch (e) {
      debugPrint("Błąd nagrywania: $e");
    }
  }

  Future<void> stopRecording() async {
    int? localId;
    try {
      final path = await audioRecorder.stop();
      _recordingTicker?.cancel();
      setState(() {
        isRecording = false;
        _recordingStartedAt = null;
        _recordingElapsed = Duration.zero;
        _isSavingRecording = path != null;
      });

      if (path != null) {
        final file = File(path);
        final recordingIndex = _nextRecordingIndex();
        final defaultTitle = 'Recording $recordingIndex';
        final title = await _promptRecordingTitle(
          initialValue: defaultTitle,
          isNewRecording: true,
        );
        if (title == null) {
          if (await file.exists()) {
            await file.delete();
          }
          if (mounted) {
            setState(() => _isSavingRecording = false);
          }
          return;
        }
        final fileStem = _storageStemFromTitle(title);
        final fileName = '$fileStem.wav';
        final userId = Supabase.instance.client.auth.currentUser!.id;
        final storagePath = _storagePathForUserFile(fileName, userId: userId);
        final createdAt = DateTime.now();
        localId = _nextLocalSketchId--;
        final localSketch = <String, dynamic>{
          'id': localId,
          'user_id': userId,
          'title': title,
          'audio_path': path,
          'created_at': createdAt.toIso8601String(),
          '_is_uploading': true,
          '_local_audio_path': path,
        };
        _cachedAudioPathBySketchId[localId] = path;

        _upsertSessionSketch(localSketch);

        // 1. Upload do Storage
        await Supabase.instance.client.storage
            .from('audio-samples')
            .upload(
              storagePath,
              file,
              fileOptions: const FileOptions(
                contentType: 'audio/wav',
                upsert: true,
              ),
            );

        // 2. Pobranie Linku
        final String publicUrl = Supabase.instance.client.storage
            .from('audio-samples')
            .getPublicUrl(storagePath);
        // 3. Zapis w DB
        final inserted = await Supabase.instance.client
            .from('sketches')
            .insert({
              'user_id': userId,
              'title': title,
              'audio_path': publicUrl,
              'source_type': 'recording',
              'status': 'ready',
            })
            .select()
            .single();
        final remoteSketch = Map<String, dynamic>.from(inserted);
        _cachedAudioPathBySketchId.remove(localId);
        _cachedAudioPathBySketchId[remoteSketch['id'] as int] = path;
        _playbackCacheByUrl[publicUrl] = path;
        _replaceSessionSketch(localId, remoteSketch);

        unawaited(getSketches().then((_) => _showSessionSketches()));
      }
      if (mounted) {
        setState(() => _isSavingRecording = false);
      }
    } catch (e) {
      debugPrint("Błąd wysyłki: $e");
      if (localId != null) {
        final index = _sessionSketches.indexWhere(
          (item) => item['id'] == localId,
        );
        if (index >= 0) {
          _sessionSketches[index] = {
            ..._sessionSketches[index],
            '_is_uploading': false,
            '_upload_failed': true,
          };
          _showSessionSketches();
        }
      }
      if (mounted) {
        setState(() => _isSavingRecording = false);
      }
    }
  }

  Future<void> deleteSketch(int id, String filePath) async {
    if (_playingSketchId == id) {
      await audioPlayer.stop();
      _clearPlayingSketch();
    }

    if (id < 0) {
      final cachedLocal = _cachedAudioPathBySketchId.remove(id);
      if (cachedLocal != null) {
        final cachedFile = File(cachedLocal);
        if (await cachedFile.exists()) {
          await cachedFile.delete();
        }
      }
      _removeSessionSketch(id);
      final localFile = File(filePath);
      if (await localFile.exists()) {
        await localFile.delete();
      }
      return;
    }

    final fileName = _storagePathFromPublicUrl(filePath);
    await Supabase.instance.client
        .from('sketches')
        .delete()
        .match(_ownedSketchFilter(id));
    await Supabase.instance.client.storage.from('audio-samples').remove([
      fileName,
    ]);
    final cached = _cachedAudioPathBySketchId.remove(id);
    if (cached != null) {
      final cachedFile = File(cached);
      if (await cachedFile.exists()) {
        await cachedFile.delete();
      }
    }
    _playbackCacheByUrl.remove(filePath);
    _removeSessionSketch(id);
    _refreshSketches();
  }

  Future<String> _localPlaybackPathForUrl(String audioUrl) async {
    if (!audioUrl.startsWith('http://') && !audioUrl.startsWith('https://')) {
      return audioUrl;
    }
    final cached = _playbackCacheByUrl[audioUrl];
    if (cached != null && await File(cached).exists()) {
      return cached;
    }
    final response = await http.get(Uri.parse(audioUrl));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw Exception(
        'Could not download audio for playback (${response.statusCode})',
      );
    }
    final ext = audioUrl.toLowerCase().contains('.wav') ? 'wav' : 'bin';
    final dir = await getTemporaryDirectory();
    final localPath =
        '${dir.path}/sketch_cache_${audioUrl.hashCode.abs()}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(localPath).writeAsBytes(response.bodyBytes, flush: true);
    _playbackCacheByUrl[audioUrl] = localPath;
    return localPath;
  }

  Future<String> _resolveLocalAudioPath(int sketchId, String audioUrl) async {
    final cachedBySketch = _cachedAudioPathBySketchId[sketchId];
    if (cachedBySketch != null && await File(cachedBySketch).exists()) {
      return cachedBySketch;
    }

    if (!audioUrl.startsWith('http://') && !audioUrl.startsWith('https://')) {
      if (await File(audioUrl).exists()) {
        _cachedAudioPathBySketchId[sketchId] = audioUrl;
        return audioUrl;
      }
    }

    String? sessionLocalPath;
    for (final item in _sessionSketches) {
      if (item['id'] == sketchId) {
        sessionLocalPath = item['_local_audio_path']?.toString();
        break;
      }
    }
    if (sessionLocalPath != null && await File(sessionLocalPath).exists()) {
      _cachedAudioPathBySketchId[sketchId] = sessionLocalPath;
      return sessionLocalPath;
    }

    final localPath = await _localPlaybackPathForUrl(audioUrl);
    _cachedAudioPathBySketchId[sketchId] = localPath;
    return localPath;
  }

  void _clearLocalAudioCache() {
    final paths = <String>{
      ..._playbackCacheByUrl.values,
      ..._cachedAudioPathBySketchId.values,
    };
    for (final path in paths) {
      final f = File(path);
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
    _playbackCacheByUrl.clear();
    _cachedAudioPathBySketchId.clear();
  }

  Future<void> playOrStopSketch(int sketchId, String audioUrl) async {
    try {
      if (_playingSketchId == sketchId) {
        await audioPlayer.stop();
        _clearPlayingSketch();
        return;
      }

      if (mounted) {
        setState(() {
          _loadingSketchId = sketchId;
          _playingSketchId = null;
        });
      }
      _playbackResetTimer?.cancel();
      final sourcePath = await _resolveLocalAudioPath(sketchId, audioUrl);
      final localFile = File(sourcePath);
      final isLocalFile = await localFile.exists();
      final playbackDuration = isLocalFile
          ? await _playbackDurationForPath(sourcePath)
          : null;
      await audioPlayer.stop();
      if (isLocalFile) {
        await audioPlayer.play(
          DeviceFileSource(sourcePath),
          mode: PlayerMode.mediaPlayer,
        );
      } else {
        await audioPlayer.play(
          UrlSource(sourcePath),
          mode: PlayerMode.mediaPlayer,
        );
      }

      if (mounted) {
        setState(() {
          _playingSketchId = sketchId;
          _loadingSketchId = null;
        });
      }
      _schedulePlaybackReset(sketchId, playbackDuration);
    } catch (e) {
      debugPrint("Błąd odtwarzania: $e");
      if (mounted) {
        _clearPlayingSketch();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('playback_failed')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _schedulePlaybackReset(int sketchId, Duration? duration) {
    _playbackResetTimer?.cancel();
    if (duration == null) return;

    _playbackResetTimer = Timer(
      duration + const Duration(milliseconds: 350),
      () {
        if (_playingSketchId == sketchId) {
          _clearPlayingSketch();
        }
      },
    );
  }

  Future<Duration?> _playbackDurationForPath(String sourcePath) async {
    final extension = sourcePath.split('.').last.toLowerCase();
    if (extension == 'wav') {
      return _wavDuration(sourcePath);
    }

    return null;
  }

  Future<Duration?> _wavDuration(String path) async {
    final bytes = await File(path).readAsBytes();
    if (bytes.length < 44 ||
        String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
      return null;
    }

    var offset = 12;
    int? sampleRate;
    int? byteRate;
    int? dataSize;

    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = _readUint32LittleEndian(bytes, offset + 4);
      final chunkDataOffset = offset + 8;

      if (chunkId == 'fmt ' && chunkSize >= 16) {
        sampleRate = _readUint32LittleEndian(bytes, chunkDataOffset + 4);
        byteRate = _readUint32LittleEndian(bytes, chunkDataOffset + 8);
      } else if (chunkId == 'data') {
        dataSize = chunkSize;
      }

      offset = chunkDataOffset + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    final bytesPerSecond = byteRate ?? sampleRate;
    if (bytesPerSecond == null || bytesPerSecond <= 0 || dataSize == null) {
      return null;
    }

    return Duration(milliseconds: ((dataSize / bytesPerSecond) * 1000).round());
  }

  int _readUint32LittleEndian(List<int> bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  Future<Uint8List> _downloadAudioBytes(
    String audioUrl, {
    required String downloadFailedMessage,
  }) async {
    final response = await http.get(Uri.parse(audioUrl));
    if (response.statusCode != 200) {
      throw Exception(downloadFailedMessage);
    }
    return response.bodyBytes;
  }

  Future<Uint8List> _convertWithBasicPitch(Uint8List audioBytes) async {
    final bridgeHost = Platform.isAndroid
        ? _basicPitchBridgeHostAndroidEmulator
        : _basicPitchBridgeHostDesktop;
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('http://$bridgeHost:8090/audio-to-midi'),
          )
          ..fields['audio_filename'] = 'input.wav'
          ..fields['purify_audio'] = 'true'
          ..files.add(
            http.MultipartFile.fromBytes(
              'audio_file',
              audioBytes,
              filename: 'input.wav',
            ),
          );

    final response = await request.send();
    final responseBytes = await response.stream.toBytes();
    if (response.statusCode != 200) {
      final errorText = String.fromCharCodes(responseBytes);
      throw Exception(
        'Basic Pitch bridge error (${response.statusCode}): $errorText',
      );
    }
    if (responseBytes.isEmpty) {
      throw Exception('Basic Pitch bridge returned empty MIDI bytes');
    }
    return Uint8List.fromList(responseBytes);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sukces!"),
        content: const Text(
          "Twój plik MIDI został wygenerowany. Możesz go teraz pobrać z Supabase i otworzyć w programie muzycznym.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Super"),
          ),
        ],
      ),
    );
  }

  Future<void> convertAudioToMidi(String audioUrl, int sketchId) async {
    _enqueueConversionJob(sketchId, audioUrl);
    return;
    // ignore: dead_code
    try {
      if (mounted) {
        setState(() => _isGeneratingMidiPreview = true);
      }
      // 1. Informujemy użytkownika o starcie
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Generowanie czystego pliku .midi..."),
          duration: Duration(seconds: 1),
        ),
      );

      // 2. Pobieramy nagrany plik audio z Supabase
      final localAudioFile = File(audioUrl);
      final Uint8List audioBytes;
      if (await localAudioFile.exists()) {
        audioBytes = await localAudioFile.readAsBytes();
      } else {
        audioBytes = await _downloadAudioBytes(
          audioUrl,
          downloadFailedMessage: 'Could not download audio file',
        );
      }

      // 3. Wywołujemy silnik z osobnego pliku (ten, który ma tylko 1 nutę)
      final midiBytes = await _convertWithBasicPitch(audioBytes);
      final editedMidiBytes = await _openMidiEditor(
        midiBytes,
        tempoOverrideBpm: _lockTempo ? _parseTempoBpm() : null,
        meterOverride: _lockMeter ? (_parseMeter()) : null,
        keyScaleConstraint: _constrainToScale
            ? KeyScaleConstraint(
                tonic: _keyNameToPitchClass(_selectedKey),
                isMinor: _selectedScale == 'Minor',
              )
            : null,
      );
      if (editedMidiBytes == null) {
        return;
      }

      // 4. Tworzymy unikalną nazwę, żeby uniknąć starych plików w pamięci
      final midiFileName = _storageMidiFileName(sketchId: sketchId);
      final midiStoragePath = _storagePathForUserFile(midiFileName);

      // 5. Upload do Supabase Storage
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

      // 6. Pobieramy publiczny URL do nowego pliku .midi
      final String midiUrl = Supabase.instance.client.storage
          .from('audio-samples')
          .getPublicUrl(midiStoragePath);

      // 7. Aktualizujemy bazę danych (zmieniamy tytuł i ścieżkę na MIDI)
      await Supabase.instance.client
          .from('sketches')
          .update({
            'audio_path': midiUrl,
            'status': 'ready',
            'last_error': null,
          })
          .match(_ownedSketchFilter(sketchId));

      // 8. Sukces!
      if (mounted) {
        _showSuccessDialog();
        _sessionSketches.removeWhere((item) => item['id'] == sketchId);
        _refreshSketches();
      }
    } catch (e) {
      debugPrint("BŁĄD KONWERSJI: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('error_prefix')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingMidiPreview = false);
      }
    }
  }

  void _enqueueConversionJob(int sketchId, String audioUrl) {
    final active = _conversionJobs[sketchId];
    if (active != null &&
        (active.status == _ConversionStatus.queued ||
            active.status == _ConversionStatus.running)) {
      return;
    }
    setState(() {
      _conversionJobs[sketchId] = const _ConversionJobState(
        status: _ConversionStatus.queued,
        message: 'Queued',
        progress: 0.0,
      );
      _conversionQueue.add(
        _ConversionRequest(sketchId: sketchId, audioUrl: audioUrl),
      );
    });
    unawaited(_processConversionQueue());
  }

  Future<void> _processConversionQueue() async {
    if (_isProcessingConversionQueue) return;
    _isProcessingConversionQueue = true;
    try {
      while (_conversionQueue.isNotEmpty) {
        await _runConversionJob(_conversionQueue.removeFirst());
      }
    } finally {
      _isProcessingConversionQueue = false;
    }
  }

  Future<void> _runConversionJob(_ConversionRequest request) async {
    try {
      if (_isMidiSource(request.audioUrl)) {
        _setJobState(
          request.sketchId,
          const _ConversionJobState(
            status: _ConversionStatus.running,
            message: 'Editing existing MIDI...',
            progress: 0.40,
          ),
        );
        final midiBytes = await _downloadOrReadBytes(request.audioUrl);
        final editedMidiBytes = await _openMidiEditor(
          midiBytes,
          tempoOverrideBpm: _lockTempo ? _parseTempoBpm() : null,
          meterOverride: _lockMeter ? (_parseMeter()) : null,
          keyScaleConstraint: _constrainToScale
              ? KeyScaleConstraint(
                  tonic: _keyNameToPitchClass(_selectedKey),
                  isMinor: _selectedScale == 'Minor',
                )
              : null,
        );
        if (editedMidiBytes == null) {
          _setJobState(
            request.sketchId,
            const _ConversionJobState(
              status: _ConversionStatus.failed,
              message: 'Canceled in preview',
              progress: 1.0,
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 900));
          if (mounted) {
            setState(() => _conversionJobs.remove(request.sketchId));
          }
          return;
        }
        _setJobState(
          request.sketchId,
          const _ConversionJobState(
            status: _ConversionStatus.running,
            message: 'Uploading edited MIDI...',
            progress: 0.82,
          ),
        );
        final midiFileName = _storageMidiFileName(sketchId: request.sketchId);
        final midiStoragePath = _storagePathForUserFile(midiFileName);
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
            .match(_ownedSketchFilter(request.sketchId));
        await Supabase.instance.client
            .from('sketches')
            .update({
              'title':
                  _sketchTitleById(request.sketchId) ??
                  'Recording ${request.sketchId}',
              'status': 'ready',
              'last_error': null,
            })
            .match(_ownedSketchFilter(request.sketchId));

        _setJobState(
          request.sketchId,
          const _ConversionJobState(
            status: _ConversionStatus.done,
            message: 'MIDI updated',
            progress: 1.0,
          ),
        );
        _triggerJumpingNotes();
        if (mounted) {
          _refreshSketches();
        }
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          setState(() => _conversionJobs.remove(request.sketchId));
        }
        return;
      }

      _setJobState(
        request.sketchId,
        const _ConversionJobState(
          status: _ConversionStatus.running,
          message: 'Preparing audio...',
          progress: 0.10,
        ),
      );
      final sourcePath = await _resolveLocalAudioPath(
        request.sketchId,
        request.audioUrl,
      );
      final audioBytes = await File(sourcePath).readAsBytes();

      _setJobState(
        request.sketchId,
        const _ConversionJobState(
          status: _ConversionStatus.running,
          message: 'Converting to MIDI...',
          progress: 0.45,
        ),
      );
      final midiBytes = await _convertWithBasicPitch(audioBytes);
      _setJobState(
        request.sketchId,
        const _ConversionJobState(
          status: _ConversionStatus.running,
          message: 'Waiting for preview confirmation...',
          progress: 0.60,
        ),
      );
      final editedMidiBytes = await _openMidiEditor(
        midiBytes,
        tempoOverrideBpm: _lockTempo ? _parseTempoBpm() : null,
        meterOverride: _lockMeter ? (_parseMeter()) : null,
        keyScaleConstraint: _constrainToScale
            ? KeyScaleConstraint(
                tonic: _keyNameToPitchClass(_selectedKey),
                isMinor: _selectedScale == 'Minor',
              )
            : null,
      );
      if (editedMidiBytes == null) {
        _setJobState(
          request.sketchId,
          const _ConversionJobState(
            status: _ConversionStatus.failed,
            message: 'Canceled in preview',
            progress: 1.0,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          setState(() => _conversionJobs.remove(request.sketchId));
        }
        return;
      }
      final processedMidiBytes = _postProcessGeneratedMidi(editedMidiBytes);

      _setJobState(
        request.sketchId,
        const _ConversionJobState(
          status: _ConversionStatus.running,
          message: 'Uploading result...',
          progress: 0.82,
        ),
      );
      final midiFileName = _storageMidiFileName(sketchId: request.sketchId);
      final midiStoragePath = _storagePathForUserFile(midiFileName);
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
          .match(_ownedSketchFilter(request.sketchId));
      await Supabase.instance.client
          .from('sketches')
          .update({
            'title':
                _sketchTitleById(request.sketchId) ??
                'Recording ${request.sketchId}',
            'status': 'ready',
            'last_error': null,
          })
          .match(_ownedSketchFilter(request.sketchId));

      _setJobState(
        request.sketchId,
        const _ConversionJobState(
          status: _ConversionStatus.done,
          message: 'Conversion complete',
          progress: 1.0,
        ),
      );
      _triggerJumpingNotes();
      if (mounted) {
        _sessionSketches.removeWhere((item) => item['id'] == request.sketchId);
        _refreshSketches();
      }
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        setState(() => _conversionJobs.remove(request.sketchId));
      }
    } catch (e) {
      unawaited(
        Supabase.instance.client
            .from('sketches')
            .update({'status': 'failed', 'last_error': e.toString()})
            .match(_ownedSketchFilter(request.sketchId)),
      );
      _setJobState(
        request.sketchId,
        _ConversionJobState(
          status: _ConversionStatus.failed,
          message: 'Failed: $e',
          progress: 1.0,
        ),
      );
    }
  }

  bool _isMidiSource(String pathOrUrl) {
    final value = pathOrUrl.toLowerCase();
    return value.endsWith('.mid') || value.endsWith('.midi');
  }

  Future<Uint8List> _downloadOrReadBytes(String pathOrUrl) async {
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

  Uint8List _postProcessGeneratedMidi(Uint8List midiBytes) {
    final parsed = ParsedMidi.tryParse(midiBytes);
    if (parsed == null || parsed.notes.isEmpty) return midiBytes;
    final notes = parsed.notes.map((n) => EditableMidiNote.copy(n)).toList()
      ..sort((a, b) => a.startTick.compareTo(b.startTick));
    final firstTick = notes.map((n) => n.startTick).reduce(math.min);
    for (final note in notes) {
      note.startTick = math.max(0, note.startTick - firstTick);
    }
    if (_constrainToScale) {
      final tonic = _keyNameToPitchClass(_selectedKey);
      final allowed = _selectedScale == 'Minor'
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
    final meter = _lockMeter ? _parseMeter() : null;
    final tempo = _lockTempo ? _parseTempoBpm() : null;
    return parsed.rebuild(
      notes,
      tempoOverrideBpm: tempo,
      beatsPerMeasureOverride: meter?.beatsPerMeasure,
      beatUnitOverride: meter?.beatUnit,
    );
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
          score += 8; // avoid flipping contour direction
        }
        if ((candidate - previousConstrained).abs() > 12) {
          score += 5; // discourage octave jumps from snapping
        }
      }

      if (score < bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    return best;
  }

  void _setJobState(int sketchId, _ConversionJobState state) {
    if (!mounted) return;
    setState(() => _conversionJobs[sketchId] = state);
  }

  Future<Uint8List?> _openMidiEditor(
    Uint8List midiBytes, {
    int? tempoOverrideBpm,
    ({int beatsPerMeasure, int beatUnit})? meterOverride,
    KeyScaleConstraint? keyScaleConstraint,
  }) async {
    final parsed = ParsedMidi.tryParse(midiBytes);
    if (parsed == null || parsed.notes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('MIDI editor skipped: could not parse note events.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return midiBytes;
    }
    if (!mounted) return midiBytes;
    final effectiveTempo = tempoOverrideBpm ?? parsed.tempoBpm;
    final effectiveMeterTop =
        meterOverride?.beatsPerMeasure ?? parsed.beatsPerMeasure;
    final effectiveMeterBottom = meterOverride?.beatUnit ?? parsed.beatUnit;
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MidiEditorDialog(
        parsed: parsed,
        tempoOverrideBpm: effectiveTempo,
        beatsPerMeasureOverride: effectiveMeterTop,
        beatUnitOverride: effectiveMeterBottom,
        keyScaleConstraint: keyScaleConstraint,
      ),
    );
  }

  @override
  void dispose() {
    _recordingTicker?.cancel();
    _playbackResetTimer?.cancel();
    _jumpingNotesTimer?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _timeSigTopController.dispose();
    _timeSigBottomController.dispose();
    _tempoController.dispose();
    _clearLocalAudioCache();
    audioRecorder.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset(_brandLogoMarkAsset, width: 24, height: 24),
            const SizedBox(width: 8),
            Text(
              context.tr('app_title'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tutorial',
            icon: const Icon(Icons.help_outline),
            // onPressed: _startTutorial, // Disabled: keep tutorial code, don't run it.
            onPressed: null,
          ),
          IconButton(
            key: _settingsIconKey,
            tooltip: context.tr('settings'),
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileSettingsPage()),
              );
              if (mounted) {
                setState(() {});
              }
            },
          ),
          IconButton(
            tooltip: context.tr('logout'),
            icon: const Icon(Icons.logout),
            onPressed: () async {
              _clearLocalAudioCache();
              await Supabase.instance.client.auth.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AuthCheck()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF091325),
                    Color(0xFF1B1A3A),
                    Color(0xFF102A3E),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // PANEL NAGRYWANIA
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Material(
                    key: _recordCardKey,
                    color: isRecording
                        ? const Color(0xFF2B1B24)
                        : const Color(0xFF131A2B),
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: _isSavingRecording
                          ? null
                          : (isRecording ? stopRecording : startRecording),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isRecording
                                ? Colors.redAccent
                                : colorScheme.primary.withValues(alpha: 0.65),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(
                                alpha: 0.15,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              isRecording ? Icons.stop_circle : Icons.mic,
                              size: 48,
                              color: isRecording
                                  ? Colors.redAccent
                                  : colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isSavingRecording
                                  ? context.tr('saving_clip')
                                  : isRecording
                                  ? context.tr('tap_to_stop')
                                  : context.tr('record_melody'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isSavingRecording
                                  ? "Uploading recording to Supabase"
                                  : isRecording
                                  ? "Saving as a 44.1 kHz WAV clip"
                                  : context.tr('hum_prompt'),
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (isRecording) ...[
                              const SizedBox(height: 6),
                              Text(
                                _formatDuration(_recordingElapsed),
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                            if (_isSavingRecording) ...[
                              const SizedBox(height: 10),
                              const LinearProgressIndicator(minHeight: 3),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Material(
                    key: _conversionCardKey,
                    color: const Color(0xFF131A2B),
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.30),
                        ),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF17213A), Color(0xFF121A2E)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.tune,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.tr('settings_card'),
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _openConversionSettingsSheet,
                                icon: const Icon(Icons.open_in_full, size: 16),
                                label: Text(context.tr('open')),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _lockTempo
                                ? 'Tempo: ${_parseTempoBpm()} BPM (locked)'
                                : context.tr('tempo_auto'),
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _lockMeter
                                ? 'Meter: ${_parseMeter().beatsPerMeasure}/${_parseMeter().beatUnit} (locked)'
                                : context.tr('meter_auto'),
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _constrainToScale
                                ? 'Key/Scale: $_selectedKey $_selectedScale'
                                : context.tr('scale_off'),
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: _openConversionSettingsSheet,
                                icon: const Icon(Icons.settings_suggest),
                                label: Text(context.tr('edit_settings')),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF273258),
                                  foregroundColor: const Color(0xFFEAF0FF),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    key: _topActionsKey,
                    children: [
                      Text(
                        context.tr('sketches'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: "Generate random melody",
                        onPressed: _generateRandomMelodySketch,
                        icon: const Icon(Icons.casino_outlined),
                      ),
                      IconButton(
                        tooltip: "Refresh",
                        onPressed: _refreshSketches,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                // LISTA
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _sketchesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final sketches = snapshot.data ?? [];
                      if (sketches.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.library_music,
                                size: 48,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.tr('no_sketches'),
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: sketches.length,
                        itemBuilder: (context, index) {
                          final item = sketches[index];
                          final itemId = item['id'] as int;
                          final audioPath = item['audio_path'] as String;
                          final isPlaying = _playingSketchId == itemId;
                          final isLoading = _loadingSketchId == itemId;
                          final isUploading = item['_is_uploading'] == true;
                          final uploadFailed = item['_upload_failed'] == true;
                          final job = _conversionJobs[itemId];
                          final jobActive =
                              job != null &&
                              (job.status == _ConversionStatus.queued ||
                                  job.status == _ConversionStatus.running);

                          return Dismissible(
                            key: Key(itemId.toString()),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => deleteSketch(itemId, audioPath),
                            background: Container(
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                            ),
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: const BorderSide(
                                  color: Color(0xFF263150),
                                ),
                              ),
                              color: const Color(0xFF121A2D),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.18,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.graphic_eq,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                title: Text(
                                  isUploading
                                      ? '${item['title']} (uploading...)'
                                      : uploadFailed
                                      ? '${item['title']} (local only)'
                                      : item['title'],
                                ),
                                subtitle: Text(
                                  job != null
                                      ? '${item['created_at'].toString().substring(0, 10)} • ${job.message}'
                                      : item['created_at'].toString().substring(
                                          0,
                                          10,
                                        ),
                                ),
                                trailing: Wrap(
                                  key: index == 0
                                      ? _firstSketchActionsKey
                                      : null,
                                  spacing: 12, // odstęp między ikonami
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: Color(0xFF9FB0D8),
                                      ),
                                      onPressed: isUploading
                                          ? null
                                          : () => _renameSketch(
                                              sketchId: itemId,
                                              currentTitle:
                                                  item['title']?.toString() ??
                                                  'Recording',
                                            ),
                                      tooltip: context.tr('rename'),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.auto_awesome,
                                        color: Colors.deepPurpleAccent,
                                      ), // Ikona magii
                                      onPressed: isUploading
                                          ? null
                                          : jobActive
                                          ? null
                                          : () => convertAudioToMidi(
                                              audioPath,
                                              itemId,
                                            ),
                                      tooltip: context.tr('convert_to_midi'),
                                    ),
                                    IconButton(
                                      icon: isLoading
                                          ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                                color: colorScheme.primary,
                                              ),
                                            )
                                          : Icon(
                                              isPlaying
                                                  ? Icons.stop_circle
                                                  : Icons.play_arrow,
                                              color: isPlaying
                                                  ? Colors.redAccent
                                                  : colorScheme.primary,
                                            ),
                                      onPressed: () =>
                                          playOrStopSketch(itemId, audioPath),
                                      tooltip: isPlaying
                                          ? context.tr('stop_playback')
                                          : context.tr('play_clip'),
                                    ),
                                  ],
                                ),
                                isThreeLine: job != null,
                                minVerticalPadding: 8,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Disabled: keep tutorial overlay implementation in code, but don't render it.
          // if (_tutorialActive) _buildTutorialOverlay(colorScheme),
          if (_showJumpingNotes)
            Positioned.fill(
              child: IgnorePointer(
                child: _FullScreenConfettiOverlay(
                  key: ValueKey<int>(_jumpingNotesSeed),
                ),
              ),
            ),
          if (_isGeneratingMidiPreview)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTutorialOverlay(ColorScheme colorScheme) {
    return Positioned.fill(
      child: Builder(
        builder: (overlayContext) {
          final targetKey = _tutorialTargetKey();
          final targetCenter = targetKey == null
              ? null
              : _targetCenterInOverlay(
                  overlayContext: overlayContext,
                  targetKey: targetKey,
                );
          final size = MediaQuery.of(overlayContext).size;
          final cardTop = targetCenter == null
              ? 88.0
              : targetCenter.dy < size.height * 0.5
              ? (size.height * 0.62).clamp(96.0, size.height - 190)
              : 86.0;
          final cardRect = Rect.fromLTWH(12, cardTop, size.width - 24, 124);

          return Stack(
            children: [
              AbsorbPointer(
                absorbing: true,
                child: Container(color: Colors.black.withValues(alpha: 0.48)),
              ),
              if (targetCenter != null)
                _TutorialCurvedArrow(
                  start: _anchorPointOnRect(cardRect, targetCenter),
                  end: targetCenter,
                ),
              Positioned(
                top: cardTop,
                left: 12,
                right: 12,
                child: _buildTutorialCard(colorScheme),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTutorialCard(ColorScheme colorScheme) {
    return Material(
      color: const Color(0xEE111A2D),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: colorScheme.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _tutorialHint(),
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _advanceTutorial,
              child: const Text('Next ->'),
            ),
            TextButton(onPressed: _finishTutorial, child: const Text('Skip')),
          ],
        ),
      ),
    );
  }

  Future<void> _openConversionSettingsSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10182B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              void sync(void Function() fn) {
                setState(fn);
                setModalState(() {});
              }

              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Conversion Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildSettingsBlock(
                        title: 'Tempo',
                        child: Row(
                          children: [
                            Switch(
                              value: _lockTempo,
                              onChanged: (value) =>
                                  sync(() => _lockTempo = value),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Tempo lock',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 90,
                              child: TextField(
                                controller: _tempoController,
                                keyboardType: TextInputType.number,
                                enabled: _lockTempo,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  suffixText: 'BPM',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildSettingsBlock(
                        title: 'Meter',
                        child: Row(
                          children: [
                            Switch(
                              value: _lockMeter,
                              onChanged: (value) =>
                                  sync(() => _lockMeter = value),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Meter lock',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 56,
                              child: TextField(
                                controller: _timeSigTopController,
                                keyboardType: TextInputType.number,
                                enabled: _lockMeter,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  isDense: true,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Text('/'),
                            ),
                            SizedBox(
                              width: 56,
                              child: TextField(
                                controller: _timeSigBottomController,
                                keyboardType: TextInputType.number,
                                enabled: _lockMeter,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildSettingsBlock(
                        title: 'Key and Scale',
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Switch(
                                  value: _constrainToScale,
                                  onChanged: (value) =>
                                      sync(() => _constrainToScale = value),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Key/Scale constraint',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedKey,
                                    isDense: true,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                    ),
                                    items:
                                        const [
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
                                            ]
                                            .map(
                                              (k) => DropdownMenuItem(
                                                value: k,
                                                child: Text(k),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: _constrainToScale
                                        ? (value) {
                                            if (value == null) return;
                                            sync(() => _selectedKey = value);
                                          }
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedScale,
                                    isDense: true,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                    ),
                                    items: const ['Major', 'Minor']
                                        .map(
                                          (s) => DropdownMenuItem(
                                            value: s,
                                            child: Text(s),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: _constrainToScale
                                        ? (value) {
                                            if (value == null) return;
                                            sync(() => _selectedScale = value);
                                          }
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSettingsBlock({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131D33),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  ({int beatsPerMeasure, int beatUnit}) _parseMeter() {
    final top = int.tryParse(_timeSigTopController.text.trim()) ?? 4;
    final bottom = int.tryParse(_timeSigBottomController.text.trim()) ?? 4;
    final normalizedTop = top.clamp(1, 12);
    final allowedBottom = const [1, 2, 4, 8, 16, 32];
    final normalizedBottom = allowedBottom.contains(bottom) ? bottom : 4;
    return (beatsPerMeasure: normalizedTop, beatUnit: normalizedBottom);
  }

  int _parseTempoBpm() {
    final bpm = int.tryParse(_tempoController.text.trim()) ?? 120;
    return bpm.clamp(40, 240);
  }

  int _keyNameToPitchClass(String key) {
    const mapping = <String, int>{
      'C': 0,
      'C#': 1,
      'D': 2,
      'D#': 3,
      'E': 4,
      'F': 5,
      'F#': 6,
      'G': 7,
      'G#': 8,
      'A': 9,
      'A#': 10,
      'B': 11,
    };
    return mapping[key] ?? 0;
  }

  Future<void> _generateRandomMelodySketch() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final meter = _parseMeter();
      final bpm = _lockTempo ? _parseTempoBpm() : 120;
      final bars = 2;
      final tpq = 480;
      final ticksPerBeat = ((tpq * 4) / meter.beatUnit).round().clamp(
        1,
        1 << 30,
      );
      final totalTicks = ticksPerBeat * meter.beatsPerMeasure * bars;

      final keyPc = _keyNameToPitchClass(_selectedKey);
      final scale = _selectedScale == 'Minor'
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

        final octave = 4 + rand.nextInt(2); // 4..5
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
      final midiFileName = "random_melody_$ts.midi";
      final midiStoragePath = _storagePathForUserFile(
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
        'title': '🎲 Random $_selectedKey $_selectedScale',
        'audio_path': midiUrl,
      });

      if (mounted) {
        _refreshSketches();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Random melody generated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Random melody failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
