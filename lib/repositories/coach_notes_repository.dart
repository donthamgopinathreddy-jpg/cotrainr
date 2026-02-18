import 'package:supabase_flutter/supabase_flutter.dart';

/// Note from a trainer or nutritionist to a client.
class CoachNote {
  final String id;
  final String coachId;
  final String clientId;
  final String content;
  final DateTime createdAt;
  final String? coachName;
  final String? coachAvatarUrl;
  final String coachType; // 'trainer' | 'nutritionist'

  const CoachNote({
    required this.id,
    required this.coachId,
    required this.clientId,
    required this.content,
    required this.createdAt,
    this.coachName,
    this.coachAvatarUrl,
    this.coachType = 'trainer',
  });

  factory CoachNote.fromJson(Map<String, dynamic> json, {String? coachName, String? coachAvatarUrl, String? coachType}) {
    return CoachNote(
      id: json['id'] as String,
      coachId: json['coach_id'] as String,
      clientId: json['client_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      coachName: coachName ?? json['coach_name'] as String?,
      coachAvatarUrl: coachAvatarUrl ?? json['coach_avatar_url'] as String?,
      coachType: coachType ?? json['coach_type'] as String? ?? 'trainer',
    );
  }
}

/// Repository for coach notes (trainer/nutritionist → client).
class CoachNotesRepository {
  final SupabaseClient _supabase;

  CoachNotesRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Fetch notes for the current user (client). Includes coach profile info.
  Future<List<CoachNote>> getMyNotes() async {
    if (_currentUserId == null) return [];

    try {
      final res = await _supabase
          .from('coach_notes')
          .select('id, coach_id, client_id, content, created_at')
          .eq('client_id', _currentUserId!)
          .order('created_at', ascending: false);

      final rows = res as List<dynamic>;
      if (rows.isEmpty) return [];

      final coachIds = rows.map((r) => (r as Map)['coach_id'] as String).toSet().toList();
      final profiles = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .inFilter('id', coachIds);

      final profileMap = <String, Map<String, dynamic>>{};
      for (final p in profiles as List) {
        final m = p as Map<String, dynamic>;
        profileMap[m['id'] as String] = m;
      }

      final providerMap = <String, String>{};
      if (coachIds.isNotEmpty) {
        final providers = await _supabase
            .from('providers')
            .select('user_id, provider_type')
            .inFilter('user_id', coachIds);
        for (final p in providers as List) {
          final m = p as Map<String, dynamic>;
          providerMap[m['user_id'] as String] = m['provider_type'] as String? ?? 'trainer';
        }
      }

      return rows.map((r) {
        final map = r as Map<String, dynamic>;
        final coachId = map['coach_id'] as String;
        final profile = profileMap[coachId];
        return CoachNote.fromJson(
          map,
          coachName: profile?['full_name'] as String?,
          coachAvatarUrl: profile?['avatar_url'] as String?,
          coachType: providerMap[coachId] ?? 'trainer',
        );
      }).toList();
    } catch (e) {
      // Table may not exist yet
      return [];
    }
  }

  /// Insert a note as coach (trainer/nutritionist) for a client.
  Future<CoachNote?> addNote(String clientId, String content) async {
    if (_currentUserId == null) return null;
    if (content.trim().isEmpty) return null;

    try {
      final res = await _supabase
          .from('coach_notes')
          .insert({
            'coach_id': _currentUserId!,
            'client_id': clientId,
            'content': content.trim(),
          })
          .select('id, coach_id, client_id, content, created_at')
          .single();

      return CoachNote.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      return null;
    }
  }

  /// Count unread notes for badge (optional: could use last_seen_at later).
  Future<int> getUnreadCount() async {
    final notes = await getMyNotes();
    return notes.length; // For now, no read/unread; badge could show count if desired
  }

  /// Fetch notes for a specific client (used by trainer/nutritionist dashboard).
  /// Coach must have accepted lead with this client.
  Future<List<CoachNote>> getNotesForClient(String clientId) async {
    if (_currentUserId == null) return [];

    try {
      final res = await _supabase
          .from('coach_notes')
          .select('id, coach_id, client_id, content, created_at')
          .eq('client_id', clientId)
          .eq('coach_id', _currentUserId!)
          .order('created_at', ascending: false);

      final rows = res as List<dynamic>;
      return rows.map((r) => CoachNote.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }
}
