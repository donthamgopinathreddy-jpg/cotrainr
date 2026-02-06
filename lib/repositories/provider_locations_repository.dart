import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/provider_location_model.dart';

/// Repository for managing provider locations
/// Handles all Supabase queries for provider_locations table
class ProviderLocationsRepository {
  final SupabaseClient _supabase;

  ProviderLocationsRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Get current user ID
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Fetch all locations for the current provider
  Future<List<ProviderLocation>> fetchMyLocations() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _supabase
          .from('provider_locations')
          .select()
          .eq('provider_id', _currentUserId!)
          .order('is_primary', ascending: false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ProviderLocation.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch locations: $e');
    }
  }

  /// Insert or update a location
  /// If id is provided, updates existing; otherwise inserts new
  Future<ProviderLocation> upsertLocation(ProviderLocation location) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Ensure provider_id matches current user
    final locationWithProvider = location.copyWith(providerId: _currentUserId!);

    try {
      final json = locationWithProvider.toJson();
      
      // Remove id for insert, keep for update
      if (location.id.isEmpty) {
        json.remove('id');
      }

      // Ensure home locations have is_public_exact=false
      if (location.locationType == LocationType.home) {
        json['is_public_exact'] = false;
      }

      final response = location.id.isEmpty
          ? await _supabase
              .from('provider_locations')
              .insert(json)
              .select()
              .single()
          : await _supabase
              .from('provider_locations')
              .update(json)
              .eq('id', location.id)
              .eq('provider_id', _currentUserId!)
              .select()
              .single();

      return ProviderLocation.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to save location: $e');
    }
  }

  /// Delete a location
  Future<void> deleteLocation(String locationId) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _supabase
          .from('provider_locations')
          .delete()
          .eq('id', locationId)
          .eq('provider_id', _currentUserId!);
    } catch (e) {
      throw Exception('Failed to delete location: $e');
    }
  }

  /// Set a location as primary (automatically un-sets others via trigger)
  Future<void> setPrimary(String locationId) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _supabase
          .from('provider_locations')
          .update({'is_primary': true})
          .eq('id', locationId)
          .eq('provider_id', _currentUserId!);
    } catch (e) {
      throw Exception('Failed to set primary location: $e');
    }
  }

  /// Toggle active status of a location
  Future<void> setActive(String locationId, bool isActive) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _supabase
          .from('provider_locations')
          .update({'is_active': isActive})
          .eq('id', locationId)
          .eq('provider_id', _currentUserId!);
    } catch (e) {
      throw Exception('Failed to update location status: $e');
    }
  }

  /// Fetch nearby providers for discovery (public API)
  /// Uses the nearby_providers RPC function for efficient spatial queries
  /// 
  /// TODO: Integrate this in Discover page to replace mock data
  Future<List<Map<String, dynamic>>> fetchNearbyProviders({
    required double userLat,
    required double userLng,
    double maxDistanceKm = 50.0,
    List<LocationType>? locationTypes,
  }) async {
    try {
      final locationTypeStrings = locationTypes?.map((e) => e.value).toList();
      
      final response = await _supabase.rpc(
        'nearby_providers',
        params: {
          'user_lat': userLat,
          'user_lng': userLng,
          'max_distance_km': maxDistanceKm,
          'location_types': locationTypeStrings,
        },
      );

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Failed to fetch nearby providers: $e');
    }
  }
}
