import 'package:flutter/foundation.dart';

/// Central MVP feature toggles.
///
/// Set to `true` in dev builds to re-enable dormant features without deleting code.
class FeatureFlags {
  FeatureFlags._();

  static const bool enableCoCircle = false;
  static const bool enableQuest = false;
  static const bool enableCommunityNotifications = false;
  static const bool enableLeaderboards = false;
  static const bool enableSocialProfiles = false;

  static final Set<String> _loggedBlocks = {};

  /// Debug-only log when a disabled feature path is skipped (once per [key]).
  static void logBlockedOnce(String key, String message) {
    if (!kDebugMode) return;
    if (_loggedBlocks.add(key)) {
      debugPrint('[FeatureFlags] $message');
    }
  }

  /// Community notification types (like, comment, follow).
  static bool get communityNotificationsActive =>
      enableCoCircle && enableCommunityNotifications;

  /// Quest-specific notification types (quest, achievement tied to quest system).
  static bool get questNotificationsActive => enableQuest;

  /// Leaderboard-related UI and notifications.
  static bool get leaderboardsActive => enableQuest && enableLeaderboards;
}
