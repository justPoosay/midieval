import 'dart:io';
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
        primarySwatch: Colors.amber,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
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
  static const bool _useSyntheticRecording = true;

  final AudioRecorder audioRecorder = AudioRecorder();
  final AudioPlayer audioPlayer = AudioPlayer();
  bool isRecording = false;

  Future<List<Map<String, dynamic>>> getSketches() async {
    final data = await Supabase.instance.client
        .from('sketches')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> startRecording() async {
    try {
      if (_useSyntheticRecording) {
        await _createSyntheticScaleSketch();
        return;
      }

      if (await audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final String path =
            '${directory.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
        await audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
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

  Future<void> _createSyntheticScaleSketch() async {
    final wavBytes = MidiEngine.generateSineSequenceWav();
    final fileName =
        "synthetic_scale_${DateTime.now().millisecondsSinceEpoch}.wav";
    final userId = Supabase.instance.client.auth.currentUser!.id;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Tworzę testowy WAV: C5-D5-E5-F5-G5-A5-B5-C6"),
        duration: Duration(seconds: 1),
      ),
    );

    await Supabase.instance.client.storage
        .from('audio-samples')
        .uploadBinary(
          fileName,
          wavBytes,
          fileOptions: const FileOptions(contentType: 'audio/wav'),
        );

    final String publicUrl = Supabase.instance.client.storage
        .from('audio-samples')
        .getPublicUrl(fileName);

    await Supabase.instance.client.from('sketches').insert({
      'user_id': userId,
      'title': 'Test sine C5-D5-E5-F5-G5-A5-B5-C6',
      'audio_path': publicUrl,
    });

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> stopRecording() async {
    try {
      final path = await audioRecorder.stop();
      setState(() => isRecording = false);

      if (path != null) {
        final file = File(path);
        final fileName = "voice_${DateTime.now().millisecondsSinceEpoch}.wav";
        final userId = Supabase.instance.client.auth.currentUser!.id;

        // 1. Upload do Storage
        await Supabase.instance.client.storage
            .from('audio-samples')
            .upload(fileName, file);

        // 2. Pobranie Linku
        final String publicUrl = Supabase.instance.client.storage
            .from('audio-samples')
            .getPublicUrl(fileName);

        // 3. Zapis w DB
        await Supabase.instance.client.from('sketches').insert({
          'user_id': userId,
          'title': 'Nucenie ${DateTime.now().hour}:${DateTime.now().minute}',
          'audio_path': publicUrl,
        });

        setState(() {}); // Odśwież listę
      }
    } catch (e) {
      debugPrint("Błąd wysyłki: $e");
    }
  }

  Future<void> deleteSketch(int id, String filePath) async {
    final fileName = filePath.split('/').last;
    await Supabase.instance.client.from('sketches').delete().match({'id': id});
    await Supabase.instance.client.storage.from('audio-samples').remove([
      fileName,
    ]);
    setState(() {});
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
      final response = await http.get(Uri.parse(audioUrl));
      if (response.statusCode != 200) {
        throw Exception("Nie udało się pobrać pliku audio");
      }
      final audioBytes = response.bodyBytes;

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
        setState(() {}); // Odświeżamy listę, żeby zobaczyć nową ikonkę/tytuł
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
    audioRecorder.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Moje Nucenia"),
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
      body: Column(
        children: [
          // PANEL NAGRYWANIA
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: isRecording ? stopRecording : startRecording,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isRecording
                      ? Colors.red.withValues(alpha: 0.2)
                      : Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isRecording ? Colors.red : Colors.amber,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      isRecording ? Icons.stop_circle : Icons.mic,
                      size: 48,
                      color: isRecording ? Colors.red : Colors.amber,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isRecording
                          ? "KLIKNIJ, ABY ZAKOŃCZYĆ"
                          : "ZACZNIJ NAGRYWAĆ POMYSŁ",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // LISTA
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: getSketches(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sketches = snapshot.data ?? [];
                if (sketches.isEmpty) {
                  return const Center(child: Text("Cisza w bibliotece..."));
                }

                return ListView.builder(
                  itemCount: sketches.length,
                  itemBuilder: (context, index) {
                    final item = sketches[index];
                    return Dismissible(
                      key: Key(item['id'].toString()),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) =>
                          deleteSketch(item['id'], item['audio_path']),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete),
                      ),
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          title: Text(item['title']),
                          subtitle: Text(
                            item['created_at'].toString().substring(0, 10),
                          ),
                          trailing: Wrap(
                            spacing: 12, // odstęp między ikonami
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.purple,
                                ), // Ikona magii
                                onPressed: () => convertAudioToMidi(
                                  item['audio_path'],
                                  item['id'],
                                ),
                                tooltip: "Konwertuj na MIDI",
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.amber,
                                ),
                                onPressed: () => audioPlayer.play(
                                  UrlSource(item['audio_path']),
                                ),
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
    );
  }
}
