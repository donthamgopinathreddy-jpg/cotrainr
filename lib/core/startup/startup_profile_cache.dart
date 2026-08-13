import 'package:shared_preferences/shared_preferences.dart';

/// Local UI continuity cache for role/profile after a successful online load.
/// Never used for security decisions — Supabase/RLS remains authoritative.
class StartupProfileCache {
  StartupProfileCache._();

  static const _userIdKey = 'startup_cache_user_id';
  static const _roleKey = 'startup_cache_role';
  static const _fullNameKey = 'startup_cache_full_name';
  static const _avatarKey = 'startup_cache_avatar_url';

  static Future<void> save({
    required String userId,
    required String role,
    String? fullName,
    String? avatarUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_roleKey, role.toLowerCase());
    if (fullName != null) {
      await prefs.setString(_fullNameKey, fullName);
    }
    if (avatarUrl != null) {
      await prefs.setString(_avatarKey, avatarUrl);
    } else {
      await prefs.remove(_avatarKey);
    }
  }

  static Future<CachedStartupProfile?> read(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedId = prefs.getString(_userIdKey);
    if (cachedId == null || cachedId != userId) return null;
    final role = prefs.getString(_roleKey);
    if (role == null || role.isEmpty) return null;
    return CachedStartupProfile(
      userId: cachedId,
      role: role.toLowerCase(),
      fullName: prefs.getString(_fullNameKey),
      avatarUrl: prefs.getString(_avatarKey),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_fullNameKey);
    await prefs.remove(_avatarKey);
  }
}

class CachedStartupProfile {
  const CachedStartupProfile({
    required this.userId,
    required this.role,
    this.fullName,
    this.avatarUrl,
  });

  final String userId;
  final String role;
  final String? fullName;
  final String? avatarUrl;

  bool get isClient => role == 'client';
  bool get isTrainer => role == 'trainer';
  bool get isNutritionist => role == 'nutritionist';
  bool get isProvider => isTrainer || isNutritionist;
}
