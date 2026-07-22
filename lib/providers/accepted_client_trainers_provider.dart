import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/leads_models.dart' show AcceptedTrainer;
import 'leads_provider.dart';

/// Shared source of accepted trainers for the signed-in client.
///
/// Used by Quick Access count, My Trainers list, and related client screens.
class AcceptedClientTrainersNotifier
    extends AsyncNotifier<List<AcceptedTrainer>> {
  RealtimeChannel? _channel;

  @override
  Future<List<AcceptedTrainer>> build() async {
    ref.onDispose(() {
      final ch = _channel;
      _channel = null;
      if (ch != null) {
        Supabase.instance.client.removeChannel(ch);
      }
    });

    _subscribeToLeadChanges();
    return ref.read(leadsServiceProvider).getAcceptedTrainersAsClient();
  }

  void _subscribeToLeadChanges() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _channel = Supabase.instance.client
        .channel('accepted-client-trainers-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'leads',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'client_id',
            value: uid,
          ),
          callback: (_) {
            refreshQuiet();
          },
        )
        .subscribe();
  }

  /// Soft refresh (keeps previous data visible while reloading).
  Future<void> refreshQuiet() async {
    state = await AsyncValue.guard(() async {
      return ref.read(leadsServiceProvider).getAcceptedTrainersAsClient();
    });
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return ref.read(leadsServiceProvider).getAcceptedTrainersAsClient();
    });
  }
}

final acceptedClientTrainersProvider = AsyncNotifierProvider<
    AcceptedClientTrainersNotifier, List<AcceptedTrainer>>(
  AcceptedClientTrainersNotifier.new,
);

/// Convenience count for Quick Access subtitle.
final acceptedClientTrainersCountProvider = Provider<int>((ref) {
  return ref.watch(acceptedClientTrainersProvider).maybeWhen(
        data: (list) => list.length,
        orElse: () => 0,
      );
});
