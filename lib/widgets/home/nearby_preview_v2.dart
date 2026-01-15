import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import '../common/glass_card.dart';
import '../common/pill_chip.dart';

class NearbyPlace {
  final String id;
  final String name;
  final String category;
  final double rating;
  final double distance; // in km
  final bool isFavorite;
  final String? thumbnailUrl;

  NearbyPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    required this.distance,
    this.isFavorite = false,
    this.thumbnailUrl,
  });
}

class NearbyPreviewV2 extends StatefulWidget {
  final List<NearbyPlace> places;
  final List<String> categories;

  const NearbyPreviewV2({
    super.key,
    required this.places,
    this.categories = const ['All', 'Gyms', 'Yoga', 'CrossFit', 'Pilates'],
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
        Padding(
          padding: EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
          child: Text(
            'Nearby',
            style: TextStyle(
              fontSize: DesignTokens.fontSizeH2,
              fontWeight: FontWeight.w700,
              color: DesignTokens.textPrimary,
            ),
          ),
        ),
        SizedBox(height: DesignTokens.spacing12),
        // Chips row scroll
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
            itemCount: widget.categories.length,
            itemBuilder: (context, index) {
              final category = widget.categories[index];
              final isActive = _selectedCategory == category;
              return Padding(
                padding: EdgeInsets.only(right: DesignTokens.spacing8),
                child: PillChip(
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
        SizedBox(height: DesignTokens.spacing12),
        // List cards
        ...filteredPlaces.take(3).map((place) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(
              milliseconds: 200 + (filteredPlaces.indexOf(place) * 50),
            ),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: _NearbyPlaceRow(place: place),
          );
        }),
      ],
    );
  }
}

class _NearbyPlaceRow extends StatelessWidget {
  final NearbyPlace place;

  const _NearbyPlaceRow({required this.place});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing16,
        vertical: 6,
      ),
      child: GlassCard(
        padding: EdgeInsets.all(DesignTokens.spacing16),
        onTap: null,
        child: Row(
          children: [
            // Left: Thumbnail rounded 16
            if (place.thumbnailUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(DesignTokens.radiusSecondary),
                child: Image.network(
                  place.thumbnailUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 56,
                    height: 56,
                    color: DesignTokens.surface,
                    child: Icon(
                      Icons.place,
                      color: DesignTokens.textSecondary,
                    ),
                  ),
                ),
              )
            else
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: DesignTokens.surface,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSecondary),
                ),
                child: Icon(
                  Icons.place,
                  color: DesignTokens.textSecondary,
                ),
              ),
            SizedBox(width: DesignTokens.spacing16),
            // Middle: name + rating + distance
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeBody,
                      fontWeight: FontWeight.w600,
                      color: DesignTokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: DesignTokens.spacing4),
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: DesignTokens.iconSizeList,
                        color: Colors.amber,
                      ),
                      SizedBox(width: DesignTokens.spacing4),
                      Text(
                        place.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeMeta,
                          color: DesignTokens.textSecondary,
                        ),
                      ),
                      SizedBox(width: DesignTokens.spacing8),
                      Icon(
                        Icons.location_on_outlined,
                        size: DesignTokens.iconSizeList,
                        color: DesignTokens.textSecondary,
                      ),
                      SizedBox(width: DesignTokens.spacing4),
                      Text(
                        '${place.distance.toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeMeta,
                          color: DesignTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Right: heart outline + nav arrow button
            IconButton(
              icon: Icon(
                place.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: place.isFavorite ? Colors.red : DesignTokens.textSecondary,
                size: DesignTokens.iconSizeTile,
              ),
              onPressed: () {
                // TODO: Toggle favorite
              },
            ),
            IconButton(
              icon: Icon(
                Icons.navigation,
                color: DesignTokens.textSecondary,
                size: DesignTokens.iconSizeTile,
              ),
              onPressed: () {
                // TODO: Open directions
              },
            ),
          ],
        ),
      ),
    );
  }
}



