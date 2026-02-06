import 'package:flutter/material.dart';

/// Model for provider service locations
class ProviderLocation {
  final String id;
  final String providerId;
  final LocationType locationType;
  final String displayName;
  final double latitude;
  final double longitude;
  final double radiusKm;
  final bool isPublicExact;
  final bool isActive;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProviderLocation({
    required this.id,
    required this.providerId,
    required this.locationType,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.isPublicExact,
    required this.isActive,
    required this.isPrimary,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Supabase JSON response
  factory ProviderLocation.fromJson(Map<String, dynamic> json) {
    // Handle geo field - can be Point or null
    double lat = 0.0;
    double lng = 0.0;
    
    if (json['geo'] != null) {
      // Supabase returns geo as a string like "POINT(lng lat)" or as coordinates
      final geo = json['geo'];
      if (geo is Map && geo['coordinates'] != null) {
        // GeoJSON format: [lng, lat]
        final coords = geo['coordinates'] as List;
        lng = (coords[0] as num).toDouble();
        lat = (coords[1] as num).toDouble();
      } else if (geo is String) {
        // Parse "POINT(lng lat)" format
        final match = RegExp(r'POINT\(([\d.]+)\s+([\d.]+)\)').firstMatch(geo);
        if (match != null) {
          lng = double.parse(match.group(1)!);
          lat = double.parse(match.group(2)!);
        }
      }
    }

    return ProviderLocation(
      id: json['id'] as String,
      providerId: json['provider_id'] as String,
      locationType: LocationType.fromString(json['location_type'] as String),
      displayName: json['display_name'] as String,
      latitude: lat,
      longitude: lng,
      radiusKm: (json['radius_km'] as num).toDouble(),
      isPublicExact: json['is_public_exact'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      isPrimary: json['is_primary'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to JSON for Supabase insert/update
  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'provider_id': providerId,
      'location_type': locationType.value,
      'display_name': displayName,
      'geo': 'POINT($longitude $latitude)',
      'radius_km': radiusKm,
      'is_public_exact': isPublicExact,
      'is_active': isActive,
      'is_primary': isPrimary,
    };
  }

  /// Create a copy with updated fields
  ProviderLocation copyWith({
    String? id,
    String? providerId,
    LocationType? locationType,
    String? displayName,
    double? latitude,
    double? longitude,
    double? radiusKm,
    bool? isPublicExact,
    bool? isActive,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProviderLocation(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      locationType: locationType ?? this.locationType,
      displayName: displayName ?? this.displayName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusKm: radiusKm ?? this.radiusKm,
      isPublicExact: isPublicExact ?? this.isPublicExact,
      isActive: isActive ?? this.isActive,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Location type enum
enum LocationType {
  home('home'),
  gym('gym'),
  studio('studio'),
  park('park'),
  other('other');

  final String value;
  const LocationType(this.value);

  static LocationType fromString(String value) {
    return LocationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => LocationType.other,
    );
  }

  String get displayName {
    switch (this) {
      case LocationType.home:
        return 'Home';
      case LocationType.gym:
        return 'Gym';
      case LocationType.studio:
        return 'Studio';
      case LocationType.park:
        return 'Park';
      case LocationType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case LocationType.home:
        return Icons.home_rounded;
      case LocationType.gym:
        return Icons.fitness_center_rounded;
      case LocationType.studio:
        return Icons.business_rounded;
      case LocationType.park:
        return Icons.park_rounded;
      case LocationType.other:
        return Icons.location_on_rounded;
    }
  }
}
