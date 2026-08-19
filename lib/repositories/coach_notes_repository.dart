import 'package:flutter/foundation.dart';
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
    this.coachType = '',
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
      coachType: coachType ?? json['coach_type'] as String? ?? '',
    );
  }
}

class CoachNotesLoadException implements Exception {
  final String reason;
  const CoachNotesLoadException(this.reason);

  @override
  String toString() => 'CoachNotesLoadException($reason)';
}

abstract class CoachNotesInboxApi {
  Future<List<CoachNote>> getMyNotes();
}

abstract class CoachNotesApi {
  Future<List<CoachNote>> getNotesForClient(String clientId);
  Future<CoachNote?> addNote(String clientId, String content);
  Future<void> deleteNote(String noteId);
}

/// Repository for coach notes (trainer/nutritionist → client).
class CoachNotesRepository implements CoachNotesApi, CoachNotesInboxApi {
  final SupabaseClient _supabase;

  CoachNotesRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Fetch notes addressed to the signed-in client.
  ///
  /// Query: `coach_notes` where `client_id = auth.uid()`, ordered by `created_at` desc.
  /// Provider names/avatars come from `get_public_profiles` (direct `profiles`
  /// SELECT is revoked for clients). Provider type comes from `providers`.
  @override
  Future<List<CoachNote>> getMyNotes() async {
    final uid = _currentUserId;
    if (uid == null) {
      debugPrint('CoachNotes: note query failed: not_signed_in');
      throw const CoachNotesLoadException('not_signed_in');
    }

    final List<dynamic> rows;
    try {
      final res = await _supabase
          .from('coach_notes')
          .select('id, coach_id, client_id, content, created_at')
          .eq('client_id', uid)
          .order('created_at', ascending: false);
      rows = res as List<dynamic>;
    } catch (e) {
      debugPrint('CoachNotes: note query failed: $e');
      throw const CoachNotesLoadException('query_failed');
    }

    if (rows.isEmpty) {
      debugPrint('CoachNotes: zero rows for client $uid');
      return [];
    }

    final parsed = <_ParsedNote>[];
    for (final raw in rows) {
      final map = raw is Map<String, dynamic>
          ? raw
          : Map<String, dynamic>.from(raw as Map);
      final note = _tryParseNoteRow(map);
      if (note == null) {
        debugPrint('CoachNotes: malformed note data: $map');
        continue;
      }
      parsed.add(note);
    }

    if (parsed.isEmpty) {
      debugPrint('CoachNotes: zero rows after parse for client $uid');
      return [];
    }

    final coachIds = parsed.map((n) => n.coachId).toSet().toList();
    final profiles = await _loadPublicProfiles(coachIds);
    final providerTypes = await _loadProviderTypes(coachIds);

    return parsed.map((note) {
      final profile = profiles[note.coachId];
      if (profile == null) {
        debugPrint('CoachNotes: provider profile missing for ${note.coachId}');
      }
      var type = providerTypes[note.coachId] ?? '';
      if (type.isEmpty) {
        final role = (profile?['role'] as String?)?.trim().toLowerCase() ?? '';
        if (role == 'trainer' || role == 'nutritionist') {
          type = role;
        } else if (role.isNotEmpty) {
          debugPrint(
            'CoachNotes: provider_type missing for ${note.coachId} (role=$role)',
          );
        } else {
          debugPrint('CoachNotes: provider_type missing for ${note.coachId}');
        }
      }
      final fullName = (profile?['full_name'] as String?)?.trim() ?? '';
      final username = (profile?['username'] as String?)?.trim() ?? '';
      return CoachNote(
        id: note.id,
        coachId: note.coachId,
        clientId: note.clientId,
        content: note.content,
        createdAt: note.createdAt,
        coachName: fullName.isNotEmpty ? fullName : username,
        coachAvatarUrl: (profile?['avatar_url'] as String?)?.trim(),
        coachType: type,
      );
    }).toList();
  }

