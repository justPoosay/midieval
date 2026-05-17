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
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:http/http.dart' as http;
import 'package:midieval/app_localization.dart';
import 'package:midieval/midi_models.dart';

const String _brandLogoAsset = 'assets/branding/logo_concept.svg';
const String _brandLogoMarkAsset = 'assets/branding/logo_mark.svg';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ValueNotifier<AppLanguage> _language = ValueNotifier<AppLanguage>(
    AppLanguage.en,
  );

  @override
  void dispose() {
    _language.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppLocalizationScope(
      notifier: _language,
      child: ValueListenableBuilder<AppLanguage>(
        valueListenable: _language,
        builder: (context, language, _) {
          return MaterialApp(
            locale: Locale(language == AppLanguage.pl ? 'pl' : 'en'),
            title: context.tr('app_title'),
            theme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF6EE7FF),
                onPrimary: Color(0xFF05222B),
                secondary: Color(0xFFC084FC),
                onSecondary: Color(0xFF2A1742),
                surface: Color(0xFF131A2B),
                onSurface: Color(0xFFEAF0FF),
                onSurfaceVariant: Color(0xFF9FB0D8),
                outline: Color(0xFF2E3B5C),
                error: Color(0xFFFF6B7A),
              ),
              scaffoldBackgroundColor: const Color(0xFF090E1A),
              textTheme: GoogleFonts.manropeTextTheme(
                ThemeData.dark().textTheme,
              ),
              cardTheme: CardThemeData(
                color: const Color(0xFF131A2B),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              appBarTheme: const AppBarTheme(
                centerTitle: false,
                backgroundColor: Colors.transparent,
                foregroundColor: Color(0xFFEAF0FF),
                elevation: 0,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFF0F1628),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFF2E3B5C)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFF2E3B5C)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: Color(0xFF6EE7FF),
                    width: 1.5,
                  ),
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6EE7FF),
                  foregroundColor: const Color(0xFF06212A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEAF0FF),
                  side: const BorderSide(color: Color(0xFF3D4E77)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(shape: const StadiumBorder()),
              ),
              useMaterial3: true,
            ),
            home: const AuthCheck(),
          );
        },
      ),
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
            SvgPicture.asset(_brandLogoAsset, width: 280),
            const SizedBox(height: 20),
            Text(
              context.tr('app_title'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text(context.tr('auth_subtitle')),
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
class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _savingUsername = false;
  bool _savingPassword = false;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final metadataName = user?.userMetadata?['username']?.toString();
    final fallback = user?.email?.split('@').first ?? '';
    _usernameController.text = (metadataName?.isNotEmpty ?? false)
        ? metadataName!
        : fallback;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveUsername() async {
    final name = _usernameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _savingUsername = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final data = <String, dynamic>{...(user?.userMetadata ?? {})};
      data['username'] = name;
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: data),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('username_saved'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('error_prefix')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingUsername = false);
    }
  }

  Future<void> _changePassword() async {
    final pass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (pass.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('password_too_short'))));
      return;
    }
    if (pass != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('password_mismatch'))));
      return;
    }

    setState(() => _savingPassword = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: pass),
      );
      if (!mounted) return;
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('password_saved'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('error_prefix')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentLanguage = AppLocalizationScope.languageOf(context);
    final email = Supabase.instance.client.auth.currentUser?.email ?? '-';

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile_settings'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF131A2B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('email'),
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: context.tr('username'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _savingUsername ? null : _saveUsername,
                    child: _savingUsername
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.tr('save_username')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF131A2B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.tr('new_password'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.tr('confirm_password'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: _savingPassword ? null : _changePassword,
                    child: _savingPassword
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.tr('change_password')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF131A2B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('language'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                DropdownButton<AppLanguage>(
                  value: currentLanguage,
                  items: [
                    DropdownMenuItem(
                      value: AppLanguage.en,
                      child: Text(context.tr('english')),
                    ),
                    DropdownMenuItem(
                      value: AppLanguage.pl,
                      child: Text(context.tr('polish')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    AppLocalizationScope.setLanguage(context, value);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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

class _JumpingNotesOverlay extends StatelessWidget {
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
      duration: const Duration(milliseconds: 1600),
      curve: Curves.easeOutQuart,
      builder: (context, value, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            final centerX = width * 0.5;
            final centerY = height * 0.56;
            const glyphs = ['*', '+', 'o', 'x', '.'];
            const colors = <Color>[
              Color(0xFF6EE7FF),
              Color(0xFFC084FC),
              Color(0xFFFFD166),
              Color(0xFF8BFFB7),
            ];
            return Stack(
              children: List<Widget>.generate(44, (i) {
                final localDelay = (i % 11) * 0.025;
                final p = ((value - localDelay) / (1 - localDelay)).clamp(
                  0.0,
                  1.0,
                );
                if (p <= 0) return const SizedBox.shrink();
                final angle = ((i * 33) % 360) * (math.pi / 180.0);
                final speed = 110.0 + ((i * 19) % 140);
                final flight = Curves.easeOut.transform(p);
                final dx = math.cos(angle) * speed * flight;
                final dy = math.sin(angle) * speed * flight + (190.0 * p * p);
                final spin = (i.isEven ? 1 : -1) * (p * math.pi * 2.6);
                final alpha = (1.0 - p).clamp(0.0, 1.0);
                final size = 10.0 + (i % 5) * 4.0;
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
                        scale: 0.85 + ((1 - p) * 0.35),
                        child: Text(
                          glyph,
                          style: TextStyle(
                            fontSize: size,
                            fontWeight: FontWeight.w900,
                            color: color,
                            shadows: [
                              Shadow(
                                color: color.withValues(alpha: 0.55),
                                blurRadius: 10,
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
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
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
          .match({'id': sketchId});
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
              fileName,
              file,
              fileOptions: const FileOptions(
                contentType: 'audio/wav',
                upsert: true,
              ),
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

    final fileName = filePath.split('/').last;
    await Supabase.instance.client.from('sketches').delete().match({'id': id});
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
      final midiFileName = _storageMidiFileName(sketchId: sketchId);

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
            'audio_path': midiUrl,
            'status': 'ready',
            'last_error': null,
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
        await Supabase.instance.client
            .from('sketches')
            .update({
              'title':
                  _sketchTitleById(request.sketchId) ??
                  'Recording ${request.sketchId}',
              'status': 'ready',
              'last_error': null,
            })
            .match({'id': request.sketchId});

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
      await Supabase.instance.client.storage
          .from('audio-samples')
          .uploadBinary(
            midiFileName,
            processedMidiBytes,
            fileOptions: const FileOptions(
              contentType: 'audio/midi',
              upsert: true,
            ),
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
      await Supabase.instance.client
          .from('sketches')
          .update({
            'title':
                _sketchTitleById(request.sketchId) ??
                'Recording ${request.sketchId}',
            'status': 'ready',
            'last_error': null,
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
            .match({'id': request.sketchId}),
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
                                      tooltip: 'Rename',
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
          if (_showJumpingNotes)
            Positioned.fill(
              child: IgnorePointer(
                child: _JumpingNotesOverlay(
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
      final midiUrl = Supabase.instance.client.storage
          .from('audio-samples')
          .getPublicUrl(midiFileName);

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
        : _notes.map((e) => e.startTick + e.durationTicks).reduce(math.max) +
              widget.parsed.ticksPerQuarter;

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
                                              widget.beatsPerMeasureOverride) /
                                          widget.beatUnitOverride)
                                      .round();
                              final beatTicks =
                                  ((widget.parsed.ticksPerQuarter * 4) /
                                          widget.beatUnitOverride)
                                      .round();
                              return Listener(
                                onPointerDown: (event) {
                                  if ((event.buttons & kSecondaryMouseButton) !=
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
                                      (event.buttons & kSecondaryMouseButton) !=
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
                                        child: Container(
                                          height: 1,
                                          color: const Color(0xFF1E2128),
                                        ),
                                      ),
                                    if (_isPreviewPlaying || _playheadTick > 0)
                                      Positioned(
                                        left: (_playheadTick * tickScale).clamp(
                                          0.0,
                                          inner.maxWidth - 1,
                                        ),
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
                  var newStart = _snapTick(
                    math.max(0, note.startTick + deltaTicks),
                  );
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
    for (final n in notes) {
      n.note = _closestNoteInScale(
        n.note,
        constraint.tonic,
        allowedPitchClasses,
      );
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
    final firstTick = notes.map((n) => n.startTick).reduce(math.min);
    if (firstTick <= 0) return;
    for (final note in notes) {
      note.startTick = math.max(0, note.startTick - firstTick);
    }
  }
}

