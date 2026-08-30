import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Implemented by exceptions that carry a machine-readable failure code.
///
/// Only the code may influence user copy; the accompanying server message is
/// diagnostic text and never displayed.
abstract interface class VideoSessionResponseCode {
  String? get responseCode;
}

/// User-facing copy for video-session failures.
///
/// Nothing here may contain a backend exception class, an HTTP status, a
/// Postgres/RLS error code, an RPC or function name, a bucket or table name, a
/// signed URL, or an internal slug. Technical detail goes to [log], which is
/// debug-only.
abstract final class VideoSessionErrorMessages {
  static const network =
      'No internet connection. Check your connection and try again.';
  static const loadSession = 'Could not load this session. Try again.';
  static const loadSessions = 'Could not load sessions. Pull to retry.';
  static const createSession = 'Could not create the session. Try again.';
  static const updateSession = 'Could not update the session. Try again.';
  static const cancelSession = 'Could not cancel the session. Try again.';
  static const saveResponse = 'Could not save your response. Try again.';
  static const connectGoogle = 'Google Meet connection failed. Try again.';
  static const disconnectGoogle =
      'Could not disconnect Google Meet. Try again.';
  static const googleStatusUnknown =
      'Couldn\u2019t check your Google Meet connection.';

  /// Transport-level failures worth telling the user to retry on connectivity.
  static bool isNetwork(Object? error) {
    if (error == null) return false;
    if (error is SocketException ||
        error is HttpException ||
        error is HandshakeException ||
        error is TimeoutException) {
      return true;
    }
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection closed') ||
        text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('network is unreachable') ||
        text.contains('timeout');
  }

  static String forLoadSession(Object? error) =>
      isNetwork(error) ? network : loadSession;

  static String forLoadSessions(Object? error) =>
      isNetwork(error) ? network : loadSessions;

  static String forCreate(Object? error) =>
      isNetwork(error) ? network : createSession;

  static String forUpdate(Object? error) =>
      isNetwork(error) ? network : updateSession;

  static String forCancel(Object? error) =>
      isNetwork(error) ? network : cancelSession;

  static const responseNoLongerAllowed =
      'This session can no longer be updated.';

  static String forResponse(Object? error) {
    if (isNetwork(error)) return network;
    // Only the code is trusted; the server's message text is not user copy.
    final code = error is VideoSessionResponseCode ? error.responseCode : null;
    if (code == 'FORBIDDEN' || code == 'NOT_FOUND' || code == 'CONFLICT') {
      return responseNoLongerAllowed;
    }
    return saveResponse;
  }

  static String forDisconnect(Object? error) =>
      isNetwork(error) ? network : disconnectGoogle;

  static String forConnect(Object? error) =>
      isNetwork(error) ? network : connectGoogle;

  /// Maps the OAuth callback's internal slug to user copy.
  ///
  /// The callback emits a fixed allow-list of slugs (for example the state
  /// lookup failing, or the token upsert failing). Those are diagnostic
  /// identifiers, not user copy, so an unrecognised slug must fall through to
  /// the generic message rather than being displayed.
  static String forOAuthSlug(String? slug) {
    switch (slug?.trim().toLowerCase()) {
      case 'access_denied':
      case 'user_denied':
        return 'Google Meet connection was cancelled.';
      case 'invalid_state':
      case 'state_expired':
      case 'missing_code_or_state':
        return 'That Google Meet connection attempt expired. Try connecting again.';
      case 'missing_refresh_token':
        return 'Google Meet needs offline access. Try connecting again and allow all permissions.';
      default:
        return connectGoogle;
    }
  }

  static void log(String context, Object error, [StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    debugPrint('[VideoSessions] $context failed: $error');
    if (stackTrace != null) debugPrint(stackTrace.toString());
  }
}
