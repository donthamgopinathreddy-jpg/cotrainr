/// Client-side mirrors of video-session notification rules (SQL is source of truth).
class VideoSessionNotificationLogic {
  static const types = [
    'video_session_created',
    'video_session_rescheduled',
    'video_session_cancelled',
    'video_session_reminder_5m',
    'video_session_starting',
  ];

  static const createdType = 'video_session_created';

  static String idempotencyKey({
    required String sessionId,
    required String userId,
    required String kind,
  }) =>
      '$sessionId|$userId|$kind';

  static String displayName({
    String? fullName,
    String? username,
  }) {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final user = username?.trim();
    if (user != null && user.isNotEmpty) return user;
    return '';
  }

  static String withLine({
    required List<String> participantNames,
    String? counterpartyName,
  }) {
    final names = participantNames
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (names.length == 1) return 'with ${names.first}';
    if (names.length > 1) return 'with ${names.first} +${names.length - 1}';
    final fallback = counterpartyName?.trim();
    if (fallback != null && fallback.isNotEmpty) return 'with $fallback';
    return 'with your session partner';
  }

  static bool shouldShowGenericPartnerFallback({
    required List<String> participantNames,
    String? counterpartyName,
  }) {
    return withLine(
          participantNames: participantNames,
          counterpartyName: counterpartyName,
        ) ==
        'with your session partner';
  }

  static Map<String, dynamic> createdPayload({
    required String sessionId,
    required String hostId,
    required String counterpartName,
    required DateTime scheduledStart,
    String? joinUrl,
    String? sessionTitle,
  }) {
    return {
      'type': createdType,
      'video_session_id': sessionId,
      'host_id': hostId,
      'scheduled_start': scheduledStart.toUtc().toIso8601String(),
      'counterpart_name': counterpartName,
      'host_name': counterpartName,
      if (joinUrl != null) 'join_url': joinUrl,
      if (sessionTitle != null) 'session_title': sessionTitle,
    };
  }

  static String createdBody({
    required String hostName,
    required String whenLabel,
  }) =>
      '$hostName scheduled a session with you for $whenLabel.';

  static String reminderBody({
    required String counterpartName,
    required String whenLabel,
  }) =>
      'Your session with $counterpartName starts at $whenLabel.';

  static bool shouldDispatchReminder({
    required String status,
    required String kind,
    required DateTime scheduledStart,
    required int durationMinutes,
    required DateTime now,
  }) {
    if (status != 'scheduled') return false;
    if (kind == 'reminder_5m' && !now.isBefore(scheduledStart)) return false;
    if (kind == 'starting' &&
        now.isAfter(scheduledStart.add(Duration(minutes: durationMinutes)))) {
      return false;
    }
    return true;
  }
}
