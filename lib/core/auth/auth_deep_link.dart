/// Shared Cotrainr auth deep-link URIs.
///
/// Must stay in sync with:
/// - Android intent-filters (`scheme=cotrainr`, hosts below)
/// - iOS `CFBundleURLSchemes` (`cotrainr`)
/// - Supabase Auth → URL Configuration → Redirect URLs
abstract final class AuthDeepLink {
  /// OAuth + email confirmation callback. Do not reuse for password recovery.
  static const callback = 'cotrainr://auth-callback';

  /// Password recovery redirect used by [resetPasswordForEmail].
  static const resetPassword = 'cotrainr://reset-password';

  static bool isCallbackUri(Uri uri) =>
      uri.scheme == 'cotrainr' && uri.host == 'auth-callback';

  static bool isResetPasswordUri(Uri uri) =>
      uri.scheme == 'cotrainr' && uri.host == 'reset-password';
}
