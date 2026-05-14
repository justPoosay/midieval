import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
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

class _MyHomePageState extends State<MyHomePage> {
  static const int _recordingSampleRate = 44100;
  static const String _basicPitchBridgeUrl =
      'http://127.0.0.1:8090/audio-to-midi';

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
  bool isRecording = false;
  final TextEditingController _timeSigTopController = TextEditingController(
    text: '4',
  );
  final TextEditingController _timeSigBottomController = TextEditingController(
    text: '4',
  );

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
      return;
    }

    if (_playingSketchId != null) {
      setState(() => _playingSketchId = null);
    }
  }

  Future<void> _configureAudioPlayer({
    PlayerMode mode = PlayerMode.mediaPlayer,
  }) async {
    await audioPlayer.setPlayerMode(mode);
    await audioPlayer.setReleaseMode(ReleaseMode.stop);
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
        setState(() => isRecording = true);
      }
    } catch (e) {
      debugPrint("Błąd nagrywania: $e");
    }
  }

  Future<void> stopRecording() async {
    int? localId;
    try {
      final path = await audioRecorder.stop();
      setState(() => isRecording = false);

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
        setState(() => _playingSketchId = sketchId);
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
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(_basicPitchBridgeUrl),
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
    try {
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
      final editedMidiBytes = await _openMidiEditor(midiBytes);
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
    }
  }

  Future<Uint8List?> _openMidiEditor(Uint8List midiBytes) async {
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
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MidiEditorDialog(parsed: parsed),
    );
  }

  @override
  void dispose() {
    _playbackResetTimer?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _timeSigTopController.dispose();
    _timeSigBottomController.dispose();
    audioRecorder.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
      body: SafeArea(
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
                  onTap: isRecording ? stopRecording : startRecording,
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
                          isRecording
                              ? "Tap to stop and save"
                              : "Record a melody",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isRecording
                              ? "Saving as a 44.1 kHz WAV clip"
                              : "Hum or sing a short phrase",
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
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
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tempo: Auto Detect',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
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
                      final isUploading = item['_is_uploading'] == true;
                      final uploadFailed = item['_upload_failed'] == true;

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
                              item['created_at'].toString().substring(0, 10),
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
                                      : () => convertAudioToMidi(
                                          audioPath,
                                          itemId,
                                        ),
                                  tooltip: "Konwertuj na MIDI",
                                ),
                                IconButton(
                                  icon: Icon(
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
    );
  }
}

class MidiEditorDialog extends StatefulWidget {
  const MidiEditorDialog({super.key, required this.parsed});

  final ParsedMidi parsed;

  @override
  State<MidiEditorDialog> createState() => _MidiEditorDialogState();
}

class _MidiEditorDialogState extends State<MidiEditorDialog> {
  late List<EditableMidiNote> _notes;
  int _selectedIndex = -1;
  int _gridDivider = 8;
  static const int _beatsPerBar = 4;
  final List<List<EditableMidiNote>> _undoStack = [];
  final List<List<EditableMidiNote>> _redoStack = [];

  @override
  void initState() {
    super.initState();
    _notes = widget.parsed.notes
        .map((n) => EditableMidiNote.copy(n))
        .toList()
      ..sort((a, b) => a.startTick.compareTo(b.startTick));
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
    final grid = (widget.parsed.ticksPerQuarter / _gridDivider).round();
    if (grid <= 0) return;
    setState(() {
      for (final note in _notes) {
        note.startTick = ((note.startTick / grid).round() * grid).clamp(0, 1 << 30);
        note.durationTicks = math.max(
          grid,
          ((note.durationTicks / grid).round() * grid),
        );
      }
      _notes.sort((a, b) => a.startTick.compareTo(b.startTick));
    });
  }

  int _gridTick() {
    return math.max(1, (widget.parsed.ticksPerQuarter / _gridDivider).round());
  }

