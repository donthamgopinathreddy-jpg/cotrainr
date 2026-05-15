import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/messages_repository.dart';

/// Unread DM count for bottom-nav badge and home hints.
final unreadMessagesCountProvider = FutureProvider<int>((ref) async {
  final messagesRepo = MessagesRepository();
  return messagesRepo.getUnreadMessagesCount();
});
