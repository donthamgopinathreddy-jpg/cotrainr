import 'package:flutter_test/flutter_test.dart';

import 'package:cotrainr/models/discover_filters.dart';

void main() {
  group('DiscoverFilters defaults', () {
    test('neutral defaults do not count as active filters', () {
      const filters = DiscoverFilters();
      expect(filters.maxDistanceKm, 50.0);
      expect(filters.minRating, isNull);
      expect(filters.categories, isEmpty);
      expect(filters.hasActiveFilters, isFalse);
    });

    test('tighter distance or rating marks filters active', () {
      expect(
        const DiscoverFilters(maxDistanceKm: 10).hasActiveFilters,
        isTrue,
      );
      expect(
        const DiscoverFilters(minRating: 4.0).hasActiveFilters,
        isTrue,
      );
      expect(
        DiscoverFilters(categories: {'yoga'}).hasActiveFilters,
        isTrue,
      );
    });
  });
}
