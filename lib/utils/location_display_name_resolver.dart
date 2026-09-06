import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

/// Resolves a human-friendly place/area label from coordinates.
/// Uses platform geocoding first, then Nominatim reverse as fallback.
class LocationDisplayNameResolver {
  LocationDisplayNameResolver({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _userAgent = 'Cotrainr/1.0 (contact: support@cotrainr.app)';

  /// Returns a display label, or null if nothing useful could be resolved.
  Future<String?> resolve(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final label = _fromPlacemark(placemarks.first);
        if (label != null && label.isNotEmpty) return label;
      }
    } catch (_) {
      // Fall through to Nominatim.
    }
    return _fromNominatim(lat, lng);
  }

  String? _fromPlacemark(Placemark p) {
    final seen = <String>{};
    final parts = <String>[];
    for (final value in [
      p.name,
      p.street,
      p.thoroughfare,
      p.subLocality,
      p.locality,
      p.subAdministrativeArea,
      p.administrativeArea,
      p.country,
    ]) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty && seen.add(trimmed)) {
        parts.add(trimmed);
      }
    }
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  Future<String?> _fromNominatim(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lng',
      );
      final response = await _http.get(
        uri,
        headers: {'User-Agent': _userAgent},
      );
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return null;
      final address = json['address'];
      if (address is! Map<String, dynamic>) return null;

      final parts = <String>[];
      for (final key in [
        'suburb',
        'neighbourhood',
        'village',
        'town',
        'city',
        'municipality',
        'state',
        'country',
      ]) {
        final v = address[key];
        if (v is String && v.trim().isNotEmpty && !parts.contains(v.trim())) {
          parts.add(v.trim());
        }
      }
      if (parts.isEmpty) return null;
      return parts.join(', ');
    } catch (_) {
      return null;
    }
  }
}
