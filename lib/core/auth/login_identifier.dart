/// Local Login identifier validation / classification (no network).
class LoginIdentifier {
  LoginIdentifier._();

  static String trim(String raw) => raw.trim();

  /// True when the identifier is intended as an email.
  /// `@username` is treated as a User ID, not an email.
  static bool looksLikeEmail(String raw) {
    final v = trim(raw);
    if (!v.contains('@')) return false;
    // Single leading @ with no other @ → username shorthand.
    if (v.startsWith('@') && v.indexOf('@', 1) == -1) {
      return false;
    }
    return true;
  }

  /// Normalize username for lookup: trim, strip one leading @, lowercase.
  static String normalizeUsername(String raw) {
    var v = trim(raw);
    if (v.startsWith('@')) {
      v = v.substring(1).trim();
    }
    return v.toLowerCase();
  }

  /// Empty identifier message.
  static String? validateIdentifier(String? raw) {
    if (raw == null || trim(raw).isEmpty) {
      return 'Enter your email or User ID.';
    }
    final v = trim(raw);
    if (looksLikeEmail(v) && !isPlausibleEmail(v)) {
      return 'Enter a valid email address.';
    }
    if (!looksLikeEmail(v)) {
      final user = normalizeUsername(v);
      if (user.isEmpty) {
        return 'Enter your email or User ID.';
      }
    }
    return null;
  }

  static String? validatePassword(String? raw) {
    if (raw == null || raw.isEmpty) {
      return 'Enter your password.';
    }
    return null;
  }

  /// Lightweight email shape check — rejects obvious malformed input.
  /// Does not replace server-side auth validation.
  static bool isPlausibleEmail(String raw) {
    final v = trim(raw);
    // Basic: local@domain.tld with no spaces
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return re.hasMatch(v);
  }
}