  int _snapTick(int tick) {
    final grid = _gridTick();
    return (tick / grid).round() * grid;
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
    final minNote = _notes.isEmpty
        ? 48
        : _notes.map((e) => e.note).reduce(math.min);
    final maxNote = _notes.isEmpty
        ? 72
        : _notes.map((e) => e.note).reduce(math.max);
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
        },
        child: Focus(
          autofocus: true,
          child: AlertDialog(
      title: const Text('Edit MIDI'),
      content: SizedBox(
        width: 760,
        height: 420,
        child: Column(
          children: [
            Row(
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
                    DropdownMenuItem(value: 8, child: Text('1/8')),
                    DropdownMenuItem(value: 16, child: Text('1/16')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _gridDivider = value);
                  },
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _quantizeAll,
                  child: const Text('Quantize'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final noteSpan = math.max(12, maxNote - minNote + 1);
                  final laneHeight = constraints.maxHeight / noteSpan;
                  return Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: _buildPianoKeys(
                          maxNote: maxNote,
                          noteSpan: noteSpan,
                          laneHeight: laneHeight,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF111216),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: LayoutBuilder(
                            builder: (context, inner) {
                              final tickScale = inner.maxWidth / math.max(1, tickEnd);
                              final barTicks = widget.parsed.ticksPerQuarter * _beatsPerBar;
                              final beatTicks = widget.parsed.ticksPerQuarter;
                              return Stack(
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
                                  for (var i = 0; i < _notes.length; i++)
                                    _buildNoteRect(
                                      i,
                                      _notes[i],
                                      maxNote: maxNote,
                                      laneHeight: laneHeight,
                                      tickScale: tickScale,
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
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
            final output = widget.parsed.rebuild(_notes);
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

  Widget _buildPianoKeys({
    required int maxNote,
    required int noteSpan,
    required double laneHeight,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1014),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          for (var i = 0; i < noteSpan; i++)
            Positioned(
              top: i * laneHeight,
              left: 0,
              right: 0,
              height: laneHeight,
              child: Container(
                color: _isBlackKey(maxNote - i)
                    ? const Color(0xFF1B1E26)
                    : const Color(0xFFECECEC),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.centerLeft,
                child: Text(
                  _midiToLabel(maxNote - i),
                  style: TextStyle(
                    fontSize: 10,
                    color: _isBlackKey(maxNote - i) ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoteRect(
    int index,
    EditableMidiNote note, {
    required int maxNote,
    required double laneHeight,
    required double tickScale,
  }) {
    final top = (maxNote - note.note);
    final rectTop = (math.max(0, top.toDouble())) * laneHeight;
    final left = note.startTick * tickScale;
    final width = math.max(6.0, note.durationTicks * tickScale);
    final grid = _gridTick();
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
                  color: _selectedIndex == index
                      ? const Color(0xFFF39C12)
                      : const Color(0xFF57C86A),
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

  bool _isBlackKey(int midiNote) {
    final pc = midiNote % 12;
    return pc == 1 || pc == 3 || pc == 6 || pc == 8 || pc == 10;
  }

  String _midiToLabel(int midiNote) {
    const names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    return '${names[midiNote % 12]}${(midiNote ~/ 12) - 1}';
  }
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
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
    required this.notes,
  });

  final int ticksPerQuarter;
  final int tempoBpm;
  final List<EditableMidiNote> notes;

  static ParsedMidi? tryParse(Uint8List bytes) {
    if (bytes.length < 14 || String.fromCharCodes(bytes.sublist(0, 4)) != 'MThd') {
      return null;
    }
    final headerLength = _readUint32BE(bytes, 4);
    if (headerLength < 6 || bytes.length < 8 + headerLength) return null;
    final ticksPerQuarter = (bytes[12] << 8) | bytes[13];
    var tempoBpm = 120;
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
      notes: notes,
    );
  }

  Uint8List rebuild(List<EditableMidiNote> edited) {
    final track = <int>[];
    final mpq = (60000000 / math.max(1, tempoBpm)).round();
    track.addAll([
      0x00, 0xFF, 0x51, 0x03, (mpq >> 16) & 0xFF, (mpq >> 8) & 0xFF, mpq & 0xFF,
      0x00, 0xFF, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08,
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



