import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/meeting_link_rules.dart';

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
  });

  factory VideoSession.fromJson(
    Map<String, dynamic> json, {
    String? counterpartyName,
  }) {
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
      counterpartyName: counterpartyName,
    );
  }

  VideoSession copyWith({String? counterpartyName, String? status}) {
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
    );
  }

  bool get isScheduled => status == 'scheduled';
  bool get isCancelled => status == 'cancelled';
  bool get isEnded => status == 'ended';

  DateTime get endsAt =>
      scheduledStart.add(Duration(minutes: durationMinutes));

  bool get isPast {
    if (isCancelled || isEnded) return true;
    return endsAt.isBefore(DateTime.now());
  }

  bool get isUpcoming => isScheduled && !isPast;

  bool get canJoin => VideoSessionJoinRules.canJoin(
        VideoSessionJoinRules.evaluate(
          status: status,
          scheduledStart: scheduledStart,
          durationMinutes: durationMinutes,
          joinUrl: joinUrl,
        ),
      );

  String? get meetingProviderLabel {
    if (provider == 'google_meet' || provider == 'meet') return 'Google Meet';
    return MeetingLinkRules.detectProviderLabel(joinUrl);
  }

  bool get isGoogleMeet =>
      provider == 'google_meet' || provider == 'meet';
}

class GoogleMeetIntegrationStatus {
  final bool connected;
  final bool reconnectRequired;
  final String? googleEmail;
  final DateTime? connectedAt;

  const GoogleMeetIntegrationStatus({
    required this.connected,
    this.reconnectRequired = false,
    this.googleEmail,
    this.connectedAt,
  });

  factory GoogleMeetIntegrationStatus.disconnected() =>
      const GoogleMeetIntegrationStatus(connected: false);

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
}

class VideoSessionCreateException implements Exception {
  final String message;
  final String? code;

  VideoSessionCreateException(this.message, {this.code});

  @override
  String toString() => message;
}

class VideoSessionsRepository {
  VideoSessionsRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<GoogleMeetIntegrationStatus> getGoogleMeetStatus() async {
    final res = await _supabase.functions.invoke('google-integration-status');
    if (res.status != 200) {
      return GoogleMeetIntegrationStatus.disconnected();
    }
    final data = res.data;
    if (data is! Map) return GoogleMeetIntegrationStatus.disconnected();
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
      final res = await _supabase
          .from('video_sessions')
          .select(_videoSessionSelectColumns)
          .inFilter('status', ['scheduled', 'ended', 'cancelled'])
          .order('scheduled_start', ascending: false);

      final sessions = (res as List)
          .map((e) => VideoSession.fromJson(e as Map<String, dynamic>))
          .toList();

      return _attachCounterpartyNames(sessions);
    } catch (e) {
      _logPostgrestError('listSessions', e);
      rethrow;
    }
  }

  Future<List<VideoSession>> _attachCounterpartyNames(
    List<VideoSession> sessions,
  ) async {
    if (sessions.isEmpty) return sessions;
    final me = _supabase.auth.currentUser?.id;
    if (me == null) return sessions;

    // Membership is only via video_session_participants (no video_sessions.client_id).
    final participantBySession = <String, String>{};
    try {
      final partRes = await _supabase
          .from('video_session_participants')
          .select('session_id, user_id, role')
          .inFilter('session_id', sessions.map((s) => s.id).toList());
      for (final row in (partRes as List)) {
        final map = row as Map<String, dynamic>;
        if (map['role'] != 'participant') continue;
        final sessionId = map['session_id'] as String;
        // Prefer first non-host participant as the display counterparty.
        participantBySession.putIfAbsent(sessionId, () => map['user_id'] as String);
      }
    } catch (e) {
      _logPostgrestError('listSessions.participants', e);
      rethrow;
    }

    final ids = <String>{};
    for (final s in sessions) {
      if (s.hostId != me) {
        ids.add(s.hostId);
      } else {
        final other = participantBySession[s.id];
        if (other != null) ids.add(other);
      }
    }
    if (ids.isEmpty) return sessions;

    try {
      final profiles = await _supabase
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', ids.toList());
      final nameById = <String, String>{};
      for (final row in (profiles as List)) {
        final map = row as Map<String, dynamic>;
        final name = (map['full_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          nameById[map['id'] as String] = name;
        }
      }

      return sessions.map((s) {
        final otherId =
            s.hostId != me ? s.hostId : participantBySession[s.id];
        return VideoSession(
          id: s.id,
          hostId: s.hostId,
          provider: s.provider,
          title: s.title,
          description: s.description,
          scheduledStart: s.scheduledStart,
          durationMinutes: s.durationMinutes,
          maxParticipants: s.maxParticipants,
          status: s.status,
          joinUrl: s.joinUrl,
          providerMeetingId: s.providerMeetingId,
          clientId: s.hostId == me ? participantBySession[s.id] : null,
          createdAt: s.createdAt,
          counterpartyName: otherId == null ? null : nameById[otherId],
        );
      }).toList();
    } catch (e) {
      _logPostgrestError('listSessions.profiles', e);
      // Names are optional — still return sessions if profiles fail.
      return sessions.map((s) {
        return VideoSession(
          id: s.id,
          hostId: s.hostId,
          provider: s.provider,
          title: s.title,
          description: s.description,
          scheduledStart: s.scheduledStart,
          durationMinutes: s.durationMinutes,
          maxParticipants: s.maxParticipants,
          status: s.status,
          joinUrl: s.joinUrl,
          providerMeetingId: s.providerMeetingId,
          clientId: s.hostId == me ? participantBySession[s.id] : null,
          createdAt: s.createdAt,
          counterpartyName: s.counterpartyName,
        );
      }).toList();
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

  Future<void> cancelSession(String sessionId) async {
    await _supabase
        .from('video_sessions')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', sessionId)
        .eq('host_id', _supabase.auth.currentUser!.id);
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
      final res = await _supabase
          .from('video_sessions')
          .select(_videoSessionSelectColumns)
          .eq('id', sessionId)
          .maybeSingle();

      if (res == null) return null;
      final list = await _attachCounterpartyNames([VideoSession.fromJson(res)]);
      return list.first;
    } catch (e) {
      _logPostgrestError('getSession', e);
      rethrow;
    }
  }
}
