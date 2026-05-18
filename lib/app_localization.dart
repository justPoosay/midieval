import 'package:flutter/material.dart';

enum AppLanguage { en, pl }

class AppLocalizationScope
    extends InheritedNotifier<ValueNotifier<AppLanguage>> {
  const AppLocalizationScope({
    super.key,
    required ValueNotifier<AppLanguage> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ValueNotifier<AppLanguage> notifierOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppLocalizationScope>();
    assert(scope != null, 'AppLocalizationScope not found in widget tree');
    return scope!.notifier!;
  }

  static AppLanguage languageOf(BuildContext context) =>
      notifierOf(context).value;

  static void setLanguage(BuildContext context, AppLanguage language) {
    notifierOf(context).value = language;
  }
}

class AppStrings {
  static const Map<String, String> _en = {
    'app_title': 'MIDieval',
    'auth_subtitle': 'Sign in to create melody sketches',
    'email': 'Email',
    'password': 'Password',
    'sign_in': 'Sign In',
    'sign_up': 'Sign Up',
    'registered': 'Registered! Check your email.',
    'error_prefix': 'Error',
    'settings': 'Settings',
    'logout': 'Logout',
    'profile_settings': 'Profile and Settings',
    'username': 'Username',
    'save_username': 'Save Username',
    'new_password': 'New Password',
    'confirm_password': 'Confirm Password',
    'change_password': 'Change Password',
    'language': 'Language',
    'english': 'English',
    'polish': 'Polish',
    'password_mismatch': 'Passwords do not match.',
    'password_too_short': 'Password must be at least 6 characters.',
    'username_saved': 'Username updated.',
    'password_saved': 'Password updated.',
    'record_melody': 'Record a melody',
    'tap_to_stop': 'Tap to stop and save',
    'saving_clip': 'Saving clip...',
    'hum_prompt': 'Hum or sing a short phrase',
    'settings_card': 'Conversion Settings',
    'open': 'Open',
    'edit_settings': 'Edit Settings',
    'tempo_auto': 'Tempo: auto-detect',
    'meter_auto': 'Meter: auto-detect',
    'scale_off': 'Key/Scale: unconstrained',
    'sketches': 'Sketches',
    'no_sketches': 'No sketches yet',
    'rename': 'Rename',
    'convert_to_midi': 'Convert to MIDI',
    'play_clip': 'Play clip',
    'stop_playback': 'Stop playback',
    'playback_failed': 'Could not play clip',
    'audio_download_failed': 'Could not download audio file',
    'random_melody_generated': 'Random melody generated',
    'random_melody_failed': 'Random melody failed',
    'done': 'Done',
    'tutorial_title': 'Quick Tutorial',
    'tutorial_skip': 'Skip',
    'tutorial_convert_hint':
        'Step 1/4: Tap Convert on the seeded C-major tutorial sketch.',
    'tutorial_quantize_hint':
        'Step 2/4: Use Quantize to align notes to the grid.',
    'tutorial_edit_hint': 'Step 3/4: Drag or resize a note to edit the melody.',
    'tutorial_apply_hint':
        'Step 4/4: Press Apply to confirm and save the MIDI preview.',
    'tutorial_seed_title': 'Tutorial C Major Scale',
  };

  static const Map<String, String> _pl = {
    'app_title': 'MIDieval',
    'auth_subtitle': 'Zaloguj sie, aby tworzyc szkice melodii',
    'email': 'Email',
    'password': 'Haslo',
    'sign_in': 'Wejdz',
    'sign_up': 'Dolacz',
    'registered': 'Zarejestrowano! Sprawdz email.',
    'error_prefix': 'Blad',
    'settings': 'Ustawienia',
    'logout': 'Wyloguj',
    'profile_settings': 'Profil i Ustawienia',
    'username': 'Nazwa uzytkownika',
    'save_username': 'Zapisz nazwe',
    'new_password': 'Nowe haslo',
    'confirm_password': 'Potwierdz haslo',
    'change_password': 'Zmien haslo',
    'language': 'Jezyk',
    'english': 'Angielski',
    'polish': 'Polski',
    'password_mismatch': 'Hasla nie sa takie same.',
    'password_too_short': 'Haslo musi miec min. 6 znakow.',
    'username_saved': 'Nazwa uzytkownika zaktualizowana.',
    'password_saved': 'Haslo zaktualizowane.',
    'record_melody': 'Nagraj melodie',
    'tap_to_stop': 'Dotknij, aby zatrzymac i zapisac',
    'saving_clip': 'Zapisywanie klipu...',
    'hum_prompt': 'Nuc lub spiewaj krotka fraze',
    'settings_card': 'Ustawienia Konwersji',
    'open': 'Otworz',
    'edit_settings': 'Edytuj ustawienia',
    'tempo_auto': 'Tempo: auto-detekcja',
    'meter_auto': 'Metrum: auto-detekcja',
    'scale_off': 'Tonacja/Skala: bez ograniczen',
    'sketches': 'Szkice',
    'no_sketches': 'Brak szkicow',
    'rename': 'Zmien nazwe',
    'convert_to_midi': 'Konwertuj na MIDI',
    'play_clip': 'Odtworz klip',
    'stop_playback': 'Zatrzymaj odtwarzanie',
    'playback_failed': 'Nie udalo sie odtworzyc klipu',
    'audio_download_failed': 'Nie udalo sie pobrac pliku audio',
    'random_melody_generated': 'Wygenerowano losowa melodie',
    'random_melody_failed': 'Generowanie losowej melodii nie powiodlo sie',
    'done': 'Gotowe',
    'tutorial_title': 'Szybki samouczek',
    'tutorial_skip': 'Pomin',
    'tutorial_convert_hint':
        'Krok 1/4: Dotknij Konwertuj na szkicu samouczka C-dur.',
    'tutorial_quantize_hint':
        'Krok 2/4: Uzyj Quantize, aby wyrownac nuty do siatki.',
    'tutorial_edit_hint':
        'Krok 3/4: Przeciagnij lub rozciagnij note, aby edytowac melodie.',
    'tutorial_apply_hint':
        'Krok 4/4: Nacisnij Apply, aby potwierdzic i zapisac podglad MIDI.',
    'tutorial_seed_title': 'Samouczek Skala C-dur',
  };

  static String of(BuildContext context, String key) {
    final language = AppLocalizationScope.languageOf(context);
    final table = language == AppLanguage.pl ? _pl : _en;
    return table[key] ?? _en[key] ?? key;
  }
}

extension AppTr on BuildContext {
  String tr(String key) => AppStrings.of(this, key);
}
