import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../repositories/metrics_repository.dart';
import 'hydration_local_store.dart';
import 'water_reminder_service.dart';

/// Single source of truth for adding water (in-app + notification quick actions).
class WaterIntakeService {
  WaterIntakeService._();

  static final WaterIntakeService instance = WaterIntakeService._();

  /// Bumped after water is added from UI or notification actions.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  final MetricsRepository _metricsRepo = MetricsRepository();
  final HydrationLocalStore _local = HydrationLocalStore.instance;

  /// Adds [liters] using the same flow as in-app +250 ml.
  ///
  /// Local calendar day is updated first; then Supabase `metrics_daily`
  /// is incremented when a session is available.
  Future<double?> addWater(
    double liters, {
    String source = 'app',
    String? eventId,
  }) async {
    if (liters <= 0) return null;
    final amountMl = (liters * 1000).round();
    if (amountMl <= 0) return null;

    final id =
        eventId ?? 'app_${DateTime.now().microsecondsSinceEpoch}_$amountMl';

    try {
      final localTotalMl = await _local.applyEvent(
        eventId: id,
        amountMl: amountMl,
        source: source,
      );
      if (localTotalMl == null) {
        // Duplicate callback — return current local total without re-adding.
        final existing = await _local.getTodayMl();
        return existing / 1000.0;
      }

      await _ensureSupabaseReady();
      final synced = await _syncLocalEventToRemote(
        eventId: id,
        amountMl: amountMl,
        absoluteLocalMl: localTotalMl,
      );

      final totalLiters = (synced ?? localTotalMl) / 1000.0;
      revision.value++;

      if (kDebugMode) {
        debugPrint(
          'WaterIntakeService: +${amountMl}ml source=$source '
          'total=${totalLiters}L synced=${synced != null}',
        );
      }

      try {
        await WaterReminderService.instance.syncHydrationSnapshot(
          consumedLiters: totalLiters,
        );
      } catch (_) {}

      return totalLiters;
    } catch (e, stack) {
      debugPrint('WaterIntakeService: failed to add water: $e\n$stack');
      return null;
    }
  }

  /// Flush pending notification/offline events to Supabase (app resume).
  Future<void> flushPendingRemoteSync() async {
    await _ensureSupabaseReady();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      revision.value++;
      return;
    }

    final pending = await _local.pendingEvents();
    for (final event in pending) {
      final eventId = event['eventId'] as String?;
      final amountMl = (event['amountMl'] as num?)?.toInt();
      if (eventId == null || amountMl == null || amountMl <= 0) continue;

      final ok = await _metricsRepo.incrementWater(amountMl / 1000.0);
      if (ok) {
        await _local.removePendingEvent(eventId);
      }
    }

    final remaining = await _local.pendingEvents();
    final localMl = await _local.getTodayMl();
    final remote = await _metricsRepo.getTodayMetrics();
    final remoteLiters =
        (remote?['water_intake_liters'] as num?)?.toDouble();
    if (remoteLiters != null) {
      final remoteMl = (remoteLiters * 1000).round();
      // Never overwrite a higher local total while offline events remain.
      final bestMl = remaining.isEmpty
          ? (remoteMl >= localMl ? remoteMl : localMl)
          : (localMl >= remoteMl ? localMl : remoteMl);
      await _local.setTodayMl(bestMl);
      try {
        await WaterReminderService.instance.syncHydrationSnapshot(
          consumedLiters: bestMl / 1000.0,
        );
      } catch (_) {}
    }
    revision.value++;
  }

  /// Today’s water for Home / Insights / notifications (local-first).
  Future<double> getTodayLiters() async {
    final localMl = await _local.getTodayMl();
    try {
      await _ensureSupabaseReady();
      final remote = await _metricsRepo.getTodayMetrics();
      final remoteLiters =
          (remote?['water_intake_liters'] as num?)?.toDouble();
      if (remoteLiters != null) {
        final remoteMl = (remoteLiters * 1000).round();
        final pending = await _local.pendingEvents();
        final bestMl = pending.isEmpty
            ? (remoteMl >= localMl ? remoteMl : localMl)
            : (localMl >= remoteMl ? localMl : remoteMl);
        if (bestMl != localMl) {
          await _local.setTodayMl(bestMl);
        }
        return bestMl / 1000.0;
      }
    } catch (_) {}
    return localMl / 1000.0;
  }

  Future<int?> _syncLocalEventToRemote({
    required String eventId,
    required int amountMl,
    required int absoluteLocalMl,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (kDebugMode) {
        debugPrint(
          'WaterIntakeService: no session — kept local +${amountMl}ml pending sync',
        );
      }
      return null;
    }

    final ok = await _metricsRepo.incrementWater(amountMl / 1000.0);
    if (!ok) return null;

    await _local.removePendingEvent(eventId);

    final remote = await _metricsRepo.getTodayMetrics();
    final remoteMl =
        ((remote?['water_intake_liters'] as num?)?.toDouble() ?? 0) * 1000;
    final reconciled = remoteMl.round();
    final best =
        reconciled >= absoluteLocalMl ? reconciled : absoluteLocalMl;
    await _local.setTodayMl(best);
    return best;
  }

  Future<void> _ensureSupabaseReady() async {
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
    }

    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) {
      try {
        await auth.refreshSession();
      } catch (_) {}
    }
  }
}
