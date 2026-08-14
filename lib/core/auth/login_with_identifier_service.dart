import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_error_mapper.dart';
import 'login_identifier.dart';

typedef LoginFunctionInvoke = Future<FunctionResponse> Function(
  String functionName,
  Map<String, dynamic> body,
);

typedef LoginSessionInstaller = Future<bool> Function({
  required String accessToken,
  required String refreshToken,
});

/// Client for secure User ID / email password login via Edge Function.
///
/// The Edge Function resolves usernames with the service role and authenticates
/// via Supabase Auth. The Flutter app never receives username→email mappings.
class LoginWithIdentifierService {
  LoginWithIdentifierService({
    SupabaseClient? client,
    LoginFunctionInvoke? invoke,
    LoginSessionInstaller? installSession,
  })  : _client = client,
        _invoke = invoke,
        _installSession = installSession;

  final SupabaseClient? _client;
  final LoginFunctionInvoke? _invoke;
  final LoginSessionInstaller? _installSession;

  static const functionName = 'login-with-identifier';
  static const timeout = Duration(seconds: 15);

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  /// Authenticates and installs the session on the Supabase client.
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    final id = LoginIdentifier.normalizeForSubmit(identifier);
    final localIdError = LoginIdentifier.validateIdentifier(identifier);
    if (localIdError != null) {
      throw AuthValidationException(localIdError);
    }
    final localPassError = LoginIdentifier.validatePassword(password);
    if (localPassError != null) {
      throw AuthValidationException(localPassError);
    }

    if (kDebugMode) {
      debugPrint('[LOGIN] identifier auth started');
    }

    try {
      final response = await (_invoke ?? _defaultInvoke)(
        functionName,
        {
          'identifier': id,
          'password': password,
        },
      ).timeout(timeout);

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
        if (kDebugMode) {
          debugPrint('[LOGIN] edge response success=false');
        }
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
      if (refreshToken == null ||
          refreshToken.isEmpty ||
          accessToken == null ||
          accessToken.isEmpty) {
        if (kDebugMode) {
          debugPrint('[LOGIN] edge response success=false');
        }
        // Dual tokens are required. Refresh-only setSession historically
        // emitted tokenRefreshed (not SIGNED_IN) and broke startup routing.
        throw const AuthMappedException(AuthErrorMapper.unknown);
      }

      if (kDebugMode) {
        debugPrint('[LOGIN] edge response success=true');
      }

      final installed = await (_installSession ?? _defaultInstallSession)(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      if (!installed) {
        if (kDebugMode) {
          debugPrint('[LOGIN] session established=false');
        }
        throw const AuthMappedException(AuthErrorMapper.unknown);
      }
      if (kDebugMode) {
        debugPrint('[LOGIN] session established=true');
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
      if (kDebugMode) {
        debugPrint('[LOGIN] identifier auth failed type=${e.runtimeType}');
      }
      throw AuthMappedException(AuthErrorMapper.map(e));
    }
  }

  Future<FunctionResponse> _defaultInvoke(
    String name,
    Map<String, dynamic> body,
  ) {
    return _supabase.functions.invoke(name, body: body);
  }

  Future<bool> _defaultInstallSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _supabase.auth.setSession(
      refreshToken,
      accessToken: accessToken,
    );
    return _supabase.auth.currentSession != null &&
        _supabase.auth.currentUser != null;
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
