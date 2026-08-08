import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/notifications_repository.dart';
import '../repositories/profile_repository.dart';

/// Unread app-notification count for the home bell badge.
/// Source of truth: Supabase `notifications.read = false` (prefs-filtered).
final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  final notificationsRepo = NotificationsRepository();
  final profileRepo = ProfileRepository();
  final prefs = await profileRepo.fetchNotificationPreferences();
  return notificationsRepo.fetchUnreadCount(
    community: prefs['community'] ?? true,
    reminders: prefs['reminders'] ?? true,
    achievements: prefs['achievements'] ?? true,
  );
});
