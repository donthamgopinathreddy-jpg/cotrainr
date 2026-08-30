import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Sanitized, user-facing copy for verification / provider-profile failures.
///
/// Technical details (Postgrest / Storage / Function exceptions, SQL, HTTP
/// bodies, paths) are logged in debug builds only and never rendered.
abstract final class VerificationErrorMessages {
  static const network =
      'No internet connection. Check your connection and try again.';
  static const loadStatus =
      'We couldn’t load your verification status. Try again.';
  static const loadRole =
      'We couldn’t confirm your account type. Try again.';
  static const submit =
      'We couldn’t submit your documents. Try again.';
  static const saveProfessional =
      'We couldn’t save your professional profile. Try again.';
  static const loadCertifications =
      'We couldn’t load your certifications. Try again.';
  static const logout = 'We couldn’t sign you out. Try again.';
  static const pendingAlready =
      'You already have a pending submission. Please wait for review.';

  static bool isNetwork(Object? error) {
    if (error is SocketException) return true;
    if (error is HandshakeException) return true;
    if (error is TimeoutException) return true;
    final text = error?.toString().toLowerCase() ?? '';
    return text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('network is unreachable') ||
        text.contains('timeout');
  }

  static String forLoadStatus(Object? error) =>
      isNetwork(error) ? network : loadStatus;

  static String forLoadRole(Object? error) =>
      isNetwork(error) ? network : loadRole;

  static String forSaveProfessional(Object? error) =>
      isNetwork(error) ? network : saveProfessional;

  static String forSubmit(Object? error) {
    if (isNetwork(error)) return network;
    // Server-authored, already user-safe guard message.
    final text = error?.toString() ?? '';
    if (text.contains('pending submission')) return pendingAlready;
    return submit;
  }

  static String forLogout(Object? error) =>
      isNetwork(error) ? network : logout;

  /// Debug-only technical logging. Never logs tokens, sessions or document URLs.
  static void log(String context, Object? error, [StackTrace? stack]) {
    if (!kDebugMode) return;
    debugPrint('[verification] $context failed: $error');
    if (stack != null) debugPrint('$stack');
  }
}
