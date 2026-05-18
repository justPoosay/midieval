part of 'app.dart';

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
      ).showSnackBar(
        SnackBar(content: Text('${context.tr('error_prefix')}: $e')),
      );
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
        SnackBar(content: Text(context.tr('registered'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text('${context.tr('error_prefix')}: $e')),
      );
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
              decoration: InputDecoration(
                labelText: context.tr('email'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: context.tr('password'),
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
                      child: Text(context.tr('sign_in')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleSignUp,
                      child: Text(context.tr('sign_up')),
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
