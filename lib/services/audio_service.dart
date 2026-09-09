import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AudioRecordResult {
  final File file;
  final int durationSeconds;

  AudioRecordResult({required this.file, required this.durationSeconds});
}

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  
  String? _recordingPath;
  DateTime? _recordingStartTime;
  String? _currentlyPlayingUrl;

  String? get currentlyPlayingUrl => _currentlyPlayingUrl;

  // --- Recorder ---

  // Check and request microphone permission
  Future<bool> checkPermission() async {
    return await _recorder.hasPermission();
  }

  // Start recording voice note
  Future<void> startRecording() async {
    try {
      if (await checkPermission()) {
        final Directory tempDir = await getTemporaryDirectory();
        final String path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _recordingPath = path;
        _recordingStartTime = DateTime.now();
        
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // Stop recording voice note and return file + duration
  Future<AudioRecordResult?> stopRecording() async {
    try {
      final String? path = await _recorder.stop();
      final durationSeconds = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inSeconds
          : 0;
      _recordingStartTime = null;

      if (path != null && _recordingPath == path) {
        final file = File(path);
        if (await file.exists()) {
          return AudioRecordResult(
            file: file,
            durationSeconds: durationSeconds > 0 ? durationSeconds : 1,
          );
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Cancel current recording
  Future<void> cancelRecording() async {
    try {
      await _recorder.stop();
      _recordingStartTime = null;
      if (_recordingPath != null) {
        final File file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      // Ignore errors on cleanup
    }
  }

  // --- Playback ---

  // Play audio from URL
  Future<void> playAudio(String url) async {
    try {
      if (_currentlyPlayingUrl == url && _player.state == PlayerState.paused) {
        await _player.resume();
        return;
      }
      await _player.stop();
      _currentlyPlayingUrl = url;
      await _player.play(UrlSource(url));
    } catch (e) {
      rethrow;
    }
  }

  // Pause playback
  Future<void> pauseAudio() async {
    await _player.pause();
  }

  // Resume playback
  Future<void> resumeAudio() async {
    await _player.resume();
  }

  // Stop playback
  Future<void> stopAudio() async {
    await _player.stop();
    _currentlyPlayingUrl = null;
  }

  // Seek
  Future<void> seekAudio(Duration position) async {
    await _player.seek(position);
  }

  // Get stream of playback position
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;

  // Get stream of audio duration
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;

  // Get stream of playback state changes
  Stream<PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;

  // Get completion stream
  Stream<void> get onPlayerComplete => _player.onPlayerComplete;

  // Dispose resources
  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
