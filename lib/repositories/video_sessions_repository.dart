import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/meeting_link_rules.dart';
import '../utils/video_session_error_messages.dart';
import '../video_sessions/video_session_notification_logic.dart';

/// Columns safe for authenticated clients (no obsolete client_id, no token embeds).
const _videoSessionSelectColumns =
    'id, host_id, provider, title, description, scheduled_start, '
    'duration_minutes, max_participants, status, join_url, '
    'provider_meeting_id, created_at, updated_at';

void _logPostgrestError(String operation, Object error) {
  if (!kDebugMode) return;
  if (error is PostgrestException) {
    debugPrint(
      '[VideoSessionsRepository] $operation '
      'code=${error.code} message=${error.message} '
      'details=${error.details} hint=${error.hint}',
    );
    return;
  }
  debugPrint('[VideoSessionsRepository] $operation error=$error');
}

bool isVideoSessionUuid(String value) {
  final v = value.trim();
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(v);
}

class VideoSessionPerson {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String role;

  /// This participant's own attendance response, when the server provides it.
  ///
  /// Null means "not known" — the people RPC does not always project it. Null
  /// must render as no state at all rather than being assumed to be pending,
  /// so a group session never implies a response nobody gave.
  final String? responseStatus;

  const VideoSessionPerson({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.role = 'participant',
    this.responseStatus,
  });

  bool get isHost => role == 'host';
  bool get rejected => responseStatus == 'rejected';
  bool get accepted => responseStatus == 'accepted';
}

/// Supabase-backed provider-neutral video session.
class VideoSession {
  final String id;
  final String hostId;
  final String provider;
  final String title;
  final String? description;
  final DateTime scheduledStart;
  final int durationMinutes;
  final int maxParticipants;
  final String status;
  final String joinUrl;
  final String? providerMeetingId;
  final String? clientId;
  final DateTime createdAt;
  final String? counterpartyName;
  final List<String> participantNames;
  final int participantCount;
  final String? nameResolutionStatus;
  final String? myResponseStatus;
  final String? myResponseReason;
  final DateTime? myRespondedAt;
  final String? counterpartResponseStatus;
  final String? counterpartResponseReason;
  final List<VideoSessionPerson> people;

  VideoSession({
    required this.id,
    required this.hostId,
    required this.provider,
    required this.title,
    this.description,
    required this.scheduledStart,
    required this.durationMinutes,
    required this.maxParticipants,
    required this.status,
    required this.joinUrl,
    this.providerMeetingId,
    this.clientId,
    required this.createdAt,
    this.counterpartyName,
    this.participantNames = const [],
    this.participantCount = 0,
    this.nameResolutionStatus,
    this.myResponseStatus,
    this.myResponseReason,
    this.myRespondedAt,
    this.counterpartResponseStatus,
    this.counterpartResponseReason,
    this.people = const [],
  });

