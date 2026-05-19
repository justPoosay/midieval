part of 'package:midieval/app.dart';

class _HomeRecordPanelBuilder {
  static Widget build(
    _MyHomePageState state,
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Material(
        key: state._recordCardKey,
        color: state.isRecording
            ? const Color(0xFF2B1B24)
            : const Color(0xFF131A2B),
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: state._isSavingRecording
              ? null
              : (state.isRecording
                    ? state.stopRecording
                    : state.startRecording),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: state.isRecording
                    ? Colors.redAccent
                    : colorScheme.primary.withValues(alpha: 0.65),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  state.isRecording ? Icons.stop_circle : Icons.mic,
                  size: 48,
                  color: state.isRecording
                      ? Colors.redAccent
                      : colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  state._isSavingRecording
                      ? context.tr('saving_clip')
                      : state.isRecording
                      ? context.tr('tap_to_stop')
                      : context.tr('record_melody'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state._isSavingRecording
                      ? 'Uploading recording to Supabase'
                      : state.isRecording
                      ? 'Saving as a 44.1 kHz WAV clip'
                      : context.tr('hum_prompt'),
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                if (state.isRecording) ...[
                  const SizedBox(height: 6),
                  Text(
                    state._formatDuration(state._recordingElapsed),
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
                if (state._isSavingRecording) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 3),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
