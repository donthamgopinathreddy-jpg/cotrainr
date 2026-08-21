import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for managing daily metrics in Supabase
class MetricsRepository {
  final SupabaseClient _supabase;

  MetricsRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Get current user ID
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Get today's metrics for the current user
  Future<Map<String, dynamic>?> getTodayMetrics() async {
    if (_currentUserId == null) {
      return null;
    }

    try {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final dateString = todayDate.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('metrics_daily')
          .select()
          .eq('user_id', _currentUserId!)
          .eq('date', dateString)
          .maybeSingle();

      return response;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('MetricsRepository: today metrics failed');
        debugPrint('$stackTrace');
      }
      return null;
    }
  }

  /// Get metrics for a specific date
  Future<Map<String, dynamic>?> getMetricsForDate(DateTime date) async {
    if (_currentUserId == null) return null;

    try {
      final dateOnly = DateTime(date.year, date.month, date.day);
      final dateString = dateOnly.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('metrics_daily')
          .select()
          .eq('user_id', _currentUserId!)
          .eq('date', dateString)
          .maybeSingle();

      return response;
    } catch (e) {
      if (kDebugMode) debugPrint('MetricsRepository: date fetch failed');
      return null;
    }
  }

  /// Get weekly metrics (last 7 days, inclusive of today).
  Future<List<Map<String, dynamic>>> getWeeklyMetrics() async {
    if (_currentUserId == null) return [];

    try {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final weekAgo = todayDate.subtract(const Duration(days: 6));
      final weekAgoString = weekAgo.toIso8601String().split('T')[0];
      final todayString = todayDate.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('metrics_daily')
          .select()
          .eq('user_id', _currentUserId!)
          .gte('date', weekAgoString)
          .lte('date', todayString)
          .order('date', ascending: true);

      final rows = (response as List).cast<Map<String, dynamic>>();
      if (kDebugMode) {
        debugPrint(
          'MetricsRepository.getWeeklyMetrics: ${rows.length} rows '
          '($weekAgoString…$todayString)',
        );
      }
      return rows;
    } catch (e) {
      if (kDebugMode) debugPrint('MetricsRepository: weekly fetch failed');
      return [];
    }
  }

  /// Metrics for the last [days] days (inclusive of today).
  Future<List<Map<String, dynamic>>> getMetricsForDays(int days) async {
    if (_currentUserId == null || days < 1) return [];

    try {
      final today = DateTime.now();
      final start = today.subtract(Duration(days: days - 1));
      final startDate = DateTime(start.year, start.month, start.day);
      final startString = startDate.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('metrics_daily')
          .select()
          .eq('user_id', _currentUserId!)
          .gte('date', startString)
          .order('date', ascending: true);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) debugPrint('MetricsRepository: days fetch failed');
      return [];
    }
  }

  /// Get monthly metrics (last 30 days)
  Future<List<Map<String, dynamic>>> getMonthlyMetrics() async {
    if (_currentUserId == null) return [];

    try {
      final today = DateTime.now();
      final monthAgo = today.subtract(const Duration(days: 29));
      final monthAgoDate = DateTime(monthAgo.year, monthAgo.month, monthAgo.day);
      final monthAgoString = monthAgoDate.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('metrics_daily')
          .select()
          .eq('user_id', _currentUserId!)
          .gte('date', monthAgoString)
          .order('date', ascending: true);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) debugPrint('MetricsRepository: monthly fetch failed');
      return [];
    }
  }

  /// Update metrics for an arbitrary calendar day (weekly HC backfill).
  Future<void> updateMetricsForDate(
    DateTime date, {
    int? steps,
    double? caloriesBurned,
    double? distanceKm,
    double? waterIntakeLiters,
    int? streakDays,
  }) async {
    if (_currentUserId == null) return;

    try {
      final dateOnly = DateTime(date.year, date.month, date.day);
      final dateString = dateOnly.toIso8601String().split('T')[0];

      final updates = <String, dynamic>{};
      if (steps != null) updates['steps'] = steps;
      if (caloriesBurned != null) updates['calories_burned'] = caloriesBurned;
      if (distanceKm != null) updates['distance_km'] = distanceKm;
      if (waterIntakeLiters != null) {
        updates['water_intake_liters'] = waterIntakeLiters;
      }
      if (streakDays != null) updates['streak_days'] = streakDays;
      if (updates.isEmpty) return;

      final existing = await _supabase
          .from('metrics_daily')
          .select('id')
          .eq('user_id', _currentUserId!)
          .eq('date', dateString)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('metrics_daily')
            .update(updates)
            .eq('id', existing['id'] as String);
      } else {
        await _supabase.from('metrics_daily').insert({
          'user_id': _currentUserId!,
          'date': dateString,
          ...updates,
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MetricsRepository: date update failed');
      rethrow;
    }
  }

  /// Update or insert today's metrics
  Future<void> updateTodayMetrics({
    int? steps,
    double? caloriesBurned,
    double? distanceKm,
    double? waterIntakeLiters,
    int? streakDays,
  }) async {
    await updateMetricsForDate(
      DateTime.now(),
      steps: steps,
      caloriesBurned: caloriesBurned,
      distanceKm: distanceKm,
      waterIntakeLiters: waterIntakeLiters,
      streakDays: streakDays,
    );
  }

  /// Increment water intake (add to existing value).
  /// Returns `true` when the write succeeds for an authenticated user.
  Future<bool> incrementWater(double liters) async {
    if (_currentUserId == null) {
      return false;
    }
    if (liters <= 0) return false;

    try {
      final existing = await getTodayMetrics();
      final currentWater =
          (existing?['water_intake_liters'] as num?)?.toDouble() ?? 0.0;
      final newWater = currentWater + liters;

      await updateTodayMetrics(waterIntakeLiters: newWater);

      final verify = await getTodayMetrics();
      final verified =
          (verify?['water_intake_liters'] as num?)?.toDouble() ?? 0.0;
      if (verified + 0.0001 < newWater && kDebugMode) {
        debugPrint('MetricsRepository: incrementWater verify mismatch');
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('MetricsRepository: incrementWater failed');
      return false;
    }
  }

  /// Get metrics for a client (coach only - requires accepted lead, RLS enforces)
  Future<Map<String, dynamic>?> getClientMetricsForDate(String clientId, DateTime date) async {
    if (_currentUserId == null) return null;
    try {
      final dateStr = DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];
      final response = await _supabase
          .from('metrics_daily')
          .select()
          .eq('user_id', clientId)
          .eq('date', dateStr)
          .maybeSingle();
      return response;
    } catch (e) {
      if (kDebugMode) debugPrint('MetricsRepository: client metrics failed');
      return null;
    }
  }

  /// Get weekly metrics for a client (coach only)
  Future<List<Map<String, dynamic>>> getClientWeeklyMetrics(String clientId) async {
    if (_currentUserId == null) return [];
    try {
      final today = DateTime.now();
      final weekAgo = today.subtract(const Duration(days: 6));
      final weekAgoStr = '${weekAgo.year}-${weekAgo.month.toString().padLeft(2, '0')}-${weekAgo.day.toString().padLeft(2, '0')}';
      final response = await _supabase
          .from('metrics_daily')
          .select()
          .eq('user_id', clientId)
          .gte('date', weekAgoStr)
          .order('date', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) debugPrint('MetricsRepository: client weekly failed');
      return [];
    }
  }
}
