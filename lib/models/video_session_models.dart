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
  final int? durationMins;
  final int maxParticipants;
  final bool isInstant;
  final int participantsCount;
  final MeetingStatus status;
  final String joinCode;
  final MeetingPrivacy privacy;
  final List<Role> allowedRoles;
  final String? notes;

  Meeting({
    required this.meetingId,
    required this.title,
    required this.hostUserId,
    required this.hostRole,
    required this.createdAt,
    this.scheduledFor,
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
