import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/notifications_repository.dart';

/// Unread video-session activity for the Explore Video Sessions red dot.
/// Not shown merely because an upcoming session exists.
final unreadVideoSessionNotificationsProvider = FutureProvider<int>((ref) async {
  return NotificationsRepository().fetchUnreadVideoSessionCount();
});
