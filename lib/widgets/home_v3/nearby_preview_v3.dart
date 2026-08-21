import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/nearby_fitness_places_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../theme/text_styles.dart';
import '../../widgets/common/pressable_card.dart';
import '../../widgets/common/shimmer_skeleton.dart';
import 'home_premium_theme.dart';

class NearbyPreviewV3 extends StatefulWidget {
  const NearbyPreviewV3({super.key});

  @override
  State<NearbyPreviewV3> createState() => _NearbyPreviewV3State();
}

class _NearbyPreviewV3State extends State<NearbyPreviewV3> {
  String _selectedFilter = 'All';
  List<NearbyFitnessResult> _results = [];
  bool _isLoading = true;
  _NearbyFitnessState _state = _NearbyFitnessState.loading;
  LocationPermission? _permission;

  static const _categories = [
    ('All', Icons.apps_rounded),
    ('Gyms', Icons.fitness_center_rounded),
    ('Yoga', Icons.self_improvement_rounded),
    ('Parks', Icons.park_rounded),
    ('Boxing', Icons.sports_mma_rounded),
    ('Running', Icons.directions_run_rounded),
    ('Wellness', Icons.spa_rounded),
    ('Swimming', Icons.pool_rounded),
    ('Sports', Icons.sports_soccer_rounded),
    ('Physio', Icons.healing_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _state = _NearbyFitnessState.loading;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        setState(() {
          _state = _NearbyFitnessState.locationDisabled;
          _isLoading = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      _permission = permission;

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() {
          _state = _NearbyFitnessState.permissionDenied;
          _isLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final results = nearbyFitnessPlaces(
        userLat: position.latitude,
        userLng: position.longitude,
        categoryFilter: _selectedFilter,
      );

      if (!mounted) return;
      setState(() {
        _results = results;
        _state = results.isEmpty
            ? _NearbyFitnessState.empty
            : _NearbyFitnessState.loaded;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('NearbyFitness load error: $e');
      if (!mounted) return;
      setState(() {
        _state = _NearbyFitnessState.error;
        _isLoading = false;
      });
    }
  }

  void _onFilterTap(String filter) {
    if (_selectedFilter == filter) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedFilter = filter);
    if (_state == _NearbyFitnessState.loaded ||
        _state == _NearbyFitnessState.empty) {
      _loadPlaces();
    }
  }

  Future<void> _enableLocation() async {
    if (_permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }
    await Geolocator.requestPermission();
    await _loadPlaces();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.stepsGradient.createShader(bounds),
              child: const Icon(
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nearby Fitness',
                    style: AppTextStyles.sectionTitle(context, color: cs.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Find gyms, parks and wellness spots around you.',
                    style: TextStyle(
                      fontSize: 12,
                      color: HomePremiumTheme.secondaryText(!isDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: (12 * 2 + 14 * MediaQuery.textScalerOf(context).scale(1.0))
              .clamp(38.0, 60.0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final chip = _categories[index];
              final isActive = _selectedFilter == chip.$1;
              return GestureDetector(
                onTap: () => _onFilterTap(chip.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isActive ? AppColors.stepsGradient : null,
                    color: isActive
                        ? null
                        : (isDark
                            ? HomePremiumTheme.darkCard
                            : HomePremiumTheme.lightCreamCard),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isActive
                          ? Colors.transparent
                          : cs.onSurface.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        chip.$2,
                        size: 14,
                        color: isActive ? Colors.white : cs.onSurface,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        chip.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
        _buildBody(context, isDark),
      ],
    );
  }

  Widget _buildBody(BuildContext context, bool isDark) {
    if (_isLoading) {
      return SizedBox(
        height: 118,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, _) => const ShimmerHorizontalCard(width: 188, height: 108),
        ),
      );
    }

    switch (_state) {
      case _NearbyFitnessState.locationDisabled:
      case _NearbyFitnessState.permissionDenied:
        return _locationState(
          isDark: isDark,
          showSettings: _state == _NearbyFitnessState.permissionDenied ||
              _permission == LocationPermission.deniedForever,
        );
      case _NearbyFitnessState.error:
        return _retryState(isDark);
      case _NearbyFitnessState.empty:
        return _emptyState(isDark);
      case _NearbyFitnessState.loaded:
        return _resultsRow(isDark);
      case _NearbyFitnessState.loading:
        return const SizedBox.shrink();
    }
  }

  Widget _resultsRow(bool isDark) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _results.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = _results[index];
          return _FitnessPlaceCard(result: item, isDark: isDark);
        },
      ),
    );
  }

  Widget _locationState({required bool isDark, required bool showSettings}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? HomePremiumTheme.darkCard : HomePremiumTheme.lightCreamCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: DesignTokens.cardShadowOf(context),
      ),
      child: Column(
        children: [
          Icon(
            Icons.location_disabled_rounded,
            size: 36,
            color: HomePremiumTheme.secondaryText(!isDark),
          ),
          const SizedBox(height: 10),
          Text(
            'Enable location to explore nearby fitness',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: HomePremiumTheme.primaryText(!isDark),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Find gyms, yoga studios, parks, wellness centers and running spots near you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: HomePremiumTheme.secondaryText(!isDark),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _enableLocation,
                icon: const Icon(Icons.location_on_rounded, size: 18),
                label: Text(showSettings ? 'Open Settings' : 'Enable Location'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3ED598),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _loadPlaces,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _retryState(bool isDark) {
    return _friendlyState(
      isDark: isDark,
      icon: Icons.wifi_off_rounded,
      title: 'Could not load nearby fitness',
      description: 'Please try again in a moment.',
      action: _loadPlaces,
      actionLabel: 'Retry',
    );
  }

  Widget _emptyState(bool isDark) {
    return _friendlyState(
      isDark: isDark,
      icon: Icons.search_off_rounded,
      title: 'No fitness spots found nearby',
      description:
          'Try changing category or increasing distance.',
      action: _loadPlaces,
      actionLabel: 'Retry',
    );
  }

  Widget _friendlyState({
    required bool isDark,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback action,
    required String actionLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? HomePremiumTheme.darkCard : HomePremiumTheme.lightCreamCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: HomePremiumTheme.secondaryText(!isDark)),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: HomePremiumTheme.primaryText(!isDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: HomePremiumTheme.secondaryText(!isDark),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: action,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

enum _NearbyFitnessState {
  loading,
  loaded,
  empty,
  locationDisabled,
  permissionDenied,
  error,
}

class _FitnessPlaceCard extends StatelessWidget {
  final NearbyFitnessResult result;
  final bool isDark;

  const _FitnessPlaceCard({required this.result, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final place = result.place;
    final distance = formatFitnessDistance(result.distanceKm);
    final status = place.isOpen ? 'Open now' : 'Closed';

    return PressableCard(
      borderRadius: 20,
      pressScale: 0.99,
      enableHaptic: false,
      onTap: () {},
      child: Container(
      width: 188,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? HomePremiumTheme.darkCard : HomePremiumTheme.lightCreamCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: DesignTokens.cardShadowOf(context),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: AppColors.stepsGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _categoryIcon(place.category),
                  size: 15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: HomePremiumTheme.primaryText(!isDark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${place.category} · $distance',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: HomePremiumTheme.secondaryText(!isDark),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5B942)),
              const SizedBox(width: 2),
              Text(
                place.rating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: HomePremiumTheme.primaryText(!isDark),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '· $status',
                style: TextStyle(
                  fontSize: 11,
                  color: place.isOpen
                      ? const Color(0xFF22C55E)
                      : HomePremiumTheme.secondaryText(!isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      'Gyms' => Icons.fitness_center_rounded,
      'Yoga' => Icons.self_improvement_rounded,
      'Parks' => Icons.park_rounded,
      'Boxing' => Icons.sports_mma_rounded,
      'Running' => Icons.directions_run_rounded,
      'Wellness' => Icons.spa_rounded,
      'Swimming' => Icons.pool_rounded,
      'Sports' => Icons.sports_soccer_rounded,
      'Physio' => Icons.healing_rounded,
      _ => Icons.place_rounded,
    };
  }
}