  Future<Map<String, Map<String, dynamic>>> _loadPublicProfiles(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return {};
    try {
      final res = await _supabase.rpc(
        'get_public_profiles',
        params: {'p_user_ids': userIds},
      );
      final map = <String, Map<String, dynamic>>{};
      for (final p in res as List) {
        final m = Map<String, dynamic>.from(p as Map);
        final id = m['id'] as String?;
        if (id != null) map[id] = m;
      }
      return map;
    } catch (e) {
      debugPrint('CoachNotes: provider profile lookup failed: $e');
      return {};
    }
  }

  Future<Map<String, String>> _loadProviderTypes(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    try {
      final res = await _supabase
          .from('providers')
          .select('user_id, provider_type')
          .inFilter('user_id', userIds);
      final map = <String, String>{};
      for (final p in res as List) {
        final m = Map<String, dynamic>.from(p as Map);
        final id = m['user_id'] as String?;
        final type = (m['provider_type'] as String?)?.trim().toLowerCase() ?? '';
        if (id != null && type.isNotEmpty) map[id] = type;
      }
      return map;
    } catch (e) {
      debugPrint('CoachNotes: provider_type lookup failed: $e');
      return {};
    }
  }

  _ParsedNote? _tryParseNoteRow(Map<String, dynamic> map) {
    final id = map['id'] as String?;
    final coachId = map['coach_id'] as String?;
    final clientId = map['client_id'] as String?;
    final content = map['content'] as String?;
    final createdRaw = map['created_at'];
    DateTime? createdAt;
    if (createdRaw is DateTime) {
      createdAt = createdRaw;
    } else if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw);
    }
    if (id == null ||
        id.isEmpty ||
        coachId == null ||
        coachId.isEmpty ||
        clientId == null ||
        clientId.isEmpty ||
        content == null ||
        createdAt == null) {
      return null;
    }
    return _ParsedNote(
      id: id,
      coachId: coachId,
      clientId: clientId,
      content: content,
      createdAt: createdAt,
    );
  }

  /// Insert a note as coach (trainer/nutritionist) for a client.
  @override
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
      throw Exception('Failed to add coach note: $e');
    }
  }

  /// Count unread notes for badge (optional: could use last_seen_at later).
  Future<int> getUnreadCount() async {
    final notes = await getMyNotes();
    return notes.length; // For now, no read/unread; badge could show count if desired
  }

  /// All notes written by the current coach, with client profile info.
  Future<List<CoachNote>> getAllNotesByCoach() async {
    if (_currentUserId == null) return [];

    try {
      final res = await _supabase
          .from('coach_notes')
          .select('id, coach_id, client_id, content, created_at')
          .eq('coach_id', _currentUserId!)
          .order('created_at', ascending: false);

      final rows = res as List<dynamic>;
      if (rows.isEmpty) return [];

      final clientIds =
          rows.map((r) => (r as Map)['client_id'] as String).toSet().toList();
      final profiles = await _loadPublicProfiles(clientIds);

      return rows.map((r) {
        final map = r as Map<String, dynamic>;
        final clientId = map['client_id'] as String;
        final profile = profiles[clientId];
        return CoachNote.fromJson(
          map,
          coachName: profile?['full_name'] as String?,
          coachAvatarUrl: profile?['avatar_url'] as String?,
          coachType: 'client',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch notes for a specific client (used by trainer/nutritionist dashboard).
  /// Coach must have accepted lead with this client.
  @override
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
      throw Exception('Failed to load coach notes: $e');
    }
  }

  /// Author-only delete. RLS also requires an accepted relationship.
  @override
  Future<void> deleteNote(String noteId) async {
    if (_currentUserId == null) throw Exception('Not signed in');
    try {
      await _supabase
          .from('coach_notes')
          .delete()
          .eq('id', noteId)
          .eq('coach_id', _currentUserId!);
    } catch (e) {
      throw Exception('Failed to delete coach note: $e');
    }
  }
}

class _ParsedNote {
  final String id;
  final String coachId;
  final String clientId;
  final String content;
  final DateTime createdAt;

  const _ParsedNote({
    required this.id,
    required this.coachId,
    required this.clientId,
    required this.content,
    required this.createdAt,
  });
}
