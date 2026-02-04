import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum FilterType { trainers, nutritionists, centers }

class DiscoverFilterSheet extends StatefulWidget {
  final FilterType filterType;
  final Color accentColor;
  final LinearGradient gradient;
  final RangeValues initialDistance;
  final String? initialMinRating;
  final Set<String> initialSelectedCategories;
  final Function(RangeValues, String?, Set<String>) onApply;
  final VoidCallback onReset;

  const DiscoverFilterSheet({
    super.key,
    required this.filterType,
    required this.accentColor,
    required this.gradient,
    this.initialDistance = const RangeValues(0, 50),
    this.initialMinRating,
    this.initialSelectedCategories = const {},
    required this.onApply,
    required this.onReset,
  });

  @override
  State<DiscoverFilterSheet> createState() => _DiscoverFilterSheetState();
}

class _DiscoverFilterSheetState extends State<DiscoverFilterSheet> {
  late RangeValues _distance;
  String? _minRating;
  late Set<String> _selectedCategories;

  List<String> get _ratingOptions => ['Any', '3.5+', '4+', '4.5+'];
  
  List<String> get _categories {
    switch (widget.filterType) {
      case FilterType.trainers:
        return ['Strength', 'Yoga', 'Cardio', 'Boxing', 'HIIT'];
      case FilterType.nutritionists:
        return ['Weight Loss', 'Sports Nutrition', 'Clinical', 'Plant-Based', 'Lifestyle'];
      case FilterType.centers:
        return ['Gym', 'Yoga Studio', 'CrossFit', 'Pilates', 'Martial Arts'];
    }
  }

  String get _title {
    switch (widget.filterType) {
      case FilterType.trainers:
        return 'Filter Trainers';
      case FilterType.nutritionists:
        return 'Filter Nutritionists';
      case FilterType.centers:
        return 'Filter Centers';
    }
  }

  @override
  void initState() {
    super.initState();
    _distance = widget.initialDistance;
    _minRating = widget.initialMinRating ?? 'Any';
    _selectedCategories = Set.from(widget.initialSelectedCategories);
  }

  String _getDistanceText() {
    if (_distance.start == 0 && _distance.end >= 50) {
      return '0 - 50+ km';
    }
    return '${_distance.start.toInt()} - ${_distance.end.toInt()} km';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Header with title and close button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: cs.onSurface.withValues(alpha: 0.7),
                    size: 24,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Distance Filter Section
                  _buildDistanceSection(cs),
                  const SizedBox(height: 24),
                  // Minimum Rating Filter Section
                  _buildRatingSection(cs),
                  const SizedBox(height: 24),
                  // Categories Filter Section
                  _buildCategoriesSection(cs),
                  const SizedBox(height: 24),
                  // Action Buttons
                  _buildActionButtons(cs),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceSection(ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: widget.accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Distance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              _getDistanceText(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Range Slider with gradient
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: widget.accentColor, // Will be overridden by gradient track
            inactiveTrackColor: isDark 
                ? cs.outline.withValues(alpha: 0.3)
                : Colors.grey.shade300,
            rangeThumbShape: _CustomRangeThumbShape(gradient: widget.gradient),
            rangeTrackShape: _GradientRangeTrackShape(gradient: widget.gradient),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: RangeSlider(
            values: _distance,
            min: 0,
            max: 50,
            divisions: 50,
            onChanged: (values) {
              HapticFeedback.selectionClick();
              setState(() => _distance = values);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection(ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_outline_rounded,
                color: widget.accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Minimum Rating',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              _minRating ?? 'Any',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _ratingOptions.map((rating) {
            final isSelected = (_minRating ?? 'Any') == rating;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _minRating = rating == 'Any' ? null : rating;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected ? widget.gradient : null,
                  color: isSelected ? null : cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected 
                        ? Colors.transparent 
                        : (isDark ? cs.outline.withValues(alpha: 0.3) : Colors.grey.shade300),
                    width: 1,
                  ),
                ),
                child: Text(
                  rating,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : cs.onSurface,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoriesSection(ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _categories.map((category) {
            final isSelected = _selectedCategories.contains(category);
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  if (isSelected) {
                    _selectedCategories.remove(category);
                  } else {
                    _selectedCategories.add(category);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected ? widget.gradient : null,
                  color: isSelected 
                      ? null 
                      : (isDark ? cs.surfaceContainerHighest : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected 
                        ? Colors.transparent 
                        : (isDark ? cs.outline.withValues(alpha: 0.3) : Colors.grey.shade300),
                    width: 1,
                  ),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : cs.onSurface,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Apply Filters Button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onApply(_distance, _minRating, _selectedCategories);
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: widget.gradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  'Apply Filters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Reset Button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _distance = const RangeValues(0, 50);
                _minRating = null;
                _selectedCategories = {};
              });
              widget.onReset();
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark 
                      ? cs.outline.withValues(alpha: 0.3)
                      : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  'Reset',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientRangeTrackShape extends RangeSliderTrackShape {
  final LinearGradient gradient;
  const _GradientRangeTrackShape({required this.gradient});

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 2.0;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset startThumbCenter,
    required Offset endThumbCenter,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 2.0;
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    // Draw inactive track
    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.grey.shade300;
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, Radius.circular(trackHeight / 2)),
      inactivePaint,
    );

    // Draw active track with gradient between thumbs
    if (startThumbCenter.dx < endThumbCenter.dx) {
      final activeRect = Rect.fromLTRB(
        startThumbCenter.dx,
        trackRect.top,
        endThumbCenter.dx,
        trackRect.bottom,
      );
      final activePaint = Paint()
        ..shader = gradient.createShader(activeRect);
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, Radius.circular(trackHeight / 2)),
        activePaint,
      );
    }
  }
}

class _CustomRangeThumbShape extends RangeSliderThumbShape {
  final LinearGradient gradient;
  const _CustomRangeThumbShape({required this.gradient});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(20, 20);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = true,
    bool isOnTop = false,
    bool isPressed = false,
    required SliderThemeData sliderTheme,
    TextDirection textDirection = TextDirection.ltr,
    Thumb thumb = Thumb.start,
  }) {
    final Canvas canvas = context.canvas;
    
    // Draw thumb with gradient
    final rect = Rect.fromCircle(center: center, radius: 10);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    
    // Left thumb (hollow)
    if (thumb == Thumb.start) {
      // Outer circle with gradient
      canvas.drawCircle(center, 10, paint);
      // Inner white circle
      final innerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 7, innerPaint);
    } else {
      // Right thumb (solid with gradient)
      canvas.drawCircle(center, 10, paint);
    }
  }
}
