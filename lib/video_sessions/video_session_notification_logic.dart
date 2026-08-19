/// Client-side mirrors of video-session notification rules (SQL is source of truth).
class VideoSessionNotificationLogic {
  static const types = [
    'video_session_created',
    'video_session_rescheduled',
    'video_session_cancelled',
    'video_session_reminder_5m',
    'video_session_starting',
    'video_session_rejected',
  ];

  static const createdType = 'video_session_created';
  static const reminder5mType = 'video_session_reminder_5m';
  static const startingType = 'video_session_starting';
  static const rejectedType = 'video_session_rejected';

  static const reminder5mTitle = 'Video session in 5 minutes';
  static const startingTitle = 'Video session starting now';

  static const rejectReasonCodes = [
    'cant_attend',
    'running_late',
    'need_to_reschedule',
    'emergency',
    'other',
  ];

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
    if (names.length > 1) {
      final extra = names.length - 1;
      return extra == 1
          ? 'with ${names.first} + 1 other'
          : 'with ${names.first} + $extra others';
    }
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

  static Map<String, dynamic> reminderPayload({
    required String type,
    required String sessionId,
    required String hostId,
    required String counterpartName,
    required DateTime scheduledStart,
    String? joinUrl,
    String? sessionTitle,
    int durationMinutes = 30,
    String status = 'scheduled',
  }) {
    return {
      'type': type,
      'notification_type': type,
      'video_session_id': sessionId,
      'host_id': hostId,
      'scheduled_start': scheduledStart.toUtc().toIso8601String(),
      'counterpart_name': counterpartName,
      'join_url': joinUrl,
      'session_title': sessionTitle,
      'duration_minutes': durationMinutes,
      'status': status,
      'actions': ['join', 'reject'],
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

  static String startingBody({
    required String counterpartName,
  }) =>
      'Your session with $counterpartName is ready.';

  static String rejectedTitle(String actorName) => "$actorName can't attend";

  static String rejectedBody(String reasonLabel) => 'Reason: $reasonLabel';

  static String rejectReasonLabel(String code, {String? otherText}) {
    switch (code) {
      case 'cant_attend':
        return "Can't attend";
      case 'running_late':
        return 'Running late';
      case 'need_to_reschedule':
        return 'Need to reschedule';
      case 'emergency':
        return 'Emergency';
      case 'other':
        final custom = otherText?.trim();
        return (custom != null && custom.isNotEmpty) ? custom : 'Other';
      default:
        return "Can't attend";
    }
  }

  static String notifiedSnackbar(String counterpartRole) {
    return counterpartRole == 'client' ? 'Client notified' : 'Trainer notified';
  }

  static bool isActionableReminderType(String? type) {
    return type == reminder5mType || type == startingType;
  }

  static bool shouldDispatchReminder({
    required String status,
    required String kind,
    required DateTime scheduledStart,
    required int durationMinutes,
    required DateTime now,
    bool participantRejected = false,
    bool sessionDeleted = false,
  }) {
    if (sessionDeleted) return false;
    if (status != 'scheduled') return false;
    if (participantRejected) return false;
    if (kind == 'reminder_5m' && !now.isBefore(scheduledStart)) return false;
    if (kind == 'starting' &&
        now.isAfter(scheduledStart.add(Duration(minutes: durationMinutes)))) {
      return false;
    }
    return true;
  }

  /// Server verifies membership; this is the client-side mirror for tests.
  static bool canRespond({
    required String actorId,
    required Iterable<String> memberIds,
  }) {
    if (actorId.isEmpty) return false;
    return memberIds.contains(actorId);
  }
}
