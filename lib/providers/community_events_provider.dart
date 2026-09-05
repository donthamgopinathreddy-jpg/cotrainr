import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_event.dart';
import '../repositories/community_events_repository.dart';

final communityEventsRepositoryProvider =
    Provider<CommunityEventsRepository>((ref) {
  return CommunityEventsRepository();
});

/// Home Community Event card data. Null = render nothing.
final homeCommunityEventProvider =
    FutureProvider<CommunityEventCardData?>((ref) async {
  return ref.watch(communityEventsRepositoryProvider).fetchHomeEvent();
});
