/// Canonical Cotrainr roles. Database values are exactly:
/// `client` | `trainer` | `nutritionist`.
enum UserRole {
  client,
  trainer,
  nutritionist;

  String get dbValue => name;

  bool get isProvider => this == trainer || this == nutritionist;
}

/// Defensive, fail-closed role parsing.
///
/// Trims and lowercases before validating. An unknown, empty or null value
/// returns `null` — callers must treat that as "role unresolved" and must never
/// substitute `client` or `trainer`.
abstract final class UserRoleParser {
  static UserRole? parse(Object? raw) {
    final value = raw?.toString().trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    switch (value) {
      case 'client':
        return UserRole.client;
      case 'trainer':
        return UserRole.trainer;
      case 'nutritionist':
        return UserRole.nutritionist;
      default:
        return null;
    }
  }

  /// Normalized database string, or null when the value is not canonical.
  static String? normalize(Object? raw) => parse(raw)?.dbValue;

  static bool isProviderRole(Object? raw) => parse(raw)?.isProvider ?? false;
}
