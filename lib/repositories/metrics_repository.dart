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
      print('MetricsRepository: Cannot fetch metrics - user not authenticated');
      return null;
    }

    try {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final dateString = todayDate.toIso8601String().split('T')[0];

      print('MetricsRepository: Fetching metrics for user: $_currentUserId, date: $dateString');
      final response = await _supabase
          .from('metrics_daily')
          .select()
          .eq('user_id', _currentUserId!)
          .eq('date', dateString)
          .maybeSingle();

      if (response != null) {
        print('MetricsRepository: Found metrics - steps: ${response['steps']}, calories: ${response['calories_burned']}, water: ${response['water_intake_liters']}');
      } else {
        print('MetricsRepository: No metrics found for today');
      }

      return response;
    } catch (e, stackTrace) {
      print('MetricsRepository: Error fetching today metrics: $e');
      print('MetricsRepository: Stack trace: $stackTrace');
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
      print('Error fetching metrics for date: $e');
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
      print('Error fetching weekly metrics: $e');
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
      print('Error fetching metrics for $days days: $e');
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
      print('Error fetching monthly metrics: $e');
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
      print('Error updating metrics for date: $e');
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
      print('MetricsRepository: incrementWater skipped — not authenticated');
      return false;
    }
    if (liters <= 0) return false;

    try {
      final existing = await getTodayMetrics();
      final currentWater =
          (existing?['water_intake_liters'] as num?)?.toDouble() ?? 0.0;
      final newWater = currentWater + liters;

      await updateTodayMetrics(waterIntakeLiters: newWater);

      // Verify write landed.
      final verify = await getTodayMetrics();
      final verified =
          (verify?['water_intake_liters'] as num?)?.toDouble() ?? 0.0;
      if (verified + 0.0001 < newWater) {
        print(
          'MetricsRepository: incrementWater verify mismatch '
          'expected=$newWater actual=$verified',
        );
      }
      return true;
    } catch (e) {
      print('Error incrementing water: $e');
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
      print('Error fetching client metrics: $e');
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
      print('Error fetching client weekly metrics: $e');
      return [];
    }
  }
}
