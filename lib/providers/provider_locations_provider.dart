import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/provider_locations_repository.dart';
import '../models/provider_location_model.dart';

/// Provider for ProviderLocationsRepository
final providerLocationsRepositoryProvider = Provider<ProviderLocationsRepository>((ref) {
  return ProviderLocationsRepository();
});

/// Provider for current provider's locations
/// Uses AsyncNotifier for async state management
class ProviderLocationsNotifier extends AsyncNotifier<List<ProviderLocation>> {
  @override
  Future<List<ProviderLocation>> build() async {
    final repo = ref.read(providerLocationsRepositoryProvider);
    return await repo.fetchMyLocations();
  }

  /// Refresh locations from server
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(providerLocationsRepositoryProvider);
      return await repo.fetchMyLocations();
    });
  }

  /// Add or update a location
  Future<void> upsertLocation(ProviderLocation location) async {
    final repo = ref.read(providerLocationsRepositoryProvider);
    try {
      await repo.upsertLocation(location);
      // Refresh after update
      await refresh();
    } catch (e) {
      // Error will be shown in UI
      rethrow;
    }
  }

  /// Delete a location
  Future<void> deleteLocation(String locationId) async {
    final repo = ref.read(providerLocationsRepositoryProvider);
    try {
      await repo.deleteLocation(locationId);
      // Refresh after delete
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  /// Set location as primary
  Future<void> setPrimary(String locationId) async {
    final repo = ref.read(providerLocationsRepositoryProvider);
    try {
      await repo.setPrimary(locationId);
      // Refresh to get updated primary status
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  /// Toggle active status
  Future<void> setActive(String locationId, bool isActive) async {
    final repo = ref.read(providerLocationsRepositoryProvider);
    try {
      await repo.setActive(locationId, isActive);
      // Refresh to get updated status
      await refresh();
    } catch (e) {
      rethrow;
    }
  }
}

/// Provider for provider locations
final providerLocationsProvider =
    AsyncNotifierProvider<ProviderLocationsNotifier, List<ProviderLocation>>(() {
  return ProviderLocationsNotifier();
});
