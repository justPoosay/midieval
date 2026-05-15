import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:http/http.dart' as http;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // INICJALIZACJA SUPABASE
  await Supabase.initialize(
    url: 'https://bbmpvmdpqbrerjrnzjkk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJibXB2bWRwcWJyZXJqcm56amtrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg0NTIyMjYsImV4cCI6MjA5NDAyODIyNn0.NhaL48LASXPKvvWMNNP8orswoZKRbUa3L0nyuCjdNj8',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MIDieval',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFC857),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101114),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1C22),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Color(0xFF101114),
          foregroundColor: Color(0xFFF5F2EA),
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const AuthCheck(),
    );
  }
}

// Sprawdza, czy użytkownik jest zalogowany
class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return session == null ? const AuthScreen() : const MyHomePage();
  }
}

// --- EKRAN LOGOWANIA ---
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MyHomePage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Błąd: $e")));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSignUp() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Zarejestrowano! Sprawdź email.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Błąd: $e")));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              "MIDieval",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const Text("Zaloguj się, aby tworzyć kroniki nucenia"),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: "Hasło",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleSignIn,
                      child: const Text("Wejdź"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleSignUp,
                      child: const Text("Dołącz"),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

}

// --- GŁÓWNY EKRAN APLIKACJI ---
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
  bool _isGeneratingMidiPreview = false;
  final Queue<_ConversionRequest> _conversionQueue = Queue<_ConversionRequest>();
  final Map<int, _ConversionJobState> _conversionJobs = {};
  bool _isProcessingConversionQueue = false;

  @override
  void initState() {
    super.initState();
    _sketchesFuture = getSketches();
    unawaited(_configureAudioPlayer());
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
    final data = await Supabase.instance.client
        .from('sketches')
        .select()
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
      _sessionSketches[index] = replacement;
    } else {
      _sessionSketches.insert(0, replacement);
    }
    _showSessionSketches();
  }

  void _removeSessionSketch(int id) {
    _sessionSketches.removeWhere((item) => item['id'] == id);
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
        _recordingTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
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
        final fileName = "voice_${DateTime.now().millisecondsSinceEpoch}.wav";
        final userId = Supabase.instance.client.auth.currentUser!.id;
        final createdAt = DateTime.now();
        final title = 'Nucenie ${createdAt.hour}:${createdAt.minute}';
        localId = _nextLocalSketchId--;
        final localSketch = <String, dynamic>{
          'id': localId,
          'user_id': userId,
          'title': title,
          'audio_path': path,
          'created_at': createdAt.toIso8601String(),
          '_is_uploading': true,
        };

        _upsertSessionSketch(localSketch);

        // 1. Upload do Storage
        await Supabase.instance.client.storage
            .from('audio-samples')
            .upload(
              fileName,
              file,
              fileOptions: const FileOptions(contentType: 'audio/wav'),
            );

        // 2. Pobranie Linku
        final String publicUrl = Supabase.instance.client.storage
            .from('audio-samples')
            .getPublicUrl(fileName);
        // 3. Zapis w DB
        final inserted = await Supabase.instance.client
            .from('sketches')
            .insert({
              'user_id': userId,
              'title': title,
              'audio_path': publicUrl,
            })
            .select()
            .single();
        final remoteSketch = Map<String, dynamic>.from(inserted);
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
      _removeSessionSketch(id);
      final localFile = File(filePath);
      if (await localFile.exists()) {
        await localFile.delete();
      }
      return;
    }

    final fileName = filePath.split('/').last;
    await Supabase.instance.client.from('sketches').delete().match({'id': id});
    await Supabase.instance.client.storage.from('audio-samples').remove([
      fileName,
    ]);
    _removeSessionSketch(id);
    _refreshSketches();
  }

  Future<String> _localPlaybackPathForUrl(String audioUrl) async {
    return audioUrl;
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
      final sourcePath = await _localPlaybackPathForUrl(audioUrl);
      final localFile = File(sourcePath);
      final isLocalFile = await localFile.exists();
      final playbackDuration = isLocalFile
          ? await _playbackDurationForPath(sourcePath)
          : null;
      await audioPlayer.stop();
      if (isLocalFile) {
        await audioPlayer.setSourceDeviceFile(sourcePath);
      } else {
        await audioPlayer.setSourceUrl(sourcePath);
      }
      await audioPlayer.resume();

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
            content: Text("Nie udało się odtworzyć klipu: $e"),
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

  Future<Uint8List> _downloadAudioBytes(String audioUrl) async {
    final response = await http.get(Uri.parse(audioUrl));
    if (response.statusCode != 200) {
      throw Exception("Nie udało się pobrać pliku audio");
    }
    return response.bodyBytes;
  }

  Future<Uint8List> _convertWithBasicPitch(Uint8List audioBytes) async {
    final bridgeHost = Platform.isAndroid
        ? _basicPitchBridgeHostAndroidEmulator
        : _basicPitchBridgeHostDesktop;
    final request = http.MultipartRequest(
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
        audioBytes = await _downloadAudioBytes(audioUrl);
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
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final midiFileName = "melody_${sketchId}_$timestamp.midi";

      // 5. Upload do Supabase Storage
      await Supabase.instance.client.storage
          .from('audio-samples')
          .uploadBinary(
            midiFileName,
            editedMidiBytes,
            fileOptions: const FileOptions(
              contentType: 'audio/midi',
              upsert: true,
            ),
          );

      // 6. Pobieramy publiczny URL do nowego pliku .midi
      final String midiUrl = Supabase.instance.client.storage
          .from('audio-samples')
          .getPublicUrl(midiFileName);

      // 7. Aktualizujemy bazę danych (zmieniamy tytuł i ścieżkę na MIDI)
      await Supabase.instance.client
          .from('sketches')
          .update({
            'title':
                '🎵 MIDI: ${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}',
            'audio_path': midiUrl,
          })
          .match({'id': sketchId});

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
          SnackBar(content: Text("Błąd: $e"), backgroundColor: Colors.red),
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
      _conversionQueue.add(_ConversionRequest(sketchId: sketchId, audioUrl: audioUrl));
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
      _setJobState(
        request.sketchId,
        const _ConversionJobState(
          status: _ConversionStatus.running,
          message: 'Downloading audio...',
          progress: 0.10,
        ),
      );
      final localAudioFile = File(request.audioUrl);
      final Uint8List audioBytes;
      if (await localAudioFile.exists()) {
        audioBytes = await localAudioFile.readAsBytes();
      } else {
        audioBytes = await _downloadAudioBytes(request.audioUrl);
      }

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
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final midiFileName = "melody_${request.sketchId}_$timestamp.midi";
      await Supabase.instance.client.storage
          .from('audio-samples')
          .uploadBinary(
            midiFileName,
            processedMidiBytes,
            fileOptions: const FileOptions(contentType: 'audio/midi', upsert: true),
          );
      final midiUrl = Supabase.instance.client.storage
          .from('audio-samples')
          .getPublicUrl(midiFileName);
      await Supabase.instance.client
          .from('sketches')
          .update({
            'title':
                '🎵 MIDI: ${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}',
            'audio_path': midiUrl,
          })
          .match({'id': request.sketchId});

      _setJobState(
        request.sketchId,
        const _ConversionJobState(
          status: _ConversionStatus.done,
          message: 'Conversion complete',
          progress: 1.0,
        ),
      );
      if (mounted) {
        _sessionSketches.removeWhere((item) => item['id'] == request.sketchId);
        _refreshSketches();
      }
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        setState(() => _conversionJobs.remove(request.sketchId));
      }
    } catch (e) {
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
      for (final note in notes) {
        note.note = _closestNoteInScale(note.note, tonic, allowed);
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

  int _closestNoteInScale(int midiNote, int tonic, Set<int> scale) {
    var best = midiNote;
    var bestDistance = 999;
    for (var delta = -3; delta <= 3; delta++) {
      final candidate = (midiNote + delta).clamp(0, 127);
      final pitchClass = ((candidate - tonic) % 12 + 12) % 12;
      if (!scale.contains(pitchClass)) continue;
      final distance = (candidate - midiNote).abs();
      if (distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
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
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _timeSigTopController.dispose();
    _timeSigBottomController.dispose();
    _tempoController.dispose();
    audioRecorder.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isNarrowPhone = MediaQuery.of(context).size.width < 420;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "MIDieval",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
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
          SafeArea(
            child: Column(
          children: [
            // PANEL NAGRYWANIA
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Material(
                color: isRecording
                    ? const Color(0xFF2A171A)
                    : const Color(0xFF1A1C22),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _isSavingRecording
                      ? null
                      : (isRecording ? stopRecording : startRecording),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isRecording
                            ? Colors.redAccent
                            : colorScheme.primary.withValues(alpha: 0.65),
                      ),
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
                              ? "Saving clip..."
                              : isRecording
                              ? "Tap to stop and save"
                              : "Record a melody",
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
                              : "Hum or sing a short phrase",
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        if (isRecording) ...[
                          const SizedBox(height: 6),
                          Text(
                            _formatDuration(_recordingElapsed),
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [FontFeature.tabularFigures()],
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
                color: const Color(0xFF1A1C22),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 46,
                        child: TextField(
                          controller: _timeSigTopController,
                          keyboardType: TextInputType.number,
                          enabled: _lockMeter,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('/'),
                      ),
                      SizedBox(
                        width: 46,
                        child: TextField(
                          controller: _timeSigBottomController,
                          keyboardType: TextInputType.number,
                          enabled: _lockMeter,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Switch(
                              value: _lockTempo,
                              onChanged: (value) {
                                setState(() => _lockTempo = value);
                              },
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isNarrowPhone ? 'Tempo' : 'Tempo Lock',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 52,
                              child: TextField(
                                controller: _tempoController,
                                keyboardType: TextInputType.number,
                                enabled: _lockTempo,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('BPM'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Material(
                color: const Color(0xFF1A1C22),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Switch(
                            value: _lockMeter,
                            onChanged: (value) {
                              setState(() => _lockMeter = value);
                            },
                          ),
                          Text(
                            isNarrowPhone ? 'Meter' : 'Meter Lock',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: _constrainToScale,
                            onChanged: (value) {
                              setState(() => _constrainToScale = value);
                            },
                          ),
                          Expanded(
                            child: Text(
                              isNarrowPhone ? 'Key/Scale' : 'Key/Scale Constraint',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedKey,
                              isDense: true,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              items: const [
                                'C', 'C#', 'D', 'D#', 'E', 'F',
                                'F#', 'G', 'G#', 'A', 'A#', 'B',
                              ]
                                  .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                                  .toList(),
                              onChanged: _constrainToScale
                                  ? (value) {
                                      if (value == null) return;
                                      setState(() => _selectedKey = value);
                                    }
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedScale,
                              isDense: true,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              items: const ['Major', 'Minor']
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                  .toList(),
                              onChanged: _constrainToScale
                                  ? (value) {
                                      if (value == null) return;
                                      setState(() => _selectedScale = value);
                                    }
                                  : null,
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
                children: [
                  const Text(
                    "Sketches",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
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
                          const Text(
                            "No sketches yet",
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
                      final jobActive = job != null &&
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
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(8),
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
                                  : item['created_at'].toString().substring(0, 10),
                            ),
                            trailing: Wrap(
                              spacing: 12, // odstęp między ikonami
                              children: [
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
                                  tooltip: "Konwertuj na MIDI",
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
                                      ? "Zatrzymaj odtwarzanie"
                                      : "Odtwórz klip",
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
}

class MidiEditorDialog extends StatefulWidget {
  const MidiEditorDialog({
    super.key,
    required this.parsed,
    required this.tempoOverrideBpm,
    required this.beatsPerMeasureOverride,
    required this.beatUnitOverride,
    this.keyScaleConstraint,
  });

  final ParsedMidi parsed;
  final int tempoOverrideBpm;
  final int beatsPerMeasureOverride;
  final int beatUnitOverride;
  final KeyScaleConstraint? keyScaleConstraint;

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
  int? _erasePointer;
  final Set<int> _erasedIndices = <int>{};

  @override
  void initState() {
    super.initState();
    _notes = widget.parsed.notes
        .map((n) => EditableMidiNote.copy(n))
        .toList()
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
    if (widget.keyScaleConstraint != null) {
      _constrainNotesToScale(_notes, widget.keyScaleConstraint!);
    }
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  void _deleteSelected() {
    if (_selectedIndex < 0 || _selectedIndex >= _notes.length) return;
    _commitUndoState();
    setState(() {
      _notes.removeAt(_selectedIndex);
      _selectedIndex = -1;
    });
  }

  void _quantizeAll() {
    _commitUndoState();
    if (_notes.isEmpty) return;
    setState(() {
      _intelligentQuantize();
      _notes.sort((a, b) => a.startTick.compareTo(b.startTick));
    });
  }

  void _intelligentQuantize() {
    final tpq = widget.parsed.ticksPerQuarter;
    final measureTicks =
        ((tpq * 4 * widget.beatsPerMeasureOverride) / widget.beatUnitOverride)
            .round()
            .clamp(1, 1 << 30);
    final beatTicks =
        ((tpq * 4) / widget.beatUnitOverride).round().clamp(1, 1 << 30);
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
        targetDuration = math.min(targetDuration, math.max(1, nextStart - quantizedStart));
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
      intervals.add(math.max(onsetStep, _notes[i].startTick - _notes[i - 1].startTick));
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
        _regularizeRun(
          runStart,
          i - 1,
          dominantInterval,
          onsetStep,
          gridPhase,
        );
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
        final snappedInBar = ((snapped % measureTicks) + measureTicks) % measureTicks;
        final beatDistance = _distanceToNearestMultiple(snappedInBar, beatTicks);
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
    final durations = fractions
        .map((f) => math.max(1, (whole * f).round()))
        .toSet()
        .toList()
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

  Future<void> _togglePreviewPlayback(int tickEnd) async {
    if (_isPreviewPlaying) {
      _previewTimer?.cancel();
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
    _previewTimer?.cancel();
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
        _triggerNotesBetween(previousTick, _playheadTick);
        if (_playheadTick >= maxTick) {
          _playheadTick = maxTick.toDouble();
          _isPreviewPlaying = false;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _rewindPreview() async {
    _previewTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isPreviewPlaying = false;
      _playheadTick = 0;
    });
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

  // ignore: unused_element
  Future<void> _playLiveNoteExperimentalWindowsTone(EditableMidiNote note) async {
    // Windows fallback preview synth without plugin channels:
    // trigger a simple tone per note in a detached process.
    if (!Platform.isWindows) return;
    final freq = (440.0 * math.pow(2.0, (note.note - 69) / 12.0))
        .round()
        .clamp(37, 32767);
    final durationMs = (((note.durationTicks / widget.parsed.ticksPerQuarter) *
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
      _notes = _undoStack.removeLast().map((n) => EditableMidiNote.copy(n)).toList();
      if (_selectedIndex >= _notes.length) _selectedIndex = -1;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_notes.map((n) => EditableMidiNote.copy(n)).toList());
      _notes = _redoStack.removeLast().map((n) => EditableMidiNote.copy(n)).toList();
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
    final tickEnd = _notes.isEmpty
        ? widget.parsed.ticksPerQuarter * 4
        : _notes
              .map((e) => e.startTick + e.durationTicks)
              .reduce(math.max) +
          widget.parsed.ticksPerQuarter;

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyZ, control: true): UndoIntent(),
        SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): RedoIntent(),
        SingleActivator(LogicalKeyboardKey.space): PlayPreviewIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          UndoIntent: CallbackAction<UndoIntent>(onInvoke: (intent) {
            _undo();
            return null;
          }),
          RedoIntent: CallbackAction<RedoIntent>(onInvoke: (intent) {
            _redo();
            return null;
          }),
          PlayPreviewIntent: CallbackAction<PlayPreviewIntent>(onInvoke: (intent) {
            unawaited(_togglePreviewPlayback(tickEnd));
            return null;
          }),
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
                    onPressed: _selectedIndex >= 0 ? _deleteSelected : null,
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
                    onPressed: () => unawaited(_togglePreviewPlayback(tickEnd)),
                    icon: Icon(_isPreviewPlaying ? Icons.stop : Icons.play_arrow),
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
                        final tickScale = inner.maxWidth / math.max(1, tickEnd);
                        final barTicks =
                            ((widget.parsed.ticksPerQuarter * 4 * widget.beatsPerMeasureOverride) /
                                    widget.beatUnitOverride)
                                .round();
                        final beatTicks =
                            ((widget.parsed.ticksPerQuarter * 4) / widget.beatUnitOverride)
                                .round();
                        return Listener(
                          onPointerDown: (event) {
                            if ((event.buttons & kSecondaryMouseButton) != 0) {
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
                                (event.buttons & kSecondaryMouseButton) != 0) {
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
                          child: Stack(
                            children: [
                              for (var tick = 0; tick <= tickEnd; tick += _gridTick())
                                Positioned(
                                  left: tick * tickScale,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: tick % barTicks == 0 ? 2 : 1,
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
                                  child: Container(height: 1, color: const Color(0xFF1E2128)),
                                ),
                              if (_isPreviewPlaying || _playheadTick > 0)
                                Positioned(
                                  left: (_playheadTick * tickScale).clamp(0.0, inner.maxWidth - 1),
                                  top: 0,
                                  bottom: 0,
                                  child: Container(width: 2, color: Colors.redAccent),
                                ),
                              for (var i = 0; i < _notes.length; i++)
                                _buildNoteRect(
                                  i,
                                  _notes[i],
                                  maxNote: maxNote,
                                  laneHeight: laneHeight,
                                  tickScale: tickScale,
                                  showConfidenceHeatmap: _showConfidenceHeatmap,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
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
    final grid = _gridTick();
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
              onPanStart: (_) => _commitUndoState(),
              onPanUpdate: (details) {
                setState(() {
                  _selectedIndex = index;
                  final deltaTicks = (details.delta.dx / tickScale).round();
                  final nextStart = _snapTick(
                    math.max(0, note.startTick + deltaTicks),
                  );
                  note.startTick = nextStart;
                  final pitchDelta = (details.delta.dy / laneHeight).round();
                  if (pitchDelta != 0) {
                    note.note = (note.note - pitchDelta).clamp(0, 127);
                  }
                });
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
              onHorizontalDragStart: (_) => _commitUndoState(),
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _selectedIndex = index;
                  final endTick = note.startTick + note.durationTicks;
                  final deltaTicks = (details.delta.dx / tickScale).round();
                  var newStart = _snapTick(math.max(0, note.startTick + deltaTicks));
                  if (endTick - newStart < grid) {
                    newStart = endTick - grid;
                  }
                  note.durationTicks = math.max(grid, endTick - newStart);
                  note.startTick = math.max(0, newStart);
                });
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
              onHorizontalDragStart: (_) => _commitUndoState(),
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _selectedIndex = index;
                  final deltaTicks = (details.delta.dx / tickScale).round();
                  final newDur = _snapTick(
                    math.max(grid, note.durationTicks + deltaTicks),
                  );
                  note.durationTicks = math.max(grid, newDur);
                });
              },
              child: Container(color: const Color(0x33FFFFFF)),
            ),
          ),
        ],
      ),
    );
  }

  String _midiToLabel(int midiNote) {
    const names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
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
    for (final n in notes) {
      n.note = _closestNoteInScale(n.note, constraint.tonic, allowedPitchClasses);
    }
  }

  int _closestNoteInScale(int midiNote, int tonic, Set<int> scale) {
    var best = midiNote;
    var bestDistance = 999;
    for (var delta = -3; delta <= 3; delta++) {
      final candidate = (midiNote + delta).clamp(0, 127);
      final pitchClass = ((candidate - tonic) % 12 + 12) % 12;
      if (!scale.contains(pitchClass)) continue;
      final distance = (candidate - midiNote).abs();
      if (distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
      }
    }
    return best;
  }

  void _alignNotesToStart(List<EditableMidiNote> notes) {
    if (notes.isEmpty) return;
    final firstTick = notes
        .map((n) => n.startTick)
        .reduce(math.min);
    if (firstTick <= 0) return;
    for (final note in notes) {
      note.startTick = math.max(0, note.startTick - firstTick);
    }
  }
}

class KeyScaleConstraint {
  const KeyScaleConstraint({required this.tonic, required this.isMinor});

  final int tonic;
  final bool isMinor;
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class PlayPreviewIntent extends Intent {
  const PlayPreviewIntent();
}

class EditableMidiNote {
  EditableMidiNote({
    required this.note,
    required this.startTick,
    required this.durationTicks,
    required this.velocity,
  });

  factory EditableMidiNote.copy(EditableMidiNote n) => EditableMidiNote(
        note: n.note,
        startTick: n.startTick,
        durationTicks: n.durationTicks,
        velocity: n.velocity,
      );

  int note;
  int startTick;
  int durationTicks;
  int velocity;
}

class ParsedMidi {
  ParsedMidi({
    required this.ticksPerQuarter,
    required this.tempoBpm,
    required this.beatsPerMeasure,
    required this.beatUnit,
    required this.notes,
  });

  final int ticksPerQuarter;
  final int tempoBpm;
  final int beatsPerMeasure;
  final int beatUnit;
  final List<EditableMidiNote> notes;

  static ParsedMidi? tryParse(Uint8List bytes) {
    if (bytes.length < 14 || String.fromCharCodes(bytes.sublist(0, 4)) != 'MThd') {
      return null;
    }
    final headerLength = _readUint32BE(bytes, 4);
    if (headerLength < 6 || bytes.length < 8 + headerLength) return null;
    final ticksPerQuarter = (bytes[12] << 8) | bytes[13];
    var tempoBpm = 120;
    var beatsPerMeasure = 4;
    var beatUnit = 4;
    final notes = <EditableMidiNote>[];

    var chunkOffset = 8 + headerLength;
    while (chunkOffset + 8 <= bytes.length) {
      final chunkType = String.fromCharCodes(bytes.sublist(chunkOffset, chunkOffset + 4));
      final chunkLength = _readUint32BE(bytes, chunkOffset + 4);
      final chunkDataStart = chunkOffset + 8;
      final chunkDataEnd = chunkDataStart + chunkLength;
      if (chunkDataEnd > bytes.length) break;

      if (chunkType == 'MTrk') {
        var idx = chunkDataStart;
        var tick = 0;
        var runningStatus = 0;
        final active = <int, int>{};

        while (idx < chunkDataEnd) {
          final delta = _readVarLen(bytes, idx);
          idx = delta.next;
          tick += delta.value;
          if (idx >= chunkDataEnd) break;

          var status = bytes[idx];
          if (status < 0x80) {
            if (runningStatus == 0) {
              break;
            }
            status = runningStatus;
          } else {
            idx++;
            runningStatus = status;
          }

          if (status == 0xFF) {
            if (idx + 1 > chunkDataEnd) break;
            final metaType = bytes[idx++];
            final len = _readVarLen(bytes, idx);
            idx = len.next;
            if (metaType == 0x51 && len.value == 3 && idx + 2 < chunkDataEnd) {
              final mpq = (bytes[idx] << 16) | (bytes[idx + 1] << 8) | bytes[idx + 2];
              if (mpq > 0) tempoBpm = (60000000 / mpq).round();
            } else if (metaType == 0x58 && len.value >= 2 && idx + 1 < chunkDataEnd) {
              beatsPerMeasure = bytes[idx].clamp(1, 12);
              final denominatorPower = bytes[idx + 1].clamp(0, 8);
              beatUnit = 1 << denominatorPower;
            }
            idx += len.value;
            continue;
          }

          if (status == 0xF0 || status == 0xF7) {
            final len = _readVarLen(bytes, idx);
            idx = len.next + len.value;
            continue;
          }

          final eventType = status & 0xF0;
          if (eventType == 0x90 || eventType == 0x80) {
            if (idx + 1 >= chunkDataEnd) break;
            final note = bytes[idx++];
            final velocity = bytes[idx++];
            final isOn = eventType == 0x90 && velocity > 0;
            if (isOn) {
              active[note] = tick;
            } else {
              final start = active.remove(note);
              if (start != null && tick > start) {
                notes.add(
                  EditableMidiNote(
                    note: note,
                    startTick: start,
                    durationTicks: tick - start,
                    velocity: math.max(1, velocity),
                  ),
                );
              }
            }
            continue;
          }

          if (eventType == 0xC0 || eventType == 0xD0) {
            idx += 1;
          } else {
            idx += 2;
          }
        }
      }
      chunkOffset = chunkDataEnd;
    }

    if (notes.isEmpty) return null;
    notes.sort((a, b) => a.startTick.compareTo(b.startTick));
    return ParsedMidi(
      ticksPerQuarter: ticksPerQuarter > 0 ? ticksPerQuarter : 480,
      tempoBpm: tempoBpm,
      beatsPerMeasure: beatsPerMeasure,
      beatUnit: beatUnit,
      notes: notes,
    );
  }

  Uint8List rebuild(
    List<EditableMidiNote> edited, {
    int? tempoOverrideBpm,
    int? beatsPerMeasureOverride,
    int? beatUnitOverride,
  }) {
    final track = <int>[];
    final effectiveTempo = math.max(1, tempoOverrideBpm ?? tempoBpm);
    final effectiveBeatsPerMeasure = (beatsPerMeasureOverride ?? beatsPerMeasure).clamp(1, 12);
    final allowedBeatUnits = {1, 2, 4, 8, 16, 32, 64, 128, 256};
    final candidateBeatUnit = beatUnitOverride ?? beatUnit;
    final effectiveBeatUnit = allowedBeatUnits.contains(candidateBeatUnit)
        ? candidateBeatUnit
        : 4;
    final mpq = (60000000 / effectiveTempo).round();
    final denominatorPower = (math.log(effectiveBeatUnit) / math.ln2).round().clamp(0, 8);
    track.addAll([
      0x00, 0xFF, 0x51, 0x03, (mpq >> 16) & 0xFF, (mpq >> 8) & 0xFF, mpq & 0xFF,
      0x00, 0xFF, 0x58, 0x04, effectiveBeatsPerMeasure, denominatorPower, 0x18, 0x08,
      0x00, 0xC0, 0x00,
    ]);

    final events = <_MidiEditEvent>[];
    for (final n in edited) {
      final start = math.max(0, n.startTick).toInt();
      final end = start + math.max(1, n.durationTicks).toInt();
      events.add(_MidiEditEvent(start, true, n.note, n.velocity.clamp(1, 127)));
      events.add(_MidiEditEvent(end, false, n.note, 0));
    }
    events.sort((a, b) {
      final t = a.tick.compareTo(b.tick);
      if (t != 0) return t;
      if (a.on == b.on) return 0;
      return a.on ? 1 : -1;
    });

    var prevTick = 0;
    for (final e in events) {
      track.addAll(_writeVarLen(math.max(0, e.tick - prevTick)));
      track.add(e.on ? 0x90 : 0x80);
      track.add(e.note.clamp(0, 127));
      track.add(e.velocity.clamp(0, 127));
      prevTick = e.tick;
    }
    track.addAll([0x00, 0xFF, 0x2F, 0x00]);

    return Uint8List.fromList([
      0x4D, 0x54, 0x68, 0x64,
      0x00, 0x00, 0x00, 0x06,
      0x00, 0x00,
      0x00, 0x01,
      (ticksPerQuarter >> 8) & 0xFF, ticksPerQuarter & 0xFF,
      0x4D, 0x54, 0x72, 0x6B,
      (track.length >> 24) & 0xFF,
      (track.length >> 16) & 0xFF,
      (track.length >> 8) & 0xFF,
      track.length & 0xFF,
      ...track,
    ]);
  }

  static _VarResult _readVarLen(Uint8List bytes, int start) {
    var idx = start;
    var value = 0;
    int b;
    do {
      if (idx >= bytes.length) break;
      b = bytes[idx++];
      value = (value << 7) | (b & 0x7F);
    } while ((b & 0x80) != 0);
    return _VarResult(value, idx);
  }

  static List<int> _writeVarLen(int value) {
    var buffer = value & 0x7F;
    while ((value >>= 7) > 0) {
      buffer <<= 8;
      buffer |= ((value & 0x7F) | 0x80);
    }
    final out = <int>[];
    while (true) {
      out.add(buffer & 0xFF);
      if ((buffer & 0x80) != 0) {
        buffer >>= 8;
      } else {
        break;
      }
    }
    return out;
  }

  static int _readUint32BE(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }
}

class _VarResult {
  const _VarResult(this.value, this.next);
  final int value;
  final int next;
}

class _MidiEditEvent {
  const _MidiEditEvent(this.tick, this.on, this.note, this.velocity);
  final int tick;
  final bool on;
  final int note;
  final int velocity;
}
