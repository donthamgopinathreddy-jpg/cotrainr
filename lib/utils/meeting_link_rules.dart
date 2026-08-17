/// Provider-neutral meeting link + join eligibility helpers.
class MeetingLinkRules {
  MeetingLinkRules._();

  static String? validateHttpsMeetingLink(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter a meeting link';
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter a valid meeting link';
    }
    if (uri.scheme.toLowerCase() != 'https') {
      return 'Meeting link must start with https://';
    }
    return null;
  }

  static bool isValidHttpsMeetingLink(String? raw) =>
      validateHttpsMeetingLink(raw) == null;

  /// Detect a display label from the URL host (never stored as credentials).
  static String? detectProviderLabel(String? raw) {
    final uri = Uri.tryParse(raw?.trim() ?? '');
    final host = uri?.host.toLowerCase() ?? '';
    if (host.isEmpty) return null;
    if (host.contains('meet.google') || host == 'meet.google.com') {
      return 'Google Meet';
    }
    if (host.contains('zoom.')) return 'Zoom';
    if (host.contains('teams.microsoft') || host.contains('teams.live')) {
      return 'Microsoft Teams';
    }
    if (host.contains('whereby.')) return 'Whereby';
    return 'Meeting link';
  }
}

enum VideoSessionJoinEligibility {
  joinable,
  cancelled,
  missingLink,
  invalidLink,
  past,
  tooEarly,
}

class VideoSessionJoinRules {
  VideoSessionJoinRules._();

  static const joinEarlyWindow = Duration(minutes: 5);

  static VideoSessionJoinEligibility evaluate({
    required String status,
    required DateTime scheduledStart,
    required int durationMinutes,
    required String? joinUrl,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    if (status == 'cancelled') return VideoSessionJoinEligibility.cancelled;
    final link = joinUrl?.trim() ?? '';
    if (link.isEmpty) return VideoSessionJoinEligibility.missingLink;
    if (!MeetingLinkRules.isValidHttpsMeetingLink(link)) {
      return VideoSessionJoinEligibility.invalidLink;
    }
    final end = scheduledStart.add(Duration(minutes: durationMinutes));
    final windowStart = scheduledStart.subtract(joinEarlyWindow);
    final windowEnd = end.add(const Duration(minutes: 30));
    if (clock.isAfter(windowEnd)) return VideoSessionJoinEligibility.past;
    if (clock.isBefore(windowStart)) {
      return VideoSessionJoinEligibility.tooEarly;
    }
    return VideoSessionJoinEligibility.joinable;
  }

  static bool canJoin(VideoSessionJoinEligibility e) =>
      e == VideoSessionJoinEligibility.joinable;
}
