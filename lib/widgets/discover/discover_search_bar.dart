import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';

class DiscoverSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onFilterTap;
  final String? selectedSort;
  final double? maxDistance;
  final double? minRating;

  const DiscoverSearchBar({
    super.key,
    required this.controller,
    this.onSearchChanged,
    this.onFilterTap,
    this.selectedSort,
    this.maxDistance,
    this.minRating,
  });

  @override
  State<DiscoverSearchBar> createState() => _DiscoverSearchBarState();
}

class _DiscoverSearchBarState extends State<DiscoverSearchBar>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleFilter() {
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
    widget.onFilterTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main Search Bar
        Container(
          decoration: BoxDecoration(
            color: DesignTokens.surface,
            borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
            boxShadow: DesignTokens.cardShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  onChanged: widget.onSearchChanged,
                  style: TextStyle(
                    color: DesignTokens.textPrimary,
                    fontSize: DesignTokens.fontSizeBody,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search trainers, nutritionists, centers...',
                    hintStyle: TextStyle(
                      color: DesignTokens.textSecondary,
                      fontSize: DesignTokens.fontSizeBody,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: DesignTokens.textSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spacing16,
                      vertical: DesignTokens.spacing16,
                    ),
                  ),
                ),
              ),
              // Filter Button with Badge
              Container(
                margin: const EdgeInsets.only(right: DesignTokens.spacing8),
                decoration: BoxDecoration(
                  gradient: _hasActiveFilters()
                      ? DesignTokens.primaryGradient
                      : null,
                  shape: BoxShape.circle,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleFilter,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: Stack(
                        children: [
                          Icon(
                            Icons.tune,
                            color: _hasActiveFilters()
                                ? Colors.white
                                : DesignTokens.accentOrange,
                            size: 24,
                          ),
                          if (_hasActiveFilters())
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: DesignTokens.surface,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Expandable Filter Section
        SizeTransition(
          sizeFactor: _expandAnimation,
          axisAlignment: -1.0,
          child: Container(
            margin: const EdgeInsets.only(top: DesignTokens.spacing12),
            padding: const EdgeInsets.all(DesignTokens.spacing16),
            decoration: BoxDecoration(
              color: DesignTokens.surface,
              borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
              boxShadow: DesignTokens.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Filter Chips
                Text(
                  'Quick Filters',
                  style: TextStyle(
                    fontSize: DesignTokens.fontSizeBody,
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: DesignTokens.spacing12),
                Wrap(
                  spacing: DesignTokens.spacing8,
                  runSpacing: DesignTokens.spacing8,
                  children: [
                    _FilterChip(
                      label: 'Distance',
                      icon: Icons.location_on,
                      isActive: widget.selectedSort == 'Distance',
                    ),
                    _FilterChip(
                      label: 'Rating',
                      icon: Icons.star,
                      isActive: widget.selectedSort == 'Rating',
                    ),
                    _FilterChip(
                      label: 'Verified',
                      icon: Icons.verified,
                      isActive: false,
                    ),
                    if (widget.maxDistance != null && widget.maxDistance! < 50)
                      _FilterChip(
                        label: '${widget.maxDistance!.toStringAsFixed(0)} km',
                        icon: Icons.near_me,
                        isActive: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _hasActiveFilters() {
    return widget.selectedSort != null ||
        (widget.maxDistance != null && widget.maxDistance! < 50) ||
        (widget.minRating != null && widget.minRating! > 0);
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isActive;

  const _FilterChip({
    required this.label,
    required this.icon,
    this.isActive = false,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing12,
            vertical: DesignTokens.spacing8,
          ),
          decoration: BoxDecoration(
            gradient: widget.isActive ? DesignTokens.primaryGradient : null,
            color: widget.isActive ? null : DesignTokens.surface,
            borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
            border: Border.all(
              color: widget.isActive
                  ? Colors.transparent
                  : DesignTokens.borderColor,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isActive
                    ? Colors.white
                    : DesignTokens.textSecondary,
              ),
              const SizedBox(width: DesignTokens.spacing8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeMeta,
                  fontWeight: FontWeight.w600,
                  color: widget.isActive
                      ? Colors.white
                      : DesignTokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
