import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/video_sessions_repository.dart';

/// Lists video sessions for the signed-in user (RLS-scoped).
final videoSessionsListProvider =
    FutureProvider.autoDispose<List<VideoSession>>((ref) async {
  return VideoSessionsRepository().listSessions();
});
