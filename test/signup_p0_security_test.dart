import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cotrainr/core/auth/signup_error_mapper.dart';
import 'package:cotrainr/widgets/provider/provider_professional_form_validation.dart';

void main() {
  group('SignupErrorMapper', () {
    bool looksRaw(String text) {
      final lower = text.toLowerCase();
      return lower.contains('authapiexception') ||
          lower.contains('postgrestexception') ||
          lower.contains('functionshttperror') ||
          lower.contains('socketexception') ||
          lower.contains('statuscode') ||
          lower.contains('duplicate key') ||
          lower.contains('violates unique') ||
          lower.contains('stack');
    }

    test('username taken', () {
      final msg = SignupErrorMapper.map(
        Exception('Username already exists'),
      );
      expect(msg.title, contains('already taken'));
      expect(looksRaw(msg.display), isFalse);
    });

    test('email conflict', () {
      final msg = SignupErrorMapper.map(
        const AuthException('User already registered'),
      );
      expect(msg.title.toLowerCase(), contains('already exists'));
      expect(looksRaw(msg.display), isFalse);
    });

    test('password rejected', () {
      final msg = SignupErrorMapper.map(
        const AuthException('Password should contain'),
      );
      expect(msg.title.toLowerCase(), contains('password'));
      expect(looksRaw(msg.display), isFalse);
    });

    test('timeout', () {
      final msg = SignupErrorMapper.map(TimeoutException('signup'));
      expect(looksRaw(msg.display), isFalse);
      expect(msg.display.toLowerCase(), isNot(contains('timeoutexception')));
    });

    test('network', () {
      final msg = SignupErrorMapper.map(const SocketException('fail'));
      expect(looksRaw(msg.display), isFalse);
      expect(msg.display.toLowerCase(), isNot(contains('socketexception')));
    });

    test('unknown never leaks exception string', () {
      final msg = SignupErrorMapper.map(
        Exception('PostgrestException(message: boom, code: 42, details: sql)'),
      );
      expect(looksRaw(msg.display), isFalse);
      expect(msg.display.toLowerCase(), isNot(contains('postgrest')));
      expect(msg.display.toLowerCase(), isNot(contains('boom')));
    });

    test('constants are safe', () {
      for (final msg in [
        SignupErrorMapper.usernameTaken,
        SignupErrorMapper.invalidUsername,
        SignupErrorMapper.usernameCheckFailed,
        SignupErrorMapper.invalidEmail,
        SignupErrorMapper.emailConflict,
        SignupErrorMapper.passwordRejected,
        SignupErrorMapper.passwordMismatch,
        SignupErrorMapper.profileFailed,
        SignupErrorMapper.providerFailed,
        SignupErrorMapper.legalRequired,
      ]) {
        expect(looksRaw(msg.display), isFalse);
      }
    });
  });

  group('Provider verification destinations', () {
    test('client → home', () {
      expect(postPermissionsDestination('client'), '/home');
    });

    test('trainer / nutritionist → verification', () {
      expect(postPermissionsDestination('trainer'), '/verification');
      expect(postPermissionsDestination('nutritionist'), '/verification');
    });
  });
}
