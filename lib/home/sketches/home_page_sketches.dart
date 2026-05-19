part of 'package:midieval/app.dart';

extension _HomePageSketches on _MyHomePageState {
  Future<List<Map<String, dynamic>>> getSketches() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _remoteSketches = [];
      return _mergedSketches();
    }
    final data = await Supabase.instance.client
        .from('sketches')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    _remoteSketches = List<Map<String, dynamic>>.from(data);
    return _mergedSketches();
  }

  void _refreshSketches() {
    if (!mounted) return;
    _applyState(() {
      _sketchesFuture = getSketches();
    });
  }

  void _showSessionSketches() {
    if (!mounted) return;
    _applyState(() {
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

  Map<String, Object> _ownedSketchFilter(int sketchId) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return {'id': sketchId};
    }
    return {'id': sketchId, 'user_id': userId};
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
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
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
          .match(_ownedSketchFilter(sketchId));
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

  String _storagePathForUserFile(String fileName, {String? userId}) {
    final uid =
        userId ?? Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';
    return '$uid/$fileName';
  }

  String _storagePathFromPublicUrl(String publicUrl) {
    final uri = Uri.tryParse(publicUrl);
    if (uri == null) return publicUrl.split('/').last;
    final bucketIndex = uri.pathSegments.indexOf('audio-samples');
    if (bucketIndex >= 0 && bucketIndex + 1 < uri.pathSegments.length) {
      return uri.pathSegments.sublist(bucketIndex + 1).join('/');
    }
    return uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : publicUrl.split('/').last;
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
        final path =
            '${directory.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
        await audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: _MyHomePageState._recordingSampleRate,
            numChannels: 1,
          ),
          path: path,
        );
        _applyState(() {
          isRecording = true;
          _recordingStartedAt = DateTime.now();
          _recordingElapsed = Duration.zero;
        });
        _recordingTicker?.cancel();
        _recordingTicker = Timer.periodic(const Duration(milliseconds: 200), (
          _,
        ) {
          if (!mounted || !isRecording || _recordingStartedAt == null) return;
          _applyState(() {
            _recordingElapsed = DateTime.now().difference(_recordingStartedAt!);
          });
        });
      }
    } catch (e) {
      debugPrint('Recording failed: $e');
    }
  }

  Future<void> stopRecording() async {
    int? localId;
    try {
      final path = await audioRecorder.stop();
      _recordingTicker?.cancel();
      _applyState(() {
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
            _applyState(() => _isSavingRecording = false);
          }
          return;
        }
        final fileStem = _storageStemFromTitle(title);
        final fileName = '$fileStem.wav';
        final userId = Supabase.instance.client.auth.currentUser!.id;
        final storagePath = _storagePathForUserFile(fileName, userId: userId);
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

        await Supabase.instance.client.storage
            .from('audio-samples')
            .upload(
              storagePath,
              file,
              fileOptions: const FileOptions(
                contentType: 'audio/wav',
                upsert: true,
              ),
            );

        final publicUrl = Supabase.instance.client.storage
            .from('audio-samples')
            .getPublicUrl(storagePath);
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
        _applyState(() => _isSavingRecording = false);
      }
    } catch (e) {
      debugPrint('Upload failed: $e');
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
        _applyState(() => _isSavingRecording = false);
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

    final fileName = _storagePathFromPublicUrl(filePath);
    await Supabase.instance.client
        .from('sketches')
        .delete()
        .match(_ownedSketchFilter(id));
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
}
