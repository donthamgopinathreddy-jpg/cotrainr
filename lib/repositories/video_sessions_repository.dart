import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed video session (Zoom/Meet/Jitsi).
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
  final DateTime createdAt;

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
    required this.createdAt,
  });

  factory VideoSession.fromJson(Map<String, dynamic> json) {
    return VideoSession(
      id: json['id'] as String,
      hostId: json['host_id'] as String,
      provider: json['provider'] as String? ?? 'zoom',
      title: json['title'] as String? ?? 'Video Session',
      description: json['description'] as String?,
      scheduledStart: DateTime.parse(json['scheduled_start'] as String),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
      maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 5,
      status: json['status'] as String? ?? 'scheduled',
      joinUrl: json['join_url'] as String,
      providerMeetingId: json['provider_meeting_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isScheduled => status == 'scheduled';
  bool get isCancelled => status == 'cancelled';
  bool get isEnded => status == 'ended';
}

/// Zoom integration status for the current user.
enum ZoomConnectionStatus {
  notConnected,
  connected,
  expired,
}

class ZoomIntegrationStatus {
  final ZoomConnectionStatus status;
  final String? email;

  ZoomIntegrationStatus({required this.status, this.email});
}

class VideoSessionsRepository {
  final _supabase = Supabase.instance.client;

  /// Get Zoom integration status (connected / expired / not connected).
  Future<ZoomIntegrationStatus> getZoomStatus() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return ZoomIntegrationStatus(status: ZoomConnectionStatus.notConnected);
    }

    final res = await _supabase
        .from('user_integrations_zoom')
        .select('zoom_account_email, expires_at')
        .eq('user_id', userId)
        .maybeSingle();

    if (res == null || res.isEmpty) {
      return ZoomIntegrationStatus(status: ZoomConnectionStatus.notConnected);
    }

    final email = res['zoom_account_email'] as String?;
    final expiresAt = res['expires_at'] as String?;
    if (expiresAt == null) {
      return ZoomIntegrationStatus(
        status: ZoomConnectionStatus.connected,
        email: email,
      );
    }

    final expired = DateTime.parse(expiresAt).isBefore(DateTime.now());
    return ZoomIntegrationStatus(
      status: expired ? ZoomConnectionStatus.expired : ZoomConnectionStatus.connected,
      email: email,
    );
  }

  /// Get OAuth start URL (client opens in browser).
  Future<String> getZoomOAuthUrl() async {
    final res = await _supabase.functions.invoke('zoom-oauth-start');
    if (res.status != 200) {
      throw Exception(res.data?['error'] ?? 'Failed to get OAuth URL');
    }
    final authUrl = (res.data as Map<String, dynamic>?)?['auth_url'] as String?;
    if (authUrl == null || authUrl.isEmpty) {
      throw Exception('No auth URL returned');
    }
    return authUrl;
  }

  /// Disconnect Zoom.
  Future<void> disconnectZoom() async {
    final res = await _supabase.functions.invoke('zoom-disconnect');
    if (res.status != 200) {
      throw Exception(res.data?['error'] ?? 'Failed to disconnect');
    }
  }

  /// List video sessions for current user (host or participant).
  Future<List<VideoSession>> listSessions() async {
    final res = await _supabase
        .from('video_sessions')
        .select()
        .inFilter('status', ['scheduled', 'ended'])
        .order('scheduled_start', ascending: true);

    return (res as List)
        .map((e) => VideoSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create a video session (calls Edge function).
  /// [participantIds] client UUIDs to invite (from accepted leads).
  /// [provider] 'zoom' or 'external'. If external, [joinUrl] must be provided.
  Future<VideoSession> createSession({
    required String title,
    required DateTime scheduledStart,
    int durationMinutes = 30,
    int maxParticipants = 5,
    String? description,
    List<String> participantIds = const [],
    String provider = 'zoom',
    String? joinUrl,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'scheduled_start': scheduledStart.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
      'max_participants': maxParticipants,
      'participant_ids': participantIds,
      'provider': provider,
      if (description != null && description.isNotEmpty) 'description': description,
    };
    if (provider == 'external' && joinUrl != null && joinUrl.trim().isNotEmpty) {
      body['join_url'] = joinUrl.trim();
    }

    final res = await _supabase.functions.invoke(
      'create-video-session',
      body: body,
    );

    if (res.status != 200) {
      throw Exception(res.data?['error'] ?? 'Failed to create session');
    }

    final data = res.data as Map<String, dynamic>?;
    return VideoSession(
      id: data!['id'] as String,
      hostId: _supabase.auth.currentUser!.id,
      provider: provider,
      title: data['title'] as String? ?? title,
      scheduledStart: DateTime.parse(data['scheduled_start'] as String),
      durationMinutes: durationMinutes,
      maxParticipants: maxParticipants,
      status: 'scheduled',
      joinUrl: data['join_url'] as String,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Cancel a session (host only).
  Future<void> cancelSession(String sessionId) async {
    await _supabase
        .from('video_sessions')
        .update({'status': 'cancelled', 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', sessionId)
        .eq('host_id', _supabase.auth.currentUser!.id);
  }

  /// Get a single session by ID.
  Future<VideoSession?> getSession(String sessionId) async {
    final res = await _supabase
        .from('video_sessions')
        .select()
        .eq('id', sessionId)
        .maybeSingle();

    if (res == null) return null;
    return VideoSession.fromJson(res);
  }
}
