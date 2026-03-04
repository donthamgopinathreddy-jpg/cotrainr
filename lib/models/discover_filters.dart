/// Filters for discover page provider search
class DiscoverFilters {
  final double maxDistanceKm;
  final List<String>? providerTypes;
  final List<String>? locationTypes;
  final double? minRating;
  final Set<String> categories;

  const DiscoverFilters({
    this.maxDistanceKm = 50.0,
    this.providerTypes,
    this.locationTypes,
    this.minRating,
    this.categories = const {},
  });

  DiscoverFilters copyWith({
    double? maxDistanceKm,
    List<String>? providerTypes,
    List<String>? locationTypes,
    double? minRating,
    Set<String>? categories,
  }) {
    return DiscoverFilters(
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      providerTypes: providerTypes ?? this.providerTypes,
      locationTypes: locationTypes ?? this.locationTypes,
      minRating: minRating ?? this.minRating,
      categories: categories ?? this.categories,
    );
  }

  bool get hasActiveFilters =>
      maxDistanceKm < 50 ||
      minRating != null ||
      categories.isNotEmpty;

  /// Short label for filter chips, e.g. "Within 10 km • 4.5+ • Gym"
  String toChipLabel() {
    final parts = <String>[];
    if (maxDistanceKm < 50) {
      parts.add('Within ${maxDistanceKm.toInt()} km');
    }
    if (minRating != null) {
      parts.add('${minRating!.toStringAsFixed(1)}+');
    }
    if (categories.isNotEmpty) {
      parts.add(categories.take(2).join(', '));
      if (categories.length > 2) {
        parts.add('+${categories.length - 2}');
      }
    }
    return parts.isEmpty ? 'All' : parts.join(' • ');
  }
}
