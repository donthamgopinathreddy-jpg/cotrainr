import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cotrainr/core/auth/auth_error_mapper.dart';
import 'package:cotrainr/core/auth/login_identifier.dart';

void main() {
  group('LoginIdentifier', () {
    test('empty identifier', () {
      expect(
        LoginIdentifier.validateIdentifier(''),
        'Enter your email or User ID.',
      );
      expect(
        LoginIdentifier.validateIdentifier('   '),
        'Enter your email or User ID.',
      );
    });

    test('empty password', () {
      expect(
        LoginIdentifier.validatePassword(''),
        'Enter your password.',
      );
      expect(LoginIdentifier.validatePassword('secret'), isNull);
    });

    test('malformed email rejected', () {
      expect(
        LoginIdentifier.validateIdentifier('abc@'),
        'Enter a valid email address.',
      );
      expect(
        LoginIdentifier.validateIdentifier('abc@gmail'),
        'Enter a valid email address.',
      );
    });

    test('valid email accepted', () {
      expect(
        LoginIdentifier.validateIdentifier('user@example.com'),
        isNull,
      );
      expect(
        LoginIdentifier.validateIdentifier(' TEST@GMAIL.COM '),
        isNull,
      );
    });

    test('username forms accepted', () {
      expect(LoginIdentifier.validateIdentifier('don_5412'), isNull);
      expect(LoginIdentifier.validateIdentifier('@don_5412'), isNull);
      expect(LoginIdentifier.validateIdentifier(' DON_5412 '), isNull);
    });

    test('username normalization', () {
      expect(LoginIdentifier.normalizeUsername('@Don_5412'), 'don_5412');
      expect(LoginIdentifier.normalizeUsername(' DON_5412 '), 'don_5412');
      expect(LoginIdentifier.normalizeUsername('don_5412'), 'don_5412');
    });
  });

  group('AuthErrorMapper', () {
    test('invalid credentials', () {
      final msg = AuthErrorMapper.map(
        const AuthException('Invalid login credentials'),
      );
      expect(msg.kind, AuthUserErrorKind.invalidCredentials);
      expect(msg.title, contains('Incorrect email or password'));
      expect(msg.display.toLowerCase(), isNot(contains('authapiexception')));
      expect(msg.display.toLowerCase(), isNot(contains('statuscode')));
      expect(msg.display.toLowerCase(), isNot(contains('invalid_credentials')));
    });

    test('network', () {
      final msg = AuthErrorMapper.map(const SocketException('fail'));
      expect(msg.kind, AuthUserErrorKind.network);
      expect(msg.title.toLowerCase(), contains('internet'));
      expect(msg.display.toLowerCase(), isNot(contains('socketexception')));
    });

    test('timeout', () {
      final msg = AuthErrorMapper.map(TimeoutException('slow'));
      expect(msg.kind, AuthUserErrorKind.timeout);
      expect(msg.title, contains('Unable to connect'));
    });

    test('rate limit', () {
      final msg = AuthErrorMapper.map(
        const AuthException('Rate limit exceeded', statusCode: '429'),
      );
      expect(msg.kind, AuthUserErrorKind.rateLimited);
    });

    test('service unavailable', () {
      final msg = AuthErrorMapper.map(Exception('503 service unavailable'));
      expect(msg.kind, AuthUserErrorKind.serviceUnavailable);
    });

    test('unknown', () {
      final msg = AuthErrorMapper.map(Exception('weird'));
      expect(msg.kind, AuthUserErrorKind.unknown);
      expect(msg.display.toLowerCase(), isNot(contains('exception:')));
    });

    test('cancel suppressed', () {
      final msg = AuthErrorMapper.map(Exception('user_cancelled'));
      expect(msg.kind, AuthUserErrorKind.cancelled);
      expect(AuthErrorMapper.shouldSuppressUi(msg), isTrue);
    });

    test('raw AuthApiException string never shown as title source', () {
      final raw =
          'AuthApiException(message: Invalid login credentials, statusCode: 400, code: invalid_credentials)';
      final msg = AuthErrorMapper.map(Exception(raw));
      expect(msg.display.contains('AuthApiException'), isFalse);
      expect(msg.display.contains('statusCode'), isFalse);
      expect(msg.display.contains('invalid_credentials'), isFalse);
    });
  });
}
