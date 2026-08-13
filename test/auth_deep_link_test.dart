import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/core/auth/auth_deep_link.dart';

void main() {
  group('AuthDeepLink', () {
    test('callback URI matches existing OAuth scheme', () {
      expect(AuthDeepLink.callback, 'cotrainr://auth-callback');
      final uri = Uri.parse(AuthDeepLink.callback);
      expect(AuthDeepLink.isCallbackUri(uri), isTrue);
    });

    test('signup / OAuth callback with tokens is recognized', () {
      final uri = Uri.parse(
        'cotrainr://auth-callback#access_token=abc&type=signup',
      );
      expect(AuthDeepLink.isCallbackUri(uri), isTrue);
    });

    test('PKCE code callback is recognized', () {
      final uri = Uri.parse('cotrainr://auth-callback?code=pkce-code');
      expect(AuthDeepLink.isCallbackUri(uri), isTrue);
    });

    test('invite and reset-password are not auth callbacks', () {
      expect(
        AuthDeepLink.isCallbackUri(Uri.parse('cotrainr://invite?code=ABC')),
        isFalse,
      );
      expect(
        AuthDeepLink.isCallbackUri(Uri.parse('cotrainr://reset-password')),
        isFalse,
      );
    });

    test('reset-password URI is recognized separately from OAuth callback', () {
      expect(AuthDeepLink.resetPassword, 'cotrainr://reset-password');
      expect(
        AuthDeepLink.isResetPasswordUri(Uri.parse(AuthDeepLink.resetPassword)),
        isTrue,
      );
      expect(
        AuthDeepLink.isResetPasswordUri(Uri.parse(AuthDeepLink.callback)),
        isFalse,
      );
    });
  });
}
