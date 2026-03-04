import 'dart:convert';

import 'package:http/http.dart' as http;

/// Result from Nominatim search API
class NominatimSearchResult {
  final double lat;
  final double lon;
  final String displayName;

  const NominatimSearchResult({
    required this.lat,
    required this.lon,
    required this.displayName,
  });
}

/// Service for searching locations via OpenStreetMap Nominatim API.
/// See: https://nominatim.org/release-docs/develop/api/Search/
class NominatimSearchService {
  static const _baseUrl = 'https://nominatim.openstreetmap.org/search';
  static const _userAgent = 'Cotrainr/1.0 (contact: support@cotrainr.app)';
  static const _limit = 6;

  /// Search for locations by query string.
  /// Returns empty list on failure or no results.
  Future<List<NominatimSearchResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return [];

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'q': trimmed,
        'format': 'json',
        'addressdetails': '1',
        'limit': _limit.toString(),
      },
    );

    try {
      final response = await http.get(
        uri,
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode != 200) return [];

      final list = jsonDecode(response.body);
      if (list is! List) return [];

      final results = <NominatimSearchResult>[];
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final lat = (item['lat'] as num?)?.toDouble();
        final lon = (item['lon'] as num?)?.toDouble();
        final displayName = item['display_name'] as String?;
        if (lat != null && lon != null && displayName != null && displayName.isNotEmpty) {
          results.add(NominatimSearchResult(
            lat: lat,
            lon: lon,
            displayName: displayName,
          ));
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }
}
