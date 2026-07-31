import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/leads_models.dart' show AcceptedProvider, AcceptedTrainer;
import 'leads_provider.dart';

/// Shared source of accepted trainers for the signed-in client.
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

final acceptedClientTrainersCountProvider = Provider<int>((ref) {
  return ref.watch(acceptedClientTrainersProvider).maybeWhen(
        data: (list) => list.length,
        orElse: () => 0,
      );
});

/// Accepted nutritionists for the signed-in client.
class AcceptedClientNutritionistsNotifier
    extends AsyncNotifier<List<AcceptedProvider>> {
  RealtimeChannel? _channel;

  @override
  Future<List<AcceptedProvider>> build() async {
    ref.onDispose(() {
      final ch = _channel;
      _channel = null;
      if (ch != null) {
        Supabase.instance.client.removeChannel(ch);
      }
    });

    _subscribeToLeadChanges();
    return ref.read(leadsServiceProvider).getAcceptedNutritionistsAsClient();
  }

  void _subscribeToLeadChanges() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _channel = Supabase.instance.client
        .channel('accepted-client-nutritionists-$uid')
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

  Future<void> refreshQuiet() async {
    state = await AsyncValue.guard(() async {
      return ref.read(leadsServiceProvider).getAcceptedNutritionistsAsClient();
    });
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return ref.read(leadsServiceProvider).getAcceptedNutritionistsAsClient();
    });
  }
}

final acceptedClientNutritionistsProvider = AsyncNotifierProvider<
    AcceptedClientNutritionistsNotifier, List<AcceptedProvider>>(
  AcceptedClientNutritionistsNotifier.new,
);

final acceptedClientNutritionistsCountProvider = Provider<int>((ref) {
  return ref.watch(acceptedClientNutritionistsProvider).maybeWhen(
        data: (list) => list.length,
        orElse: () => 0,
      );
});
