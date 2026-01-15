import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';

class DiscoverFilterSheet extends StatefulWidget {
  final double minDistance;
  final double maxDistance;
  final String? minRating;
  final Set<String> selectedCategories;
  final Function(double, double, String?, Set<String>) onApply;
  final VoidCallback onReset;

  const DiscoverFilterSheet({
    super.key,
    required this.minDistance,
    required this.maxDistance,
    required this.minRating,
    required this.selectedCategories,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<DiscoverFilterSheet> createState() => _DiscoverFilterSheetState();
}

class _DiscoverFilterSheetState extends State<DiscoverFilterSheet>
    with SingleTickerProviderStateMixin {
  late RangeValues _distanceRange;
  String? _selectedRating;
  Set<String> _selectedCategories = {};
  late AnimationController _animationController;

  final List<String> _ratingOptions = ['Any', '3.5+', '4+', '4.5+'];
  final List<String> _categoryOptions = [
    'Strength',
    'Yoga',
    'Cardio',
    'Boxing',
    'HIIT',
    'Pilates',
    'CrossFit',
  ];

  @override
  void initState() {
    super.initState();
    _distanceRange = RangeValues(widget.minDistance, widget.maxDistance);
    _selectedRating = widget.minRating;
    _selectedCategories = Set.from(widget.selectedCategories);
    _animationController = AnimationController(
      duration: DesignTokens.animationMedium,
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getDistanceText() {
    if (_distanceRange.start == 0 && _distanceRange.end >= 50) {
      return '0 - 50+ km';
    }
    return '${_distanceRange.start.toInt()} - ${_distanceRange.end.toInt()} km';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surfaceOf(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusCard),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: DesignTokens.spacing12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: DesignTokens.textSecondaryOf(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Trainers',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeBody,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.textPrimaryOf(context),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: DesignTokens.textPrimaryOf(context),
                    size: 20,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(DesignTokens.spacing20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Distance Filter
                  _buildDistanceSection(),

                  const SizedBox(height: DesignTokens.spacing20),

                  // Minimum Rating Filter
                  _buildRatingSection(),

                  const SizedBox(height: DesignTokens.spacing20),

                  // Categories Filter
                  _buildCategoriesSection(),

                  const SizedBox(height: DesignTokens.spacing20),

                  // Action Buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              size: 14,
              color: DesignTokens.accentOrange,
            ),
            const SizedBox(width: DesignTokens.spacing8),
            Text(
              'Distance',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeMeta,
                fontWeight: FontWeight.w600,
                color: DesignTokens.textPrimaryOf(context),
              ),
            ),
            const Spacer(),
            Text(
              _getDistanceText(),
              style: TextStyle(
                fontSize: DesignTokens.fontSizeCaption,
                color: DesignTokens.textSecondaryOf(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.spacing12),
        // Modern Thin Slider (matching image design)
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2.5,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 10,
              pressedElevation: 0,
              elevation: 2,
            ),
            overlayShape: const RoundSliderOverlayShape(
              overlayRadius: 18,
            ),
            activeTrackColor: DesignTokens.accentOrange,
            inactiveTrackColor: DesignTokens.textSecondaryOf(context).withValues(alpha: 0.15),
            thumbColor: Colors.white,
            overlayColor: DesignTokens.accentOrange.withValues(alpha: 0.12),
            rangeThumbShape: const RoundRangeSliderThumbShape(
              enabledThumbRadius: 10,
              pressedElevation: 0,
              elevation: 2,
            ),
            rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
          ),
          child: RangeSlider(
            values: _distanceRange,
            min: 0,
            max: 50,
            divisions: 50,
            onChanged: (values) {
              HapticFeedback.selectionClick();
              setState(() {
                _distanceRange = values;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.star_rounded,
              size: 14,
              color: DesignTokens.accentOrange,
            ),
            const SizedBox(width: DesignTokens.spacing8),
            Text(
              'Minimum Rating',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeMeta,
                fontWeight: FontWeight.w600,
                color: DesignTokens.textPrimaryOf(context),
              ),
            ),
            const Spacer(),
            Text(
              _selectedRating ?? 'Any',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeCaption,
                color: DesignTokens.textSecondaryOf(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.spacing10),
        Wrap(
          spacing: DesignTokens.spacing6,
          runSpacing: DesignTokens.spacing6,
          children: _ratingOptions.map((rating) {
            final isSelected = _selectedRating == rating;
            return AnimatedContainer(
              duration: DesignTokens.animationFast,
              curve: Curves.easeOutCubic,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedRating = isSelected ? null : rating;
                  });
                },
                child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spacing14,
                      vertical: DesignTokens.spacing6,
                    ),
                  decoration: BoxDecoration(
                    gradient: isSelected ? DesignTokens.primaryGradient : null,
                    color: isSelected ? null : DesignTokens.surfaceOf(context),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : DesignTokens.borderColorOf(context),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    rating,
                    style: TextStyle(
                      fontSize: DesignTokens.fontSizeMeta,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : DesignTokens.textPrimaryOf(context),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: TextStyle(
            fontSize: DesignTokens.fontSizeMeta,
            fontWeight: FontWeight.w600,
            color: DesignTokens.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: DesignTokens.spacing10),
        SizedBox(
          height: 32,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categoryOptions.length,
            itemBuilder: (context, index) {
              final category = _categoryOptions[index];
              final isSelected = _selectedCategories.contains(category);
              return Padding(
                padding: EdgeInsets.only(
                  right: index < _categoryOptions.length - 1
                      ? DesignTokens.spacing8
                      : 0,
                ),
                child: AnimatedContainer(
                  duration: DesignTokens.animationFast,
                  curve: Curves.easeOutCubic,
                  child: GestureDetector(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spacing14,
                      vertical: DesignTokens.spacing6,
                    ),
                      decoration: BoxDecoration(
                        gradient: isSelected ? DesignTokens.primaryGradient : null,
                        color: isSelected ? null : DesignTokens.surfaceOf(context),
                        borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : DesignTokens.borderColorOf(context),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeMeta,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : DesignTokens.textPrimaryOf(context),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Apply Filters Button
        AnimatedContainer(
          duration: DesignTokens.animationMedium,
          curve: Curves.easeOutCubic,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: DesignTokens.primaryGradient,
            borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
            boxShadow: [
              BoxShadow(
                color: DesignTokens.accentOrange.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.onApply(
                  _distanceRange.start,
                  _distanceRange.end,
                  _selectedRating == 'Any' ? null : _selectedRating,
                  _selectedCategories,
                );
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: DesignTokens.spacing12,
                ),
                child: Center(
                  child: Text(
                    'Apply Filters',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: DesignTokens.fontSizeMeta,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.spacing10),
        // Reset Button
        AnimatedContainer(
          duration: DesignTokens.animationMedium,
          curve: Curves.easeOutCubic,
          width: double.infinity,
          decoration: BoxDecoration(
            color: DesignTokens.surfaceOf(context),
            borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
            border: Border.all(
              color: DesignTokens.borderColorOf(context),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _distanceRange = const RangeValues(0, 50);
                  _selectedRating = null;
                  _selectedCategories = {};
                });
                widget.onReset();
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: DesignTokens.spacing12,
                ),
                child: Center(
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      color: DesignTokens.textPrimaryOf(context),
                      fontSize: DesignTokens.fontSizeMeta,
                      fontWeight: FontWeight.w600,
                    ),
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
