part of 'package:midieval/app.dart';

class _HomeConversionSummaryPanelBuilder {
  static Widget build(
    _MyHomePageState state,
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        key: state._conversionCardKey,
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
                  Icon(Icons.tune, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('settings_card'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: state._openConversionSettingsSheet,
                    icon: const Icon(Icons.open_in_full, size: 16),
                    label: Text(context.tr('open')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                state._lockTempo
                    ? 'Tempo: ${state._parseTempoBpm()} BPM (locked)'
                    : context.tr('tempo_auto'),
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                state._lockMeter
                    ? 'Meter: ${state._parseMeter().beatsPerMeasure}/${state._parseMeter().beatUnit} (locked)'
                    : context.tr('meter_auto'),
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                state._constrainToScale
                    ? 'Key/Scale: ${state._selectedKey} ${state._selectedScale}'
                    : context.tr('scale_off'),
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: state._openConversionSettingsSheet,
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
    );
  }
}
