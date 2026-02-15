import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/profile_repository.dart';

/// Notification preferences state
class NotificationPreferences {
  final bool push;
  final bool community;
  final bool reminders;
  final bool achievements;

  const NotificationPreferences({
    this.push = true,
    this.community = true,
    this.reminders = true,
    this.achievements = true,
  });

  NotificationPreferences copyWith({
    bool? push,
    bool? community,
    bool? reminders,
    bool? achievements,
  }) {
    return NotificationPreferences(
      push: push ?? this.push,
      community: community ?? this.community,
      reminders: reminders ?? this.reminders,
      achievements: achievements ?? this.achievements,
    );
  }
}

/// Provider for notification preferences (loaded from profile)
final notificationPreferencesProvider =
    FutureProvider<NotificationPreferences>((ref) async {
  final repo = ProfileRepository();
  final prefs = await repo.fetchNotificationPreferences();
  return NotificationPreferences(
    push: prefs['push'] ?? true,
    community: prefs['community'] ?? true,
    reminders: prefs['reminders'] ?? true,
    achievements: prefs['achievements'] ?? true,
  );
});
