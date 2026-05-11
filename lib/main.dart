import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart'; // Biblioteka do nagrywania
import 'package:path_provider/path_provider.dart'; // Do znajdowania folderów na telefonie
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://bbmpvmdpqbrerjrnzjkk.supabase.co/rest/v1/',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJibXB2bWRwcWJyZXJqcm56amtrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg0NTIyMjYsImV4cCI6MjA5NDAyODIyNn0.NhaL48LASXPKvvWMNNP8orswoZKRbUa3L0nyuCjdNj8',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final AudioRecorder audioRecorder = AudioRecorder();
  bool isRecording = false;
  String? audioPath;

  // Funkcja rozpoczynająca nagrywanie
  Future<void> startRecording() async {
    try {
      // 1. Sprawdź uprawnienia
      if (await audioRecorder.hasPermission()) {
        // 2. Znajdź miejsce na zapis pliku
        final directory = await getApplicationDocumentsDirectory();
        final String path = '${directory.path}/moje_nucenie_${DateTime.now().millisecondsSinceEpoch}.m4a';

        // 3. Konfiguracja i start
        const config = RecordConfig(); 
        await audioRecorder.start(config, path: path);

        setState(() {
          isRecording = true;
          audioPath = path;
        });
        print("Nagrywanie rozpoczęte: $path");
      }
    } catch (e) {
      print("Błąd nagrywania: $e");
    }
  }

  // Funkcja zatrzymująca nagrywanie
  Future<void> stopRecording() async {
    try {
      final path = await audioRecorder.stop();
      setState(() {
        isRecording = false;
      });
      print("Nagrywanie zakończone. Plik zapisany w: $path");
      
      // Tutaj w przyszłości dodamy wysyłanie do Supabase!
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Nagrano barda! Zapisano w $path")),
      );
    } catch (e) {
      print("Błąd przy zatrzymywaniu: $e");
    }
  }

  @override
  void dispose() {
    audioRecorder.dispose(); // Zwalniamy zasoby mikrofonu
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.amber.shade700,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ikona zmieniająca się podczas nagrywania
            Icon(
              isRecording ? Icons.mic : Icons.mic_none,
              size: 100,
              color: isRecording ? Colors.red : Colors.amber,
            ),
            const SizedBox(height: 20),
            Text(
              isRecording ? "Słucham Cię, Bardzie..." : "Naciśnij, by zacząć nucenie",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 50),
            // Główny przycisk
            ElevatedButton(
              onPressed: isRecording ? stopRecording : startRecording,
              style: ElevatedButton.styleFrom(
                backgroundColor: isRecording ? Colors.red : Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                shape: const StadiumBorder(),
              ),
              child: Text(
                isRecording ? "ZAKOŃCZ" : "NAGRAJ POMYSŁ",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}