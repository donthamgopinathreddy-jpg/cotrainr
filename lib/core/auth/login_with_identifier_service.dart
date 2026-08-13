import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_error_mapper.dart';
import 'login_identifier.dart';

/// Client for secure User ID / email password login via Edge Function.
///
/// The Edge Function resolves usernames with the service role and authenticates
/// via Supabase Auth. The Flutter app never receives username→email mappings.
class LoginWithIdentifierService {
  LoginWithIdentifierService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const functionName = 'login-with-identifier';
  static const timeout = Duration(seconds: 15);

  /// Authenticates and installs the session on the Supabase client.
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    final id = LoginIdentifier.trim(identifier);
    final localIdError = LoginIdentifier.validateIdentifier(id);
    if (localIdError != null) {
      throw AuthValidationException(localIdError);
    }
    final localPassError = LoginIdentifier.validatePassword(password);
    if (localPassError != null) {
      throw AuthValidationException(localPassError);
    }

    try {
      final response = await _client.functions
          .invoke(
            functionName,
            body: {
              'identifier': id,
              'password': password,
            },
          )
          .timeout(timeout);

      final status = response.status;
      final data = response.data;

      if (status == 401 || status == 403) {
        throw const AuthMappedException(AuthErrorMapper.invalidCredentials);
      }
      if (status == 429) {
        throw const AuthMappedException(AuthErrorMapper.rateLimited);
      }
      if (status == 408) {
        throw const AuthMappedException(AuthErrorMapper.timeout);
      }
      if (status >= 500) {
        throw const AuthMappedException(AuthErrorMapper.serviceUnavailable);
      }
      if (status < 200 || status >= 300) {
        debugPrint('[LoginWithIdentifier] unexpected status=$status');
        throw const AuthMappedException(AuthErrorMapper.unknown);
      }

      if (data is! Map) {
        throw const AuthMappedException(AuthErrorMapper.unknown);
      }
      final map = Map<String, dynamic>.from(data);
      if (map['error'] != null) {
        final code = map['error'].toString().toLowerCase();
        if (code.contains('rate')) {
          throw const AuthMappedException(AuthErrorMapper.rateLimited);
        }
        if (code.contains('unavailable') || code.contains('service')) {
          throw const AuthMappedException(AuthErrorMapper.serviceUnavailable);
        }
        throw const AuthMappedException(AuthErrorMapper.invalidCredentials);
      }

      final refreshToken = map['refresh_token'] as String?;
      final accessToken = map['access_token'] as String?;
      if (refreshToken == null || refreshToken.isEmpty) {
        if (kDebugMode) {
          debugPrint('[LOGIN] edge response missing refresh_token');
        }
        throw const AuthMappedException(AuthErrorMapper.unknown);
      }

      if (kDebugMode) {
        debugPrint(
          '[LOGIN] authentication returned success '
          'hasAccessToken=${accessToken != null && accessToken.isNotEmpty} '
          'hasRefreshToken=true',
        );
        debugPrint('[LOGIN] calling setSession');
      }

      // Prefer dual-token fast path → SIGNED_IN (avoids refresh-only
      // tokenRefreshed, which StartupBootstrap intentionally ignores).
      if (accessToken != null && accessToken.isNotEmpty) {
        await _client.auth.setSession(
          refreshToken,
          accessToken: accessToken,
        );
      } else {
        await _client.auth.setSession(refreshToken);
      }
      if (_client.auth.currentSession == null ||
          _client.auth.currentUser == null) {
        if (kDebugMode) {
          debugPrint(
            '[LOGIN] setSession left currentSession/currentUser null',
          );
        }
        throw const AuthMappedException(AuthErrorMapper.unknown);
      }
      if (kDebugMode) {
        debugPrint(
          '[LOGIN] setSession ok userId=${_client.auth.currentUser!.id}',
        );
      }
    } on AuthMappedException {
      rethrow;
    } on AuthValidationException {
      rethrow;
    } on TimeoutException {
      throw const AuthMappedException(AuthErrorMapper.timeout);
    } on FunctionException catch (e) {
      throw AuthMappedException(AuthErrorMapper.map(e));
    } catch (e) {
      debugPrint('[LoginWithIdentifier] failure type=${e.runtimeType}');
      throw AuthMappedException(AuthErrorMapper.map(e));
    }
  }
}

class AuthValidationException implements Exception {
  AuthValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthMappedException implements Exception {
  const AuthMappedException(this.message);
  final AuthUserMessage message;

  @override
  String toString() => message.title;
}
