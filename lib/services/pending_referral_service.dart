import 'package:shared_preferences/shared_preferences.dart';

const _keyPendingReferralCode = 'pending_referral_code';

/// Stores referral code from deep link until signup completes.
/// Persists across app restarts.
class PendingReferralService {
  PendingReferralService._();
  static SharedPreferences? _prefs;

  static Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Store a referral code (e.g. from deep link).
  static Future<void> setPendingCode(String code) async {
    await _ensurePrefs();
    await _prefs!.setString(_keyPendingReferralCode, code.trim().toUpperCase());
  }

  /// Get and clear the pending referral code.
  /// Call after signup to consume the code.
  static Future<String?> consumePendingCode() async {
    await _ensurePrefs();
    final code = _prefs!.getString(_keyPendingReferralCode);
    if (code != null) {
      await _prefs!.remove(_keyPendingReferralCode);
      return code;
    }
    return null;
  }

  /// Peek at the pending code without consuming it.
  static Future<String?> getPendingCode() async {
    await _ensurePrefs();
    return _prefs!.getString(_keyPendingReferralCode);
  }

  /// Clear any pending code (e.g. if user dismisses).
  static Future<void> clearPendingCode() async {
    await _ensurePrefs();
    await _prefs!.remove(_keyPendingReferralCode);
  }
}
