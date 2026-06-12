import 'dart:math' as math;

/// Static fitness facility data for Home Nearby Fitness (not trainers).
class FitnessPlace {
  final String id;
  final String name;
  final String category;
  final double lat;
  final double lng;
  final double rating;
  final bool isOpen;

  const FitnessPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.isOpen,
  });
}

/// Facility-only places — trainers/nutritionists belong in Discover.
const List<FitnessPlace> kNearbyFitnessPlaces = [
  FitnessPlace(
    id: 'gym-1',
    name: 'Power Gym',
    category: 'Gyms',
    lat: 17.3920,
    lng: 78.4810,
    rating: 4.7,
    isOpen: true,
  ),
  FitnessPlace(
    id: 'gym-2',
    name: 'Iron Forge Fitness',
    category: 'Gyms',
    lat: 17.3780,
    lng: 78.4920,
    rating: 4.5,
    isOpen: true,
  ),
  FitnessPlace(
    id: 'yoga-1',
    name: 'Zen Yoga Studio',
    category: 'Yoga',
    lat: 17.3865,
    lng: 78.4785,
    rating: 4.8,
    isOpen: true,
  ),
  FitnessPlace(
    id: 'park-1',
    name: 'KBR National Park',
    category: 'Parks',
    lat: 17.4010,
    lng: 78.4690,
    rating: 4.6,
    isOpen: true,
  ),
  FitnessPlace(
    id: 'boxing-1',
    name: 'Strike Boxing Club',
    category: 'Boxing',
    lat: 17.3830,
    lng: 78.4880,
    rating: 4.4,
    isOpen: false,
  ),
  FitnessPlace(
    id: 'running-1',
    name: 'Tank Bund Running Track',
    category: 'Running',
    lat: 17.4230,
    lng: 78.4740,
    rating: 4.3,
    isOpen: true,
  ),
  FitnessPlace(
    id: 'wellness-1',
    name: 'Aura Wellness Center',
    category: 'Wellness',
    lat: 17.3900,
    lng: 78.4950,
    rating: 4.6,
    isOpen: true,
  ),
  FitnessPlace(
    id: 'swim-1',
    name: 'AquaFit Swimming Pool',
    category: 'Swimming',
    lat: 17.3750,
    lng: 78.4800,
    rating: 4.2,
    isOpen: true,
  ),
  FitnessPlace(
    id: 'sports-1',
    name: 'City Sports Arena',
    category: 'Sports',
    lat: 17.3960,
    lng: 78.5010,
    rating: 4.5,
    isOpen: true,
  ),
  FitnessPlace(
    id: 'physio-1',
    name: 'MoveWell Physio Clinic',
    category: 'Physio',
    lat: 17.3880,
    lng: 78.4840,
    rating: 4.9,
    isOpen: true,
  ),
  FitnessPlace(
    id: 'yoga-2',
    name: 'Sunrise Pilates',
    category: 'Yoga',
    lat: 17.3810,
    lng: 78.4760,
    rating: 4.5,
    isOpen: true,
  ),
  FitnessPlace(
    id: 'park-2',
    name: 'Necklace Road Park',
    category: 'Parks',
    lat: 17.4150,
    lng: 78.4710,
    rating: 4.4,
    isOpen: true,
  ),
];

class NearbyFitnessResult {
  final FitnessPlace place;
  final double distanceKm;

  const NearbyFitnessResult({required this.place, required this.distanceKm});
}

List<NearbyFitnessResult> nearbyFitnessPlaces({
  required double userLat,
  required double userLng,
  String categoryFilter = 'All',
  double maxDistanceKm = 15,
}) {
  final results = <NearbyFitnessResult>[];

  for (final place in kNearbyFitnessPlaces) {
    if (categoryFilter != 'All' && place.category != categoryFilter) continue;

    final km = _haversineKm(userLat, userLng, place.lat, place.lng);
    if (km <= maxDistanceKm) {
      results.add(NearbyFitnessResult(place: place, distanceKm: km));
    }
  }

  results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  return results;
}

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLng = _deg2rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

double _deg2rad(double deg) => deg * math.pi / 180;

String formatFitnessDistance(double km) {
  if (km < 1.0) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1)} km';
}