  factory VideoSession.fromJson(
    Map<String, dynamic> json, {
    String? counterpartyName,
  }) {
    final namesRaw = json['participant_names'];
    final parsedNames = namesRaw is List
        ? namesRaw
            .map((e) => e?.toString().trim() ?? '')
            .where((n) => n.isNotEmpty)
            .toList()
        : const <String>[];
    final resolvedName = counterpartyName ??
        (json['counterpart_name'] as String?)?.trim();
    final respondedAtRaw = json['my_responded_at'] as String?;
    return VideoSession(
      id: json['id'] as String,
      hostId: json['host_id'] as String,
      provider: json['provider'] as String? ?? 'external',
      title: json['title'] as String? ?? 'Video Session',
      description: json['description'] as String?,
      scheduledStart: DateTime.parse(json['scheduled_start'] as String).toLocal(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
      maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 5,
      status: json['status'] as String? ?? 'scheduled',
      joinUrl: json['join_url'] as String? ?? '',
      providerMeetingId: json['provider_meeting_id'] as String?,
      clientId: json['client_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      counterpartyName: resolvedName,
      participantNames: parsedNames,
      participantCount: (json['participant_count'] as num?)?.toInt() ??
          parsedNames.length,
      nameResolutionStatus: json['name_resolution_status'] as String?,
      myResponseStatus: json['my_response_status'] as String?,
      myResponseReason: json['my_response_reason'] as String?,
      myRespondedAt: respondedAtRaw == null
          ? null
          : DateTime.tryParse(respondedAtRaw),
      counterpartResponseStatus: json['counterpart_response_status'] as String?,
      counterpartResponseReason: json['counterpart_response_reason'] as String?,
    );
  }

  VideoSession copyWith({
    String? counterpartyName,
    String? status,
    List<String>? participantNames,
    int? participantCount,
    String? nameResolutionStatus,
    String? myResponseStatus,
    String? myResponseReason,
    DateTime? myRespondedAt,
    String? counterpartResponseStatus,
    String? counterpartResponseReason,
    List<VideoSessionPerson>? people,
  }) {
    return VideoSession(
      id: id,
      hostId: hostId,
      provider: provider,
      title: title,
      description: description,
      scheduledStart: scheduledStart,
      durationMinutes: durationMinutes,
      maxParticipants: maxParticipants,
      status: status ?? this.status,
      joinUrl: joinUrl,
      providerMeetingId: providerMeetingId,
      clientId: clientId,
      createdAt: createdAt,
      counterpartyName: counterpartyName ?? this.counterpartyName,
      participantNames: participantNames ?? this.participantNames,
      participantCount: participantCount ?? this.participantCount,
      nameResolutionStatus:
          nameResolutionStatus ?? this.nameResolutionStatus,
      myResponseStatus: myResponseStatus ?? this.myResponseStatus,
      myResponseReason: myResponseReason ?? this.myResponseReason,
      myRespondedAt: myRespondedAt ?? this.myRespondedAt,
      counterpartResponseStatus:
          counterpartResponseStatus ?? this.counterpartResponseStatus,
      counterpartResponseReason:
          counterpartResponseReason ?? this.counterpartResponseReason,
      people: people ?? this.people,
    );
  }

  bool get isScheduled => status == 'scheduled';
  bool get isCancelled => status == 'cancelled';
  bool get isEnded => status == 'ended';
  bool get hasRejected => myResponseStatus == 'rejected';
  bool get counterpartRejected => counterpartResponseStatus == 'rejected';

  /// Invitees excluding the host.
  ///
  /// Takes the larger of the two sources: either can be incomplete, and
  /// under-counting would let a group session be treated as a 1:1.
  int get inviteeCount {
    final fromPeople = people.where((p) => !p.isHost).length;
    return fromPeople > participantCount ? fromPeople : participantCount;
  }

  /// True when more than one person was invited alongside the host.
  ///
  /// `counterpart_response_status` is a single scalar: for a host it is the
  /// first invitee's row only, not an aggregate. Treating it as the session's
  /// status is therefore wrong once there are several invitees.
  bool get isGroupSession => inviteeCount > 1;

  /// Counterpart rejection is only a session-level fact in a 1:1.
  bool get counterpartRejectedOneToOne =>
      !isGroupSession && counterpartRejected;

  /// Per-participant response state, resolved only from authoritative data.
  ///
  /// Returns null when the server did not tell us this person's response.
  String? responseStatusFor(VideoSessionPerson person, {String? myUserId}) {
    if (person.responseStatus != null) return person.responseStatus;
    if (myUserId != null && person.userId == myUserId) return myResponseStatus;
    if (!isGroupSession &&
        myUserId != null &&
        person.userId != myUserId &&
        counterpartResponseStatus != null) {
      return counterpartResponseStatus;
    }
    return null;
  }

  /// Compact summary for group sessions, e.g. "2 accepted · 1 declined".
  ///
  /// Built only from responses the server actually reported. When the people
  /// RPC omits per-participant state we can still say that someone declined
  /// (the scalar proves at least one did) without inventing a count.
  String? get participantResponseSummary {
    if (!isGroupSession) return null;
    final known = people.where((p) => !p.isHost && p.responseStatus != null);
    if (known.isEmpty) {
      return counterpartRejected ? 'Someone declined' : null;
    }
    final declined = known.where((p) => p.rejected).length;
    final accepted = known.where((p) => p.accepted).length;
    final parts = <String>[
      if (accepted > 0) '$accepted accepted',
      if (declined > 0) '$declined declined',
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  DateTime get endsAt =>
      scheduledStart.add(Duration(minutes: durationMinutes));

  bool get isPast {
    if (isCancelled || isEnded) return true;
    return endsAt.isBefore(DateTime.now());
  }

  bool get isUpcoming => isScheduled && !isPast;

  bool includesParticipant(String userId) {
    if (userId.isEmpty) return false;
    if (people.any((p) => p.userId == userId)) return true;
    if (clientId == userId) return true;
    return false;
  }

  VideoSessionJoinEligibility get joinEligibility =>
      VideoSessionJoinRules.evaluate(
        status: status,
        scheduledStart: scheduledStart,
        durationMinutes: durationMinutes,
        joinUrl: joinUrl,
      );

  bool get canJoin =>
      !hasRejected && VideoSessionJoinRules.canJoin(joinEligibility);

  bool get isTooEarlyToJoin =>
      joinEligibility == VideoSessionJoinEligibility.tooEarly;

  /// Counterpart line for list/detail. Never "with Provider" / "with Member".
  String get withLine {
    var names = participantNames;
    if (names.isEmpty && people.isNotEmpty) {
      names = people
          .where((p) => p.role != 'host' && p.displayName.trim().isNotEmpty)
          .map((p) => p.displayName.trim())
          .toList();
    }
    return VideoSessionNotificationLogic.withLine(
      participantNames: names,
      counterpartyName: counterpartyName,
    );
  }

  String? get meetingProviderLabel {
    if (provider == 'google_meet' || provider == 'meet') return 'Google Meet';
    return MeetingLinkRules.detectProviderLabel(joinUrl);
  }

  bool get isGoogleMeet =>
      provider == 'google_meet' || provider == 'meet';
}

/// Whether the Google Meet connection state is known.
///
/// A failed status check is [unknown], never `disconnected` — otherwise a
/// network blip silently tells a connected host to reconnect.
enum GoogleMeetStatusPhase { loading, ready, unknown }

class GoogleMeetIntegrationStatus {
  final bool connected;
  final bool reconnectRequired;
  final String? googleEmail;
  final DateTime? connectedAt;
  final GoogleMeetStatusPhase phase;

  const GoogleMeetIntegrationStatus({
    required this.connected,
    this.reconnectRequired = false,
    this.googleEmail,
    this.connectedAt,
    this.phase = GoogleMeetStatusPhase.ready,
  });

  factory GoogleMeetIntegrationStatus.disconnected() =>
      const GoogleMeetIntegrationStatus(connected: false);

  /// Not checked yet.
  factory GoogleMeetIntegrationStatus.loading() =>
      const GoogleMeetIntegrationStatus(
        connected: false,
        phase: GoogleMeetStatusPhase.loading,
      );

  /// The check failed. Carries the last known values so a transient failure
  /// does not erase a connection we already confirmed.
  factory GoogleMeetIntegrationStatus.unknown({
    GoogleMeetIntegrationStatus? lastKnown,
  }) =>
      GoogleMeetIntegrationStatus(
        connected: lastKnown?.connected ?? false,
        reconnectRequired: lastKnown?.reconnectRequired ?? false,
        googleEmail: lastKnown?.googleEmail,
        connectedAt: lastKnown?.connectedAt,
        phase: GoogleMeetStatusPhase.unknown,
      );

  factory GoogleMeetIntegrationStatus.fromJson(Map<String, dynamic> json) {
    final connectedAtRaw = json['connected_at'] as String?;
    return GoogleMeetIntegrationStatus(
      connected: json['connected'] == true,
      reconnectRequired: json['reconnect_required'] == true,
      googleEmail: json['google_email'] as String?,
      connectedAt: connectedAtRaw == null
          ? null
          : DateTime.tryParse(connectedAtRaw),
    );
  }

  bool get needsConnect => !connected || reconnectRequired;
  bool get isLoading => phase == GoogleMeetStatusPhase.loading;
  bool get isUnknown => phase == GoogleMeetStatusPhase.unknown;

  /// True only when we positively know Google is unusable.
  bool get confirmedNotConnected =>
      phase == GoogleMeetStatusPhase.ready && needsConnect;
}

class VideoSessionCreateException
    implements Exception, VideoSessionResponseCode {
  final String message;
  final String? code;

  VideoSessionCreateException(this.message, {this.code});

  @override
  String? get responseCode => code;

  @override
  String toString() => message;
}

class VideoSessionsRepository {
  VideoSessionsRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Server-authoritative Google Meet connection state.
  ///
  /// Throws when the status could not be determined. A genuinely disconnected
  /// account still returns 200 with `connected: false`, so a non-200 or an
  /// unreadable body means "unknown", and callers must not downgrade that to
  /// "disconnected".
  Future<GoogleMeetIntegrationStatus> getGoogleMeetStatus() async {
    final res = await _supabase.functions.invoke('google-integration-status');
    if (res.status != 200) {
      throw VideoSessionCreateException(
        'google_status_unavailable',
        code: 'GOOGLE_STATUS_UNAVAILABLE',
      );
    }
    final data = res.data;
    if (data is! Map) {
      throw VideoSessionCreateException(
        'google_status_unreadable',
        code: 'GOOGLE_STATUS_UNAVAILABLE',
      );
    }
    return GoogleMeetIntegrationStatus.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  Future<String> getGoogleOAuthUrl() async {
    final res = await _supabase.functions.invoke('google-oauth-start');
    if (res.status != 200) {
      final err = (res.data as Map?)?['error']?.toString();
      throw VideoSessionCreateException(err ?? 'Could not start Google connection');
    }
    final authUrl = (res.data as Map?)?['auth_url'] as String?;
    if (authUrl == null || authUrl.isEmpty) {
      throw VideoSessionCreateException('No Google auth URL returned');
    }
    return authUrl;
  }

  Future<void> disconnectGoogleMeet() async {
    final res = await _supabase.functions.invoke('google-disconnect');
    if (res.status != 200) {
      final err = (res.data as Map?)?['error']?.toString();
      throw VideoSessionCreateException(err ?? 'Could not disconnect Google Meet');
    }
  }

  /// List sessions visible to the current user (RLS).
  Future<List<VideoSession>> listSessions() async {
    try {
      final res = await _supabase.rpc('list_my_video_sessions');
      final sessions = (res as List)
          .map((e) => VideoSession.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _logNameResolution(sessions);
      return await _attachPeople(sessions);
    } catch (e) {
      _logPostgrestError('list_my_video_sessions', e);
      try {
        final res = await _supabase
            .from('video_sessions')
            .select(_videoSessionSelectColumns)
            .inFilter('status', ['scheduled', 'ended', 'cancelled'])
            .order('scheduled_start', ascending: false);

        final sessions = (res as List)
            .map((e) => VideoSession.fromJson(e as Map<String, dynamic>))
            .toList();

        final named = await _attachCounterpartyNames(sessions);
        _logNameResolution(named);
        return await _attachPeople(named);
      } catch (e2) {
        _logPostgrestError('listSessions', e2);
        rethrow;
      }
    }
  }

  /// Next upcoming session that includes [clientId] as a participant.
  Future<VideoSession?> upcomingSessionForClient(String clientId) async {
    try {
      final sessions = await listSessions();
      final upcoming = sessions
          .where((s) => s.isUpcoming && s.includesParticipant(clientId))
          .toList()
        ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
      return upcoming.isEmpty ? null : upcoming.first;
    } catch (e) {
      _logPostgrestError('upcomingSessionForClient', e);
      return null;
    }
  }

  Future<List<VideoSession>> _attachPeople(List<VideoSession> sessions) async {
    if (sessions.isEmpty) return sessions;
    try {
      final res = await _supabase.rpc('list_my_video_session_people');
      final rows = (res as List).cast<dynamic>();
      final bySession = <String, List<VideoSessionPerson>>{};
      for (final raw in rows) {
        final map = Map<String, dynamic>.from(raw as Map);
        final sid = map['session_id'] as String?;
        final uid = map['user_id'] as String?;
        if (sid == null || uid == null) continue;
        bySession.putIfAbsent(sid, () => []).add(
              VideoSessionPerson(
                userId: uid,
                displayName: (map['display_name'] as String?)?.trim() ?? '',
                avatarUrl: map['avatar_url'] as String?,
                role: map['role'] as String? ?? 'participant',
                responseStatus:
                    (map['response_status'] as String?)?.trim().isEmpty ?? true
                        ? null
                        : (map['response_status'] as String).trim(),
              ),
            );
      }
      return sessions
          .map((s) => s.copyWith(people: bySession[s.id] ?? const []))
          .toList();
    } catch (e) {
      _logPostgrestError('list_my_video_session_people', e);
      return sessions;
    }
  }

  void _logNameResolution(List<VideoSession> sessions) {
    if (!kDebugMode) return;
    for (final s in sessions) {
      if (!VideoSessionNotificationLogic.shouldShowGenericPartnerFallback(
        participantNames: s.participantNames,
        counterpartyName: s.counterpartyName,
      )) {
        continue;
      }
      debugPrint(
        '[VideoSessionsRepository] name fallback session=${s.id} '
        'host=${s.hostId} status=${s.nameResolutionStatus ?? 'unknown'} '
        'participantCount=${s.participantCount} '
        'reason=${s.nameResolutionStatus ?? 'missing_profile_or_query'}',
      );
    }
  }

  Future<List<VideoSession>> _attachCounterpartyNames(
    List<VideoSession> sessions,
  ) async {
    if (sessions.isEmpty) return sessions;
    final me = _supabase.auth.currentUser?.id;
    if (me == null) return sessions;

    // Membership is only via video_session_participants (no video_sessions.client_id).
    final participantIdsBySession = <String, List<String>>{};
    try {
      final partRes = await _supabase
          .from('video_session_participants')
          .select('session_id, user_id, role')
          .inFilter('session_id', sessions.map((s) => s.id).toList());
      for (final row in (partRes as List)) {
        final map = row as Map<String, dynamic>;
        if (map['role'] != 'participant') continue;
        final sessionId = map['session_id'] as String;
        final uid = map['user_id'] as String;
        participantIdsBySession.putIfAbsent(sessionId, () => <String>[]).add(uid);
      }
    } catch (e) {
      _logPostgrestError('listSessions.participants', e);
      rethrow;
    }

    final ids = <String>{};
    for (final s in sessions) {
      if (s.hostId != me) {
        ids.add(s.hostId);
      }
      for (final uid in participantIdsBySession[s.id] ?? const <String>[]) {
        ids.add(uid);
      }
    }
    if (ids.isEmpty) return sessions;

    try {
      // Prefer SECURITY DEFINER public profile RPC — direct profiles SELECT is
      // blocked by RLS ("own profile only"), which caused "your session partner".
      final profiles = await _supabase.rpc(
        'get_public_profiles',
        params: {'p_user_ids': ids.toList()},
      );
      final nameById = <String, String>{};
      for (final row in (profiles as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final name = VideoSessionNotificationLogic.displayName(
          fullName: map['full_name'] as String?,
          username: map['username'] as String?,
        );
        if (name.isNotEmpty) {
          nameById[map['id'] as String] = name;
        } else if (kDebugMode) {
          debugPrint(
            '[VideoSessionsRepository] missing profile display name '
            'user=${map['id']}',
          );
        }
      }

      if (kDebugMode) {
        final missing = ids.where((id) => !nameById.containsKey(id)).toList();
        if (missing.isNotEmpty) {
          debugPrint(
            '[VideoSessionsRepository] profiles missing or empty for ids=$missing '
            '(RLS denial unlikely via get_public_profiles; check empty full_name)',
          );
        }
      }

      return sessions.map((s) {
        final isHost = s.hostId == me;
        final memberIds = participantIdsBySession[s.id] ?? const <String>[];
        final displayIds = isHost
            ? memberIds
            : <String>{
                s.hostId,
                ...memberIds.where((id) => id != me),
              }.toList();
        final names = displayIds
            .map((id) => nameById[id])
            .whereType<String>()
            .toList();
        final otherId = displayIds.isEmpty ? null : displayIds.first;
        String? status;
        if (displayIds.isEmpty && isHost) {
          status = 'missing_participant';
        } else if (otherId != null && !nameById.containsKey(otherId)) {
          status = 'missing_profile';
        } else if (names.isEmpty) {
          status = 'missing_profile';
        } else {
          status = 'ok';
        }
        return s.copyWith(
          counterpartyName: otherId == null ? null : nameById[otherId],
          participantNames: names,
          participantCount: displayIds.length,
          nameResolutionStatus: status,
        );
      }).toList();
    } catch (e) {
      _logPostgrestError('listSessions.profiles', e);
      if (kDebugMode) {
        debugPrint(
          '[VideoSessionsRepository] relationship/profile query failure: $e',
        );
      }
      return sessions;
    }
  }

  /// Create a Google Meet session (Edge Function creates the Meet space).
  Future<VideoSession> createSession({
    required String title,
    required DateTime scheduledStart,
    int durationMinutes = 30,
    int maxParticipants = 5,
    String? description,
    List<String> participantIds = const [],
    String? clientRequestId,
  }) async {
    final requestId = clientRequestId ??
        '${DateTime.now().millisecondsSinceEpoch}-${_supabase.auth.currentUser?.id ?? 'anon'}';

    final res = await _supabase.functions.invoke(
      'create-video-session',
      body: {
        'title': title.trim(),
        'scheduled_start': scheduledStart.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        'max_participants': maxParticipants,
        'participant_ids': participantIds,
        'provider': 'google_meet',
        'client_request_id': requestId,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );

    if (res.status != 200) {
      final map = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null;
      final err = map?['error']?.toString() ?? 'Failed to create session';
      final code = map?['code']?.toString();
      throw VideoSessionCreateException(err, code: code);
    }

    final data = Map<String, dynamic>.from(res.data as Map);
    return VideoSession.fromJson({
      ...data,
      'host_id': data['host_id'] ?? _supabase.auth.currentUser!.id,
      'provider': data['provider'] ?? 'google_meet',
      'duration_minutes': data['duration_minutes'] ?? durationMinutes,
      'max_participants': maxParticipants,
      'status': data['status'] ?? 'scheduled',
      'join_url': data['join_url'] ?? '',
    });
  }

  /// Cancels a session the caller hosts.
  ///
  /// The `host_id` filter is defence-in-depth only; RLS is the real gate. An
  /// RLS denial or a non-existent id updates zero rows and returns no error,
  /// so the affected rows are checked explicitly rather than reporting success
  /// for a write that never happened.
  Future<void> cancelSession(String sessionId) async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) {
      throw VideoSessionCreateException(
        'cancel_not_authenticated',
        code: 'UNAUTHORIZED',
      );
    }

    final rows = await _supabase
        .from('video_sessions')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', sessionId)
        .eq('host_id', me)
        .select('id');

    if (rows is! List || rows.isEmpty) {
      throw VideoSessionCreateException(
        'cancel_not_applied',
        code: 'CANCEL_NOT_APPLIED',
      );
    }
  }

  /// Host update of scheduling fields. Preserves join_url / Meet space.
  Future<VideoSession> updateSession({
    required String sessionId,
    required String title,
    required DateTime scheduledStart,
    required int durationMinutes,
    String? description,
    String? joinUrl,
    bool preserveJoinUrl = true,
  }) async {
    final updates = <String, dynamic>{
      'title': title.trim(),
      'scheduled_start': scheduledStart.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
      'description':
          (description == null || description.trim().isEmpty)
              ? null
              : description.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (!preserveJoinUrl && joinUrl != null) {
      final linkError = MeetingLinkRules.validateHttpsMeetingLink(joinUrl);
      if (linkError != null) throw Exception(linkError);
      updates['join_url'] = joinUrl.trim();
    }

    final res = await _supabase
        .from('video_sessions')
        .update(updates)
        .eq('id', sessionId)
        .eq('host_id', _supabase.auth.currentUser!.id)
        .eq('status', 'scheduled')
        .select(_videoSessionSelectColumns)
        .maybeSingle();

    if (res == null) {
      throw Exception('Could not update session');
    }
    return VideoSession.fromJson(res);
  }

  Future<VideoSession?> getSession(String sessionId) async {
    if (!isVideoSessionUuid(sessionId)) {
      if (kDebugMode) {
        debugPrint(
          '[VideoSessionsRepository] getSession rejected non-uuid id=$sessionId',
        );
      }
      return null;
    }
    try {
      final res = await _supabase.rpc(
        'get_my_video_session',
        params: {'p_session_id': sessionId},
      );
      final list = (res as List);
      if (list.isEmpty) {
        // Fallback for environments without the RPC yet.
        final row = await _supabase
            .from('video_sessions')
            .select(_videoSessionSelectColumns)
            .eq('id', sessionId)
            .maybeSingle();
        if (row == null) return null;
        final named =
            await _attachCounterpartyNames([VideoSession.fromJson(row)]);
        _logNameResolution(named);
        final withPeople = await _attachPeople(named);
        return withPeople.first;
      }
      final session =
          VideoSession.fromJson(Map<String, dynamic>.from(list.first as Map));
      _logNameResolution([session]);
      final withPeople = await _attachPeople([session]);
      return withPeople.first;
    } catch (e) {
      _logPostgrestError('getSession', e);
      rethrow;
    }
  }

  /// Persist attendance rejection. Actor is the signed-in JWT user.
  Future<String> rejectSession({
    required String sessionId,
    required String reasonCode,
    String? reasonText,
  }) async {
    final res = await _supabase.functions.invoke(
      'respond-video-session',
      body: {
        'session_id': sessionId,
        'response_status': 'rejected',
        'reason_code': reasonCode,
        if (reasonText != null && reasonText.trim().isNotEmpty)
          'reason_text': reasonText.trim(),
      },
    );
    if (res.status != 200) {
      final map = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null;
      final code = map?['code']?.toString();
      final err = map?['error']?.toString() ?? 'Could not save response';
      if (code == 'FORBIDDEN') {
        throw VideoSessionCreateException(err, code: code);
      }
      throw VideoSessionCreateException(err, code: code);
    }
    final map = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null;
    return map?['snackbar_role']?.toString() ?? 'trainer';
  }
}
