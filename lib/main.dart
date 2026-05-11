import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:http/http.dart' as http;

import 'midi_engine.dart';

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

  final AudioRecorder audioRecorder = AudioRecorder();
  final AudioPlayer audioPlayer = AudioPlayer();
  StreamSubscription<void>? _playerCompleteSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  Timer? _playbackResetTimer;
  final Map<String, String> _cachedPlaybackPaths = {};
  final List<Map<String, dynamic>> _sessionSketches = [];
  List<Map<String, dynamic>> _remoteSketches = [];
  late Future<List<Map<String, dynamic>>> _sketchesFuture;
  int _nextLocalSketchId = -1;
  int? _playingSketchId;
  bool isRecording = false;

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
          audioFocus: AndroidAudioFocus.gainTransient,
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

        _cachedPlaybackPaths[path] = path;
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
        _cachedPlaybackPaths[publicUrl] = path;

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
      await _removeCachedPlaybackFile(filePath);
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
    await _removeCachedPlaybackFile(filePath);
    _removeSessionSketch(id);
    _refreshSketches();
  }

  Future<String> _localPlaybackPathForUrl(String audioUrl) async {
    final directFile = File(audioUrl);
    if (await directFile.exists() && await directFile.length() > 0) {
      return audioUrl;
    }

    final cachedPath = _cachedPlaybackPaths[audioUrl];
    if (cachedPath != null) {
      final cachedFile = File(cachedPath);
      if (await cachedFile.exists() && await cachedFile.length() > 0) {
        return cachedPath;
      }
    }

    final uri = Uri.parse(audioUrl);
    final response = await http.get(uri);
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw Exception("Nie udało się pobrać pliku audio do odtworzenia");
    }

    final tempDirectory = await getTemporaryDirectory();
    final playbackDirectory = Directory(
      '${tempDirectory.path}/midieval_playback',
    );
    if (!await playbackDirectory.exists()) {
      await playbackDirectory.create(recursive: true);
    }

    final sourceName = uri.pathSegments.isEmpty
        ? 'clip.wav'
        : uri.pathSegments.last;
    final safeName = sourceName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final fileName = '${audioUrl.hashCode}_$safeName';
    final localFile = File('${playbackDirectory.path}/$fileName');
    await localFile.writeAsBytes(response.bodyBytes, flush: true);

    _cachedPlaybackPaths[audioUrl] = localFile.path;
    return localFile.path;
  }

  Future<void> _removeCachedPlaybackFile(String audioUrl) async {
    final cachedPath = _cachedPlaybackPaths.remove(audioUrl);
    if (cachedPath == null) return;

    final cachedFile = File(cachedPath);
    if (await cachedFile.exists()) {
      await cachedFile.delete();
    }
  }

  Future<void> playOrStopSketch(int sketchId, String audioUrl) async {
    try {
      if (_playingSketchId == sketchId) {
        await audioPlayer.stop();
        _clearPlayingSketch();
        return;
      }

      _playbackResetTimer?.cancel();
      await audioPlayer.release();
      final localPlaybackPath = await _localPlaybackPathForUrl(audioUrl);
      await _configureAudioPlayerForSource(localPlaybackPath);
      final playbackDuration = await _playbackDurationForPath(
        localPlaybackPath,
      );
      await audioPlayer.setSourceDeviceFile(localPlaybackPath);
      await Future<void>.delayed(const Duration(milliseconds: 120));
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

  Future<void> _configureAudioPlayerForSource(String sourcePath) async {
    final extension = sourcePath.split('.').last.toLowerCase();
    final mode = extension == 'wav'
        ? PlayerMode.lowLatency
        : PlayerMode.mediaPlayer;
    await _configureAudioPlayer(mode: mode);
  }

  Future<Uint8List> _downloadAudioBytes(String audioUrl) async {
    final response = await http.get(Uri.parse(audioUrl));
    if (response.statusCode != 200) {
      throw Exception("Nie udało się pobrać pliku audio");
    }
    return response.bodyBytes;
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
      final midiBytes = MidiEngine.generateMidiFromAudio(audioBytes);

      // 4. Tworzymy unikalną nazwę, żeby uniknąć starych plików w pamięci
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final midiFileName = "melody_${sketchId}_$timestamp.midi";

      // 5. Upload do Supabase Storage
      await Supabase.instance.client.storage
          .from('audio-samples')
          .uploadBinary(
            midiFileName,
            midiBytes,
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

  @override
  void dispose() {
    _playbackResetTimer?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
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
