part of 'package:midieval/app.dart';

class _HomePageView extends StatelessWidget {
  const _HomePageView({required this.state});

  final _MyHomePageState state;

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
            tooltip: 'Tutorial',
            icon: const Icon(Icons.help_outline),
            onPressed: null,
          ),
          IconButton(
            key: state._settingsIconKey,
            tooltip: context.tr('settings'),
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileSettingsPage()),
              );
              state._triggerUiRefresh();
            },
          ),
          IconButton(
            tooltip: context.tr('logout'),
            icon: const Icon(Icons.logout),
            onPressed: () async {
              state._clearLocalAudioCache();
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
                _HomeRecordPanelBuilder.build(state, context, colorScheme),
                _HomeConversionSummaryPanelBuilder.build(
                  state,
                  context,
                  colorScheme,
                ),
                _HomeSketchesHeaderBuilder.build(state, context),
                _HomeSketchesListBuilder.build(state, context, colorScheme),
              ],
            ),
          ),
          if (state._showJumpingNotes)
            Positioned.fill(
              child: IgnorePointer(
                child: _FullScreenConfettiOverlay(
                  key: ValueKey<int>(state._jumpingNotesSeed),
                ),
              ),
            ),
          if (state._isGeneratingMidiPreview)
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
}
