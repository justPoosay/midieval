part of 'package:midieval/app.dart';

extension _HomePageAudioPlayback on _MyHomePageState {
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

    if (_HomePageConversionFlow._isMidiSource(audioUrl)) {
      final sourceAudioUrl = await _sourceAudioUrlForMidiUrl(audioUrl);
      if (sourceAudioUrl != null) {
        try {
          final localPath = await _localPlaybackPathForUrl(sourceAudioUrl);
          _cachedAudioPathBySketchId[sketchId] = localPath;
          return localPath;
        } catch (e) {
          debugPrint('Could not resolve inferred source recording: $e');
        }
      }
    }

    final localPath = await _localPlaybackPathForUrl(audioUrl);
    _cachedAudioPathBySketchId[sketchId] = localPath;
    return localPath;
  }

  Future<String?> _sourceAudioUrlForMidiUrl(String midiUrl) async {
    final uri = Uri.tryParse(midiUrl);
    if (uri == null) return null;
    final path = uri.path;
    final lowerPath = path.toLowerCase();
    final sourcePath = lowerPath.endsWith('.midi')
        ? '${path.substring(0, path.length - 5)}.wav'
        : lowerPath.endsWith('.mid')
        ? '${path.substring(0, path.length - 4)}.wav'
        : null;
    if (sourcePath == null) return null;
    return uri.replace(path: sourcePath).toString();
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

      _applyState(() {
        _loadingSketchId = sketchId;
        _playingSketchId = null;
      });
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

      _applyState(() {
        _playingSketchId = sketchId;
        _loadingSketchId = null;
      });
      _schedulePlaybackReset(sketchId, playbackDuration);
    } catch (e) {
      debugPrint('Playback failed: $e');
      if (mounted) {
        _clearPlayingSketch();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('playback_failed')}: $e'),
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

  Future<Uint8List> _convertWithBasicPitch(Uint8List audioBytes) async {
    final bridgeHost = Platform.isAndroid
        ? _MyHomePageState._basicPitchBridgeHostAndroidEmulator
        : _MyHomePageState._basicPitchBridgeHostDesktop;
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
}
