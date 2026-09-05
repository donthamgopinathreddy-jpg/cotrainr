import 'package:just_audio/just_audio.dart';

/// Ensures only one voice bubble plays at a time within the app process.
class ChatVoicePlaybackController {
  ChatVoicePlaybackController._();
  static final ChatVoicePlaybackController instance =
      ChatVoicePlaybackController._();

  final AudioPlayer player = AudioPlayer();
  String? _activeKey;

  String? get activeKey => _activeKey;

  bool isActive(String key) => _activeKey == key;

  Future<void> play({
    required String key,
    required String url,
  }) async {
    if (_activeKey != null && _activeKey != key) {
      await player.stop();
    }
    _activeKey = key;
    if (player.playing && isActive(key)) {
      await player.pause();
      return;
    }
    if (player.audioSource == null || !isActive(key)) {
      await player.setUrl(url);
    }
    await player.play();
  }

  Future<void> playFile({
    required String key,
    required String path,
  }) async {
    if (_activeKey != null && _activeKey != key) {
      await player.stop();
    }
    _activeKey = key;
    await player.setFilePath(path);
    await player.play();
  }

  Future<void> pause() async {
    await player.pause();
  }

  Future<void> stopAll() async {
    _activeKey = null;
    await player.stop();
  }

  Future<void> dispose() async {
    await stopAll();
    await player.dispose();
  }
}
