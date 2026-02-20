import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/provider_location_model.dart';
import '../../repositories/provider_locations_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';

class NearbyPreviewV3 extends StatefulWidget {
  const NearbyPreviewV3({super.key});

  @override
  State<NearbyPreviewV3> createState() => _NearbyPreviewV3State();
}

class _NearbyPreviewV3State extends State<NearbyPreviewV3> {
  String _selectedFilter = 'All';
  List<_NearbyPlace> _allPlaces = [];
  bool _isLoading = true;
  String? _errorMessage;
  Position? _userPosition;
  final ProviderLocationsRepository _repo = ProviderLocationsRepository();

  final List<_FilterChip> _allChips = [
    _FilterChip('All', Icons.business, 'All'),
    _FilterChip('Gyms', Icons.fitness_center, 'Gyms'),
    _FilterChip('Yoga', Icons.self_improvement, 'Yoga'),
    _FilterChip('Parks', Icons.park, 'Parks'),
  ];

  @override
  void initState() {
    super.initState();
    _loadNearbyPlaces();
  }

  Future<void> _loadNearbyPlaces() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get user's current location
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled';
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() {
          _errorMessage = 'Enable location to discover nearby providers';
          _isLoading = false;
        });
        return;
      }

      _userPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Map filter to location types (canonical repo method)
      List<LocationType>? locationTypes;
      if (_selectedFilter == 'Gyms') {
        locationTypes = [LocationType.gym];
      } else if (_selectedFilter == 'Yoga') {
        locationTypes = [LocationType.studio];
      } else if (_selectedFilter == 'Parks') {
        locationTypes = [LocationType.park];
      }
      // 'All' means null (no filter)

      final results = await _repo.fetchNearbyProviders(
        userLat: _userPosition!.latitude,
        userLng: _userPosition!.longitude,
        maxDistanceKm: 10.0,
        providerTypes: null,
        locationTypes: locationTypes,
      );

      final places = <_NearbyPlace>[];
      
      for (final result in results) {
        final displayName = result['display_name'] as String? ?? 'Unknown';
        final distanceKm = (result['distance_km'] as num?)?.toDouble() ?? 0.0;
        final locationType = result['location_type'] as String? ?? 'other';
        
        // Format distance
        String distanceStr;
        if (distanceKm < 1.0) {
          distanceStr = '${(distanceKm * 1000).toStringAsFixed(0)} m';
        } else {
          distanceStr = '${distanceKm.toStringAsFixed(1)} km';
        }
        
        // Map location type to category
        String category;
        if (locationType == 'gym') {
          category = 'Gyms';
        } else if (locationType == 'studio') {
          category = 'Yoga';
        } else if (locationType == 'park') {
          category = 'Parks';
        } else {
          category = 'All';
        }
        
        places.add(_NearbyPlace(displayName, distanceStr, category));
      }

      if (mounted) {
        setState(() {
          _allPlaces = places;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading nearby places: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load nearby places';
          _isLoading = false;
        });
      }
    }
  }

  List<_NearbyPlace> get _filteredPlaces {
    if (_selectedFilter == 'All') {
      return _allPlaces;
    }
    return _allPlaces.where((place) => place.category == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.black.withOpacity(0.85) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => AppColors.stepsGradient.createShader(bounds),
              child: Icon(
                Icons.location_on_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                gradient: AppColors.stepsGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Nearby Places',
              style: GoogleFonts.montserrat(
                fontSize: DesignTokens.fontSizeSection,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _allChips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final chip = _allChips[index];
              final isActive = _selectedFilter == chip.value;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedFilter = chip.value;
                  });
                  // Reload places when filter changes
                  _loadNearbyPlaces();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? AppColors.stepsGradient
                        : null,
                    color: null,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        chip.icon,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        chip.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isActive ? Colors.white : cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _isLoading
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(
                    color: AppColors.orange,
                  ),
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_off_rounded,
                            color: cs.onSurfaceVariant,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enable location in settings to discover nearby trainers and nutritionists',
                            style: TextStyle(
                              color: cs.onSurfaceVariant.withOpacity(0.8),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: _loadNearbyPlaces,
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Retry'),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  await Geolocator.openAppSettings();
                                },
                                icon: const Icon(Icons.settings_rounded, size: 18),
                                label: const Text('Settings'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : _filteredPlaces.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_searching_rounded,
                                size: 40,
                                color: cs.onSurfaceVariant.withOpacity(0.6),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No providers near you',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Try expanding the search radius or check back later',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: _filteredPlaces.map((place) {
            final textColor = isDark ? Colors.white : Colors.black;
            return Container(
              height: 90,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: DesignTokens.cardShadowOf(context),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppColors.stepsGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${place.distance} away',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.stepsGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FilterChip {
  final String label;
  final IconData icon;
  final String value;

  _FilterChip(this.label, this.icon, this.value);
}

class _NearbyPlace {
  final String name;
  final String distance;
  final String category;

  _NearbyPlace(this.name, this.distance, this.category);
}
