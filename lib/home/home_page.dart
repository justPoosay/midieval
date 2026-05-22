part of 'package:midieval/app.dart';

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
            const glyphs = [
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

  void _triggerUiRefresh() {
    if (!mounted) return;
    setState(() {});
  }

  void _applyState(void Function() fn) {
    if (!mounted) return;
    setState(fn);
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

  Future<void> convertAudioToMidi(String audioUrl, int sketchId) async {
    await _HomePageConversionFlow.convertAudioToMidi(this, audioUrl, sketchId);
  }

  Future<Uint8List?> _openMidiEditor(
    Uint8List midiBytes, {
    int? tempoOverrideBpm,
    ({int beatsPerMeasure, int beatUnit})? meterOverride,
    KeyScaleConstraint? keyScaleConstraint,
    String? sourceAudioPath,
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
    if (sourceAudioPath != null) {
      await audioPlayer.stop();
      _clearPlayingSketch();
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
        sourceAudioPath: sourceAudioPath,
        sourceAudioPlayer: sourceAudioPath == null ? null : audioPlayer,
      ),
    );
  }

  Future<void> _openConversionSettingsSheet() async {
    await _HomePageSettingsSheet.open(this);
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
    await _RandomMelodyGenerator.generate(this);
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
    return _HomePageView(state: this);
  }
}
