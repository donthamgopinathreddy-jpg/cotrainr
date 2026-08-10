/// Pure helpers for Recent foods derived from meal history.
library;

/// Deduplicate recent foods (newest-first input) by catalog [foodId] or name.
/// Keeps the first occurrence (most recently used serving).
List<T> dedupeRecentFoodsByKey<T>({
  required Iterable<T> newestFirst,
  required String Function(T item) dedupeKey,
  int limit = 30,
}) {
  final seen = <String>{};
  final out = <T>[];
  for (final item in newestFirst) {
    final key = dedupeKey(item);
    if (key.isEmpty || seen.contains(key)) continue;
    seen.add(key);
    out.add(item);
    if (out.length >= limit) break;
  }
  return out;
}

String recentFoodDedupeKey({String? foodId, required String foodName}) {
  final id = foodId?.trim();
  if (id != null && id.isNotEmpty) return 'id:$id';
  return 'name:${foodName.trim().toLowerCase()}';
}

String formatLastUsedServing({required double quantity, required String unit}) {
  final q = quantity == quantity.roundToDouble()
      ? quantity.round().toString()
      : quantity.toStringAsFixed(1);
  final u = unit.trim();
  if (u.toLowerCase() == '100g') return '$q g';
  if (u.toLowerCase() == 'serving') {
    return quantity == 1 ? '1 serving' : '$q servings';
  }
  if (RegExp(r'^\d+(\.\d+)?\s*g', caseSensitive: false).hasMatch(u)) {
    return '$q g';
  }
  // Countable labels like "1 egg" / "1 medium" → "4 eggs" style when possible.
  final m = RegExp(r'^1\s+(.+)$', caseSensitive: false).firstMatch(u);
  if (m != null) {
    final noun = m.group(1)!;
    if (quantity == 1) return '1 $noun';
    return '$q $noun';
  }
  return '$q × $u';
}
