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
    if (_currentUserId == null) return null;

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
    } catch (e) {
      print('Error fetching today metrics: $e');
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

  /// Get weekly metrics (last 7 days)
  Future<List<Map<String, dynamic>>> getWeeklyMetrics() async {
    if (_currentUserId == null) return [];

    try {
      final today = DateTime.now();
      final weekAgo = today.subtract(const Duration(days: 6));
      final weekAgoDate = DateTime(weekAgo.year, weekAgo.month, weekAgo.day);
      final weekAgoString = weekAgoDate.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('metrics_daily')
          .select()
          .eq('user_id', _currentUserId!)
          .gte('date', weekAgoString)
          .order('date', ascending: true);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error fetching weekly metrics: $e');
      return [];
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
    if (_currentUserId == null) return;

    try {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final dateString = todayDate.toIso8601String().split('T')[0];

      final updates = <String, dynamic>{};
      if (steps != null) updates['steps'] = steps;
      if (caloriesBurned != null) updates['calories_burned'] = caloriesBurned;
      if (distanceKm != null) updates['distance_km'] = distanceKm;
      if (waterIntakeLiters != null) updates['water_intake_liters'] = waterIntakeLiters;
      if (streakDays != null) updates['streak_days'] = streakDays;

      // Check if today's record exists
      final existing = await _supabase
          .from('metrics_daily')
          .select('id')
          .eq('user_id', _currentUserId!)
          .eq('date', dateString)
          .maybeSingle();

      if (existing != null) {
        // Update existing record
        await _supabase
            .from('metrics_daily')
            .update(updates)
            .eq('id', existing['id'] as String);
      } else {
        // Insert new record
        await _supabase.from('metrics_daily').insert({
          'user_id': _currentUserId!,
          'date': dateString,
          ...updates,
        });
      }
    } catch (e) {
      print('Error updating today metrics: $e');
    }
  }

  /// Increment water intake (add to existing value)
  Future<void> incrementWater(double liters) async {
    if (_currentUserId == null) return;

    try {
      // Get current water intake
      final existing = await getTodayMetrics();
      final currentWater = (existing?['water_intake_liters'] as num?)?.toDouble() ?? 0.0;
      final newWater = currentWater + liters;

      await updateTodayMetrics(waterIntakeLiters: newWater);
    } catch (e) {
      print('Error incrementing water: $e');
    }
  }
}
