import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Attachment kinds that can fail to send, for error copy only.
enum ChatMediaKind { image, video, document, audio }

/// Maps backend failures to user-facing copy for the messaging UI.
///
/// Nothing here ever returns text derived from the underlying exception. A
/// production user must never see a Supabase/PostgREST/Storage exception, an
/// HTTP status, a bucket name, a SQL or RPC identifier, a signed URL, or a
/// stack trace. Technical detail goes to [logMessagingError], which is a no-op
/// outside debug builds.
abstract final class MessagingErrorMessages {
  static const network =
      'No internet connection. Check your connection and try again.';
  static const imageSend = 'Image sending failed. Tap Retry.';
  static const videoSend = 'Video sending failed. Tap Retry.';
  static const documentSend = 'File sending failed. Tap Retry.';
  static const audioSend = 'Voice message failed. Tap Retry.';
  static const textSend = "Message couldn't be sent. Tap Retry.";
  static const mediaAccess = 'Unable to load this attachment.';
  static const mediaUnavailable = 'This attachment is no longer available.';
  static const deleteFailed = "Couldn't delete message. Try again.";
  static const generic = 'Something went wrong. Please try again.';
  static const connectionEnded =
      'This connection has ended. You can still view previous messages.';
  static const micDenied =
      'Microphone access is needed to send voice messages.';
  static const cameraDenied =
      'Camera access is needed to take a photo.';
  static const recordingTooShort = 'Recording is too short.';
  static const recordingFailed = 'Could not record audio. Try again.';
  static const playbackFailed = 'Unable to play this voice message.';

  /// Heuristic for RLS/policy denials when an accepted lead is gone.
  /// Never returns exception text — callers use [connectionEnded] for UI.
  static bool looksLikeEndedConnectionDenial(Object? error) {
    if (error == null) return false;
    final s = error.toString().toLowerCase();
    return s.contains('no_accepted_lead') ||
        s.contains('can_send_message') ||
        (s.contains('row-level security') &&
            (s.contains('messages') || s.contains('policy')));
  }

  /// Copy for a failed attachment send, falling back to the network message
  /// when the failure is clearly connectivity rather than the backend.
  static String forMediaSend(ChatMediaKind kind, Object? error) {
    if (isNetworkError(error)) return network;
    return switch (kind) {
      ChatMediaKind.image => imageSend,
      ChatMediaKind.video => videoSend,
      ChatMediaKind.document => documentSend,
      ChatMediaKind.audio => audioSend,
    };
  }

  /// Compact label shown inside a failed attachment bubble, next to Retry.
  static String bubbleLabelFor(ChatMediaKind kind) {
    return switch (kind) {
      ChatMediaKind.image => 'Image sending failed',
      ChatMediaKind.video => 'Video sending failed',
      ChatMediaKind.document => 'File sending failed',
      ChatMediaKind.audio => 'Voice message failed',
    };
  }

  static String forTextSend(Object? error) {
    if (isNetworkError(error)) return network;
    return textSend;
  }

  static String forMediaAccess(Object? error) {
    if (isNetworkError(error)) return network;
    return mediaAccess;
  }

  static String forDelete(Object? error) {
    if (isNetworkError(error)) return network;
    return deleteFailed;
  }

  static String forGeneric(Object? error) {
    if (isNetworkError(error)) return network;
    return generic;
  }

  /// Connectivity failures, identified by exception type rather than by
  /// scraping message text so no backend wording can leak through.
  static bool isNetworkError(Object? error) {
    if (error is SocketException) return true;
    if (error is HttpException) return true;
    if (error is TimeoutException) return true;
    if (error is HandshakeException) return true;
    return false;
  }

  /// Debug-only technical logging. Never called in release, so exception text
  /// cannot reach logs on a user device.
  static void logMessagingError(String context, Object error, [StackTrace? s]) {
    if (!kDebugMode) return;
    debugPrint('Messaging[$context]: $error');
    if (s != null) debugPrint(s.toString());
  }
}
