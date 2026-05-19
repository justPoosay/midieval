part of 'package:midieval/app.dart';

class _HomeSketchesListBuilder {
  static Widget build(
    _MyHomePageState state,
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Expanded(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: state._sketchesFuture,
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
                    style: const TextStyle(fontWeight: FontWeight.w700),
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
              final isPlaying = state._playingSketchId == itemId;
              final isLoading = state._loadingSketchId == itemId;
              final isUploading = item['_is_uploading'] == true;
              final uploadFailed = item['_upload_failed'] == true;
              final job = state._conversionJobs[itemId];
              final jobActive =
                  job != null &&
                  (job.status == _ConversionStatus.queued ||
                      job.status == _ConversionStatus.running);

              return Dismissible(
                key: Key(itemId.toString()),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => state.deleteSketch(itemId, audioPath),
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
                    side: const BorderSide(color: Color(0xFF263150)),
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
                        color: colorScheme.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.graphic_eq, color: colorScheme.primary),
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
                          : item['created_at'].toString().substring(0, 10),
                    ),
                    trailing: Wrap(
                      key: index == 0 ? state._firstSketchActionsKey : null,
                      spacing: 12,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Color(0xFF9FB0D8),
                          ),
                          onPressed: isUploading
                              ? null
                              : () => state._renameSketch(
                                  sketchId: itemId,
                                  currentTitle:
                                      item['title']?.toString() ?? 'Recording',
                                ),
                          tooltip: context.tr('rename'),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.auto_awesome,
                            color: Colors.deepPurpleAccent,
                          ),
                          onPressed: isUploading
                              ? null
                              : jobActive
                              ? null
                              : () =>
                                    state.convertAudioToMidi(audioPath, itemId),
                          tooltip: context.tr('convert_to_midi'),
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
                              state.playOrStopSketch(itemId, audioPath),
                          tooltip: isPlaying
                              ? context.tr('stop_playback')
                              : context.tr('play_clip'),
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
    );
  }
}
