import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';

class NearbyPreviewV3 extends StatefulWidget {
  const NearbyPreviewV3({super.key});

  @override
  State<NearbyPreviewV3> createState() => _NearbyPreviewV3State();
}

class _NearbyPreviewV3State extends State<NearbyPreviewV3> {
  String _selectedFilter = 'All';

  final List<_FilterChip> _allChips = [
    _FilterChip('All', Icons.business, 'All'),
    _FilterChip('Gyms', Icons.fitness_center, 'Gyms'),
    _FilterChip('Yoga', Icons.self_improvement, 'Yoga'),
    _FilterChip('Parks', Icons.park, 'Parks'),
  ];

  final List<_NearbyPlace> _allPlaces = [
    _NearbyPlace('Gold\'s Gym', '0.8 km', 'Gyms'),
    _NearbyPlace('The Yoga Institute', '1.2 km', 'Yoga'),
    _NearbyPlace('Cult.fit Center', '1.5 km', 'Gyms'),
    _NearbyPlace('Anytime Fitness', '2.1 km', 'Gyms'),
    _NearbyPlace('Talwalkars Gym', '2.5 km', 'Gyms'),
    _NearbyPlace('Central Park', '3.1 km', 'Parks'),
  ];

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
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.orange.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: AppColors.orange,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Nearby Places',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeSection,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
        Column(
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
