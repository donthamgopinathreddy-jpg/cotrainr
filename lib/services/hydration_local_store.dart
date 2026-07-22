import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-first hydration totals + pending remote sync events.
///
/// Uses the same local calendar day key as [MetricsRepository]
/// (`yyyy-MM-dd` from `DateTime.now()`).
class HydrationLocalStore {
  HydrationLocalStore._();

  static final HydrationLocalStore instance = HydrationLocalStore._();

  static const _keyDate = 'hydration_local_date';
  static const _keyMl = 'hydration_local_ml';
  static const _keyPending = 'hydration_pending_events_v1';
  static const _keyProcessedIds = 'hydration_processed_event_ids_v1';

  String localDateKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<void> _ensureToday(SharedPreferences prefs) async {
    final today = localDateKey();
    final stored = prefs.getString(_keyDate);
    if (stored != today) {
      await prefs.setString(_keyDate, today);
      await prefs.setInt(_keyMl, 0);
      // Keep pending events — they carry their own localDate.
    }
  }

  Future<int> getTodayMl() async {
    final prefs = await _prefs;
    await _ensureToday(prefs);
    return prefs.getInt(_keyMl) ?? 0;
  }

  Future<void> setTodayMl(int ml) async {
    final prefs = await _prefs;
    await prefs.setString(_keyDate, localDateKey());
    await prefs.setInt(_keyMl, ml.coerceAtLeast(0));
  }

  /// Returns null if [eventId] was already processed (duplicate callback).
  Future<int?> applyEvent({
    required String eventId,
    required int amountMl,
    required String source,
  }) async {
    if (amountMl <= 0) return null;
    final prefs = await _prefs;
    await _ensureToday(prefs);

    final processed = prefs.getStringList(_keyProcessedIds) ?? <String>[];
    if (processed.contains(eventId)) {
      if (kDebugMode) {
        debugPrint('HydrationLocalStore: duplicate event $eventId ignored');
      }
      return null;
    }

    final next = (prefs.getInt(_keyMl) ?? 0) + amountMl;
    await prefs.setInt(_keyMl, next);

    processed.add(eventId);
    // Bound memory — keep last 40 ids.
    while (processed.length > 40) {
      processed.removeAt(0);
    }
    await prefs.setStringList(_keyProcessedIds, processed);

    final pending = _readPending(prefs);
    pending.add({
      'eventId': eventId,
      'amountMl': amountMl,
      'localDate': localDateKey(),
      'source': source,
      'loggedAt': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_keyPending, jsonEncode(pending));

    return next;
  }

  Future<List<Map<String, dynamic>>> pendingEvents() async {
    final prefs = await _prefs;
    return _readPending(prefs);
  }

  Future<void> removePendingEvent(String eventId) async {
    final prefs = await _prefs;
    final pending = _readPending(prefs)
      ..removeWhere((e) => e['eventId'] == eventId);
    await prefs.setString(_keyPending, jsonEncode(pending));
  }

  List<Map<String, dynamic>> _readPending(SharedPreferences prefs) {
    final raw = prefs.getString(_keyPending);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }
}

extension on int {
  int coerceAtLeast(int min) => this < min ? min : this;
}
