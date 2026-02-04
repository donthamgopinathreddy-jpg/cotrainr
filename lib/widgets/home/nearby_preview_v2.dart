import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class NearbyPlace {
  final String id;
  final String name;
  final String category;
  final double rating;
  final double distance; // in km
  final bool isFavorite;
  final String? thumbnailUrl;
  final String? imageUrl; // Full background image for card

  NearbyPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    required this.distance,
    this.isFavorite = false,
    this.thumbnailUrl,
    this.imageUrl,
  });
}

class NearbyPreviewV2 extends StatefulWidget {
  final List<NearbyPlace> places;
  final List<String> categories;

  const NearbyPreviewV2({
    super.key,
    required this.places,
    this.categories = const ['All', 'Gyms', 'Yoga', 'Parks', 'CrossFit', 'Pilates'],
  });

  @override
  State<NearbyPreviewV2> createState() => _NearbyPreviewV2State();
}

class _NearbyPreviewV2State extends State<NearbyPreviewV2> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final filteredPlaces = _selectedCategory == 'All'
        ? widget.places
        : widget.places
            .where((p) => p.category == _selectedCategory)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with location icon and title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: AppColors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Nearby Places',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Category filters - horizontal scrollable
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.categories.length,
            itemBuilder: (context, index) {
              final category = widget.categories[index];
              final isActive = _selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _CategoryChip(
                  label: category,
                  isActive: isActive,
                  onTap: () {
                    setState(() => _selectedCategory = category);
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Place cards - vertical list
        ...filteredPlaces.map((place) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _NearbyPlaceCard(place: place),
          );
        }),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'gyms':
        return Icons.fitness_center_rounded;
      case 'yoga':
        return Icons.self_improvement_rounded;
      case 'parks':
        return Icons.park_rounded;
      case 'crossfit':
        return Icons.sports_gymnastics_rounded;
      case 'pilates':
        return Icons.accessibility_new_rounded;
      default:
        return Icons.business_rounded;
    }
  }

  Color _getIconColorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'gyms':
        return Colors.amber;
      case 'yoga':
        return Colors.amber;
      case 'parks':
        return Colors.green;
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.orange : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIconForCategory(label),
                size: 18,
                color: isActive ? Colors.white : _getIconColorForCategory(label),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyPlaceCard extends StatelessWidget {
  final NearbyPlace place;

  const _NearbyPlaceCard({required this.place});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            if (place.imageUrl != null)
              Image.network(
                place.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
              )
            else
              _buildPlaceholderImage(),
            // Dark overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Location pin icon
                  Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  // Name and distance
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          place.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${place.distance.toStringAsFixed(1)} km away',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Navigation icon
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // TODO: Open directions
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    // Return a gradient placeholder based on category
    Color gradientColor;
    switch (place.category.toLowerCase()) {
      case 'gyms':
        gradientColor = Colors.blue.shade800;
        break;
      case 'yoga':
        gradientColor = Colors.purple.shade800;
        break;
      case 'parks':
        gradientColor = Colors.green.shade800;
        break;
      default:
        gradientColor = Colors.grey.shade800;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradientColor,
            gradientColor.withValues(alpha: 0.7),
          ],
        ),
      ),
    );
  }
}
