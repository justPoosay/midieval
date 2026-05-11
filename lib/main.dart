import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // INICJALIZACJA SUPABASE
  await Supabase.initialize(
    url: 'https://bbmpvmdpqbrerjrnzjkk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJibXB2bWRwcWJyZXJqcm56amtrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg0NTIyMjYsImV4cCI6MjA5NDAyODIyNn0.NhaL48LASXPKvvWMNNP8orswoZKRbUa3L0nyuCjdNj8',
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
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'MIDieval: Bard Recorder'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final AudioRecorder audioRecorder = AudioRecorder();
  final AudioPlayer audioPlayer = AudioPlayer();
  bool isRecording = false;

  // FUNKCJA POBIERAJĄCA LISTĘ Z BAZY
  Future<List<Map<String, dynamic>>> getSketches() async {
    final data = await Supabase.instance.client
        .from('sketches')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ROZPOCZĘCIE NAGRYWANIA
  Future<void> startRecording() async {
    try {
      if (await audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final String path = '${directory.path}/nucenie_${DateTime.now().millisecondsSinceEpoch}.m4a';

        const config = RecordConfig();
        await audioRecorder.start(config, path: path);

        setState(() {
          isRecording = true;
        });
      }
    } catch (e) {
      debugPrint("Błąd startu nagrywania: $e");
    }
  }

  // ZATRZYMANIE I WYSYŁKA
  Future<void> stopRecording() async {
    try {
      final path = await audioRecorder.stop();
      setState(() {
        isRecording = false;
      });

      if (path != null) {
        final file = File(path);
        final fileName = "nagranie_${DateTime.now().millisecondsSinceEpoch}.m4a";

        // 1. Wysyłka pliku do Storage
        await Supabase.instance.client.storage
            .from('audio-samples')
            .upload(fileName, file);

        // 2. Pobranie linku
        final String publicUrl = Supabase.instance.client.storage
            .from('audio-samples')
            .getPublicUrl(fileName);

        // 3. Zapis w tabeli sketches
        await Supabase.instance.client.from('sketches').insert({
          'title': 'Nucenie ${DateTime.now().hour}:${DateTime.now().minute}',
          'audio_path': publicUrl,
          'notes': 'Nagrano w MIDieval',
        });

        // 4. Odświeżenie listy na ekranie
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Buntownik zanucił, plik w chmurze! ☁️")),
        );
      }
    } catch (e) {
      debugPrint("Błąd wysyłania: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Błąd: $e")),
      );
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
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Column(
        children: [
          // PANEL NAGRYWANIA (GÓRA)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              border: const Border(bottom: BorderSide(color: Colors.amber, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Icon(
                      isRecording ? Icons.mic : Icons.mic_none,
                      color: isRecording ? Colors.red : Colors.amber,
                      size: 40,
                    ),
                    Text(isRecording ? "SŁUCHAM..." : "CISZA"),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: isRecording ? stopRecording : startRecording,
                  icon: Icon(isRecording ? Icons.stop : Icons.fiber_manual_record),
                  label: Text(isRecording ? "ZAKOŃCZ" : "NAGRAJ POMYSŁ"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRecording ? Colors.red : Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
              ],
            ),
          ),

          // LISTA NAGRAŃ (DÓŁ)
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: getSketches(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("Twoja biblioteka jest pusta."));
                }

                final sketches = snapshot.data!;

                return ListView.builder(
                  itemCount: sketches.length,
                  itemBuilder: (context, index) {
                    final item = sketches[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.amber,
                        child: Icon(Icons.music_note, color: Colors.black),
                      ),
                      title: Text(item['title'] ?? 'Bez tytułu'),
                      subtitle: Text("Data: ${item['created_at'].toString().substring(0, 10)}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_circle_fill, color: Colors.amber, size: 35),
                        onPressed: () async {
                          await audioPlayer.play(UrlSource(item['audio_path']));
                        },
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