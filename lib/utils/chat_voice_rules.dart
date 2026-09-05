/// Voice-note limits and filename duration encoding (no extra DB column).
abstract final class ChatVoiceRules {
  static const Duration maxDuration = Duration(minutes: 5);
  static const Duration minDuration = Duration(seconds: 1);
  static const int maxBytes = 10 * 1024 * 1024; // 10 MB
  static const String mediaKind = 'audio';
  static const String mimeType = 'audio/mp4';
  static const String fileExtension = '.m4a';

  static int get maxDurationMs => maxDuration.inMilliseconds;
  static int get minDurationMs => minDuration.inMilliseconds;

  /// Encode duration into the stored file name: `voice_12345ms.m4a`.
  static String fileNameForDuration(int durationMs) {
    final ms = durationMs.clamp(0, maxDurationMs);
    return 'voice_${ms}ms$fileExtension';
  }

  /// Parse duration from [media_file_name] when present.
  static int? durationMsFromFileName(String? name) {
    if (name == null || name.isEmpty) return null;
    final match = RegExp(
      r'voice_(\d+)ms',
      caseSensitive: false,
    ).firstMatch(name);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  static String formatDuration(Duration d) {
    final total = d.inSeconds.clamp(0, 99 * 60);
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static bool isTooShort(int durationMs) => durationMs < minDurationMs;

  static bool isAtMax(int durationMs) => durationMs >= maxDurationMs;
}
