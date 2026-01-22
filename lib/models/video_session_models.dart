enum Role {
  client,
  trainer,
  nutritionist,
}

enum MeetingStatus {
  upcoming,
  live,
  ended,
  canceled,
}

enum MeetingPrivacy {
  inviteOnly,
  publicCode,
}

class Meeting {
  final String meetingId;
  final String title;
  final String hostUserId;
  final Role hostRole;
  final DateTime createdAt;
  final DateTime? scheduledFor;
  final DateTime? startedAt; // When the meeting actually started (for timer persistence)
  final int? durationMins;
  final int maxParticipants;
  final bool isInstant;
  final int participantsCount;
  final MeetingStatus status;
  final String joinCode;
  final MeetingPrivacy privacy;
  final List<Role> allowedRoles;
  final String? notes;
  
  // ShareKey format: "MeetingID-MeetingCode" (example: "483921-Q7K9M2")
  String get shareKey {
    return '$meetingId-$joinCode';
  }

  Meeting({
    required this.meetingId,
    required this.title,
    required this.hostUserId,
    required this.hostRole,
    required this.createdAt,
    this.scheduledFor,
    this.startedAt,
    this.durationMins,
    this.maxParticipants = 10,
    this.isInstant = true,
    this.participantsCount = 0,
    this.status = MeetingStatus.upcoming,
    required this.joinCode,
    this.privacy = MeetingPrivacy.publicCode,
    required this.allowedRoles,
    this.notes,
  });
}

class Participant {
  final String userId;
  final String displayName;
  final Role role;
  final String? avatarUrl;
  final bool isHost;
  final DateTime? joinedAt;
  final bool muted;
  final bool videoOff;

  Participant({
    required this.userId,
    required this.displayName,
    required this.role,
    this.avatarUrl,
    this.isHost = false,
    this.joinedAt,
    this.muted = false,
    this.videoOff = false,
  });
}
