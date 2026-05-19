part of 'package:midieval/app.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key, this.tutorialMode = false});

  final bool tutorialMode;

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
  int _tutorialStep = 0;

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
      body: Stack(
        children: [
          ListView(
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
          if (widget.tutorialMode)
            Positioned.fill(
              child: Stack(
                children: [
                  AbsorbPointer(
                    absorbing: true,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                  ),
                  Positioned(
                    top: _tutorialStep == 0
                        ? 120
                        : _tutorialStep == 1
                        ? 360
                        : 560,
                    left: 12,
                    right: 12,
                    child: Material(
                      color: const Color(0xEE111A2D),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.cyanAccent.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              '↘',
                              style: TextStyle(
                                fontSize: 22,
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _tutorialStep == 0
                                    ? 'Settings: Username section (email + username + save button).'
                                    : _tutorialStep == 1
                                    ? 'Settings: Password section (new password, confirm, change).'
                                    : 'Settings: Language selector (English/Polish).',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                            FilledButton(
                              onPressed: () {
                                if (_tutorialStep >= 2) {
                                  Navigator.of(context).pop();
                                  return;
                                }
                                setState(() => _tutorialStep++);
                              },
                              child: const Text('Next ->'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
