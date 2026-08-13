import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Classifies startup/auth failures without treating network blips as logout.
enum StartupFailureKind {
  network,
  authInvalid,
  server,
  unknown,
}

StartupFailureKind classifyStartupFailure(Object error) {
  if (error is TimeoutException) return StartupFailureKind.network;
  if (error is SocketException) return StartupFailureKind.network;
  if (error is HandshakeException) return StartupFailureKind.network;

  if (error is AuthException) {
    final dynamic dyn = error;
    final rawCode = dyn.code ?? dyn.statusCode;
    final code = rawCode?.toString().toLowerCase() ?? '';
    final message = error.message.toLowerCase();
    const invalidMarkers = [
      'refresh_token',
      'invalid_grant',
      'session_not_found',
      'user_not_found',
      'invalid claim',
      'jwt',
      'token is expired',
      'invalid refresh',
    ];
    for (final marker in invalidMarkers) {
      if (code.contains(marker) || message.contains(marker)) {
        return StartupFailureKind.authInvalid;
      }
    }
    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('failed host lookup') ||
        message.contains('connection')) {
      return StartupFailureKind.network;
    }
  }

  final text = error.toString().toLowerCase();
  if (text.contains('refresh_token') ||
      text.contains('invalid refresh') ||
      text.contains('invalid_grant') ||
      text.contains('session_not_found')) {
    return StartupFailureKind.authInvalid;
  }
  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable') ||
      text.contains('connection refused') ||
      text.contains('connection reset') ||
      text.contains('timed out') ||
      text.contains('timeout')) {
    return StartupFailureKind.network;
  }

  if (text.contains('503') ||
      text.contains('502') ||
      text.contains('504') ||
      text.contains('cloudflare') ||
      text.contains('upstream')) {
    return StartupFailureKind.server;
  }

  return StartupFailureKind.unknown;
}

bool isNetworkStartupFailure(Object error) =>
    classifyStartupFailure(error) == StartupFailureKind.network;

bool isInvalidSessionFailure(Object error) =>
    classifyStartupFailure(error) == StartupFailureKind.authInvalid;
