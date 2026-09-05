/// Domain models for Community Events (Home tile + details + registration).
library;

enum EventJoinAvailability {
  canJoin,
  joined,
  disabled,
  deadlinePassed,
  full,
  ended,
}

class CommunityEvent {
  final String id;
  final String title;
  final String? shortDescription;
  final String? fullDescription;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? locationName;
  final String? mapUrl;
  final String? imagePath;
  final bool registrationEnabled;
  final DateTime? registrationDeadline;
  final int? maxParticipants;
  final bool isPublished;

  const CommunityEvent({
    required this.id,
    required this.title,
    this.shortDescription,
    this.fullDescription,
    required this.startsAt,
    required this.endsAt,
    this.locationName,
    this.mapUrl,
    this.imagePath,
    this.registrationEnabled = true,
    this.registrationDeadline,
    this.maxParticipants,
    this.isPublished = true,
  });

  factory CommunityEvent.fromJson(Map<String, dynamic> json) {
    return CommunityEvent(
      id: json['id'] as String,
      title: (json['title'] as String?)?.trim() ?? '',
      shortDescription: (json['short_description'] as String?)?.trim(),
      fullDescription: (json['full_description'] as String?)?.trim(),
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
      locationName: (json['location_name'] as String?)?.trim(),
      mapUrl: (json['map_url'] as String?)?.trim(),
      imagePath: (json['image_path'] as String?)?.trim(),
      registrationEnabled: json['registration_enabled'] as bool? ?? true,
      registrationDeadline: json['registration_deadline'] != null
          ? DateTime.parse(json['registration_deadline'] as String).toLocal()
          : null,
      maxParticipants: (json['max_participants'] as num?)?.toInt(),
      isPublished: json['is_published'] as bool? ?? true,
    );
  }

  bool get isHappeningNow {
    final now = DateTime.now();
    return !now.isBefore(startsAt) && now.isBefore(endsAt);
  }

  bool get hasEnded => !DateTime.now().isBefore(endsAt);

  bool get hasValidMapUrl {
    final u = mapUrl;
    if (u == null || u.isEmpty) return false;
    final uri = Uri.tryParse(u);
    return uri != null &&
        (uri.isScheme('https') || uri.isScheme('http')) &&
        uri.host.isNotEmpty;
  }
}

/// Safe home/details payload — never includes other attendees' PII.
class CommunityEventCardData {
  final CommunityEvent event;
  final int attendeeCount;
  final bool isRegistered;

  const CommunityEventCardData({
    required this.event,
    required this.attendeeCount,
    required this.isRegistered,
  });

  factory CommunityEventCardData.fromJson(Map<String, dynamic> json) {
    final eventRaw = json['event'];
    final eventMap = eventRaw is Map
        ? Map<String, dynamic>.from(eventRaw)
        : <String, dynamic>{};
    return CommunityEventCardData(
      event: CommunityEvent.fromJson(eventMap),
      attendeeCount: (json['attendee_count'] as num?)?.toInt() ?? 0,
      isRegistered: json['is_registered'] as bool? ?? false,
    );
  }

  CommunityEventCardData copyWith({
    CommunityEvent? event,
    int? attendeeCount,
    bool? isRegistered,
  }) {
    return CommunityEventCardData(
      event: event ?? this.event,
      attendeeCount: attendeeCount ?? this.attendeeCount,
      isRegistered: isRegistered ?? this.isRegistered,
    );
  }

  EventJoinAvailability joinAvailability({DateTime? now}) {
    final n = now ?? DateTime.now();
    if (isRegistered) return EventJoinAvailability.joined;
    if (event.hasEnded || !n.isBefore(event.endsAt)) {
      return EventJoinAvailability.ended;
    }
    if (!event.registrationEnabled) return EventJoinAvailability.disabled;
    final deadline = event.registrationDeadline;
    if (deadline != null && !n.isBefore(deadline)) {
      return EventJoinAvailability.deadlinePassed;
    }
    final max = event.maxParticipants;
    if (max != null && attendeeCount >= max) {
      return EventJoinAvailability.full;
    }
    return EventJoinAvailability.canJoin;
  }
}

class EventRegistrationResult {
  final bool ok;
  final bool alreadyRegistered;
  final int? attendeeCount;
  final String? errorCode;

  const EventRegistrationResult({
    required this.ok,
    this.alreadyRegistered = false,
    this.attendeeCount,
    this.errorCode,
  });

  factory EventRegistrationResult.fromJson(Map<String, dynamic> json) {
    return EventRegistrationResult(
      ok: json['ok'] == true,
      alreadyRegistered: json['already_registered'] == true,
      attendeeCount: (json['attendee_count'] as num?)?.toInt(),
      errorCode: json['error'] as String?,
    );
  }
}
