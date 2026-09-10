import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Android MVP auth provider contract', () {
    late String login;
    late String deepLinks;
    late String manifest;

    setUpAll(() {
      login = _read('lib/pages/auth/login_page.dart');
      deepLinks = _read('lib/core/auth/auth_deep_link.dart');
      manifest = _read('android/app/src/main/AndroidManifest.xml');
    });

    test('login exposes Google and Microsoft but not Apple', () {
      expect(login.contains('OAuthProvider.google'), isTrue);
      expect(login.contains('OAuthProvider.azure'), isTrue);
      expect(login.contains('Continue with Google'), isTrue);
      expect(login.contains('Continue with Microsoft'), isTrue);
      expect(login.contains('OAuthProvider.apple'), isFalse);
      expect(login.contains('Continue with Apple'), isFalse);
    });

    test('Microsoft requests the email scope required by Supabase Azure auth', () {
      expect(
        login.contains("provider == OAuthProvider.azure ? 'email' : null"),
        isTrue,
      );
    });

    test('OAuth uses the shared Cotrainr callback constant', () {
      expect(login.contains('redirectTo: AuthDeepLink.callback'), isTrue);
      expect(deepLinks.contains("callback = 'cotrainr://auth-callback'"), isTrue);
      expect(
        manifest.contains('android:host="auth-callback"'),
        isTrue,
      );
    });

    test('phone OTP is not part of the MVP login path', () {
      expect(login.contains('signInWithOtp'), isFalse);
      expect(login.contains('verifyOTP'), isFalse);
      expect(login.contains('phone:'), isFalse);
    });
  });
}
