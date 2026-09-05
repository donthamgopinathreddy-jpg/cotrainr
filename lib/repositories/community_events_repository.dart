import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/community_event.dart';

/// Repository for Community Events Home tile + registration.
///
/// Fails soft when RPCs are not deployed yet (returns null / error codes).
class CommunityEventsRepository {
  CommunityEventsRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const eventImagesBucket = 'event-images';

  /// Public cover URL from stored [image_path], or null.
  static String? publicImageUrl(String? imagePath, {SupabaseClient? client}) {
    final path = imagePath?.trim();
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final c = client ?? Supabase.instance.client;
    try {
      return c.storage.from(eventImagesBucket).getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  /// Nearest published eligible event for Home, or null.
  Future<CommunityEventCardData?> fetchHomeEvent() async {
    try {
      final raw = await _supabase.rpc('get_home_community_event');
      if (raw == null) return null;
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      if (map['event'] == null) return null;
      return CommunityEventCardData.fromJson(map);
    } catch (e, s) {
      if (kDebugMode) {
        debugPrint('[COMMUNITY_EVENT] fetchHomeEvent failed: $e\n$s');
      }
      return null;
    }
  }

  /// Register current user. Does not mutate profile.
  Future<EventRegistrationResult> register({
    required String eventId,
    required String name,
    required String phone,
    required String email,
  }) async {
    try {
      final raw = await _supabase.rpc(
        'register_for_community_event',
        params: {
          'p_event_id': eventId,
          'p_name': name.trim(),
          'p_phone': phone.trim(),
          'p_email': email.trim(),
        },
      );
      if (raw is! Map) {
        return const EventRegistrationResult(ok: false, errorCode: 'unknown');
      }
      return EventRegistrationResult.fromJson(Map<String, dynamic>.from(raw));
    } catch (e, s) {
      if (kDebugMode) {
        debugPrint('[COMMUNITY_EVENT] register failed: $e\n$s');
      }
      return const EventRegistrationResult(ok: false, errorCode: 'network');
    }
  }

  /// Prefill helpers from profiles (read-only; edits do not write back).
  Future<({String? name, String? email, String? phone})> fetchProfilePrefill() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      return (name: null, email: _supabase.auth.currentUser?.email, phone: null);
    }
    try {
      final row = await _supabase
          .from('profiles')
          .select('full_name, email, phone')
          .eq('id', uid)
          .maybeSingle();
      return (
        name: (row?['full_name'] as String?)?.trim(),
        email: (row?['email'] as String?)?.trim() ??
            _supabase.auth.currentUser?.email,
        phone: (row?['phone'] as String?)?.trim(),
      );
    } catch (_) {
      return (
        name: null,
        email: _supabase.auth.currentUser?.email,
        phone: null,
      );
    }
  }
}
