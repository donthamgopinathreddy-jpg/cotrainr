import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// User-safe auth failure categories for Login / OAuth / related auth UI.
enum AuthUserErrorKind {
  invalidCredentials,
  network,
  timeout,
  rateLimited,
  serviceUnavailable,
  cancelled,
  unknown,
}

class AuthUserMessage {
  const AuthUserMessage({
    required this.kind,
    required this.title,
    this.detail,
  });

  final AuthUserErrorKind kind;
  final String title;
  final String? detail;

  /// Single-line copy for compact form errors.
  String get display =>
      detail == null || detail!.isEmpty ? title : '$title\n$detail';
}

/// Maps technical auth failures to safe, non-enumerating user copy.
class AuthErrorMapper {
  AuthErrorMapper._();

  static const invalidCredentials = AuthUserMessage(
    kind: AuthUserErrorKind.invalidCredentials,
    title: 'Incorrect email or password.',
    detail: 'Check your details and try again.',
  );

  static const network = AuthUserMessage(
    kind: AuthUserErrorKind.network,
    title: 'No internet connection. Check your connection and try again.',
  );

  static const timeout = AuthUserMessage(
    kind: AuthUserErrorKind.timeout,
    title: 'Unable to connect. Please try again.',
  );

  static const rateLimited = AuthUserMessage(
    kind: AuthUserErrorKind.rateLimited,
    title: 'Too many sign-in attempts. Please wait a moment and try again.',
  );

  static const serviceUnavailable = AuthUserMessage(
    kind: AuthUserErrorKind.serviceUnavailable,
    title: 'We couldn’t sign you in right now. Please try again.',
  );

  static const cancelled = AuthUserMessage(
    kind: AuthUserErrorKind.cancelled,
    title: '',
  );

  static const unknown = AuthUserMessage(
    kind: AuthUserErrorKind.unknown,
    title: 'Something went wrong. Please try again.',
  );

  static const passwordResetGeneric = AuthUserMessage(
    kind: AuthUserErrorKind.unknown,
    title: 'If an account exists for that email, a reset link will be sent.',
  );

  static AuthUserMessage map(Object error) {
    if (error is TimeoutException) return timeout;
    if (error is SocketException) return network;
    if (error is HandshakeException) return network;

    if (error is AuthException) {
      return _mapAuthException(error);
    }

    if (error is FunctionException) {
      return _mapFunctionException(error);
    }

    final text = error.toString().toLowerCase();
    if (_looksCancelled(text)) return cancelled;
    if (_looksRateLimited(text)) return rateLimited;
    if (_looksTimeout(text)) return timeout;
    if (_looksNetwork(text)) return network;
    if (_looksServiceUnavailable(text)) return serviceUnavailable;
    if (_looksInvalidCredentials(text)) return invalidCredentials;

    return unknown;
  }

  static AuthUserMessage _mapAuthException(AuthException error) {
    final dynamic dyn = error;
    final code = '${dyn.code ?? ''} ${dyn.statusCode ?? ''} ${error.message}'
        .toLowerCase();

    if (_looksCancelled(code)) return cancelled;
    if (_looksRateLimited(code)) return rateLimited;
    if (_looksNetwork(code)) return network;
    if (_looksTimeout(code)) return timeout;
    if (_looksServiceUnavailable(code)) return serviceUnavailable;
    if (_looksInvalidCredentials(code)) return invalidCredentials;
    return unknown;
  }

  static AuthUserMessage _mapFunctionException(FunctionException error) {
    final status = error.status;
    final details = '${error.details ?? ''} ${error.reasonPhrase ?? ''} $status'
        .toLowerCase();

    if (status == 401 || status == 403) return invalidCredentials;
    if (status == 429) return rateLimited;
    if (status == 408) return timeout;
    if (status >= 500) return serviceUnavailable;
    if (_looksInvalidCredentials(details)) return invalidCredentials;
    if (_looksRateLimited(details)) return rateLimited;
    if (_looksNetwork(details)) return network;
    if (_looksTimeout(details)) return timeout;
    return unknown;
  }

  static bool _looksCancelled(String text) =>
      text.contains('cancel') ||
      text.contains('cancelled') ||
      text.contains('canceled') ||
      text.contains('access_denied') ||
      text.contains('user_cancelled');

  static bool _looksRateLimited(String text) =>
      text.contains('rate limit') ||
      text.contains('rate_limit') ||
      text.contains('too many') ||
      text.contains('429');

  static bool _looksTimeout(String text) =>
      text.contains('timeout') || text.contains('timed out');

  static bool _looksNetwork(String text) =>
      text.contains('socket') ||
      text.contains('network') ||
      text.contains('failed host lookup') ||
      text.contains('connection refused') ||
      text.contains('connection reset') ||
      text.contains('unreachable') ||
      text.contains('offline');

  static bool _looksServiceUnavailable(String text) =>
      text.contains('503') ||
      text.contains('502') ||
      text.contains('504') ||
      text.contains('service unavailable') ||
      text.contains('overloaded') ||
      text.contains('upstream');

  static bool _looksInvalidCredentials(String text) =>
      text.contains('invalid_credentials') ||
      text.contains('invalid login') ||
      text.contains('invalid email or password') ||
      text.contains('email not confirmed') ||
      text.contains('user not found') ||
      text.contains('wrong password') ||
      text.contains('invalid_grant');

  /// True when UI should stay quiet (OAuth cancel, empty message).
  static bool shouldSuppressUi(AuthUserMessage message) =>
      message.kind == AuthUserErrorKind.cancelled || message.title.isEmpty;
}
