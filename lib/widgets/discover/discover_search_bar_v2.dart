import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';

class DiscoverSearchBarV2 extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onFilterTap;
  final String? selectedSort;
  final double? maxDistance;
  final double? minRating;

  const DiscoverSearchBarV2({
    super.key,
    required this.controller,
    this.onSearchChanged,
    this.onFilterTap,
    this.selectedSort,
    this.maxDistance,
    this.minRating,
  });

  @override
  State<DiscoverSearchBarV2> createState() => _DiscoverSearchBarV2State();
}

class _DiscoverSearchBarV2State extends State<DiscoverSearchBarV2>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isFocused = false;
  late AnimationController _expandController;
  late AnimationController _focusController;
  late Animation<double> _expandAnimation;
  late Animation<double> _focusAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _focusController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    _focusAnimation = CurvedAnimation(
      parent: _focusController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    _focusController.dispose();
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
        // Modern Search Bar with Focus Animation
        AnimatedBuilder(
          animation: _focusAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: DesignTokens.surfaceOf(context),
                borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                border: Border.all(
                  color: _isFocused
                      ? DesignTokens.accentOrange
                      : DesignTokens.borderColorOf(context),
                  width: 1 + (_focusAnimation.value * 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.2 + (_focusAnimation.value * 0.15),
                    ),
                    blurRadius: 20 + (_focusAnimation.value * 10),
                    offset: Offset(0, 8 + (_focusAnimation.value * 4)),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      onChanged: widget.onSearchChanged,
                      onTap: () {
                        setState(() => _isFocused = true);
                        _focusController.forward();
                      },
                      onSubmitted: (_) {
                        setState(() => _isFocused = false);
                        _focusController.reverse();
                      },
                      style: TextStyle(
                        color: DesignTokens.textPrimaryOf(context),
                        fontSize: DesignTokens.fontSizeBody,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by name, specialty, location...',
                        hintStyle: TextStyle(
                          color: DesignTokens.textSecondaryOf(context),
                          fontSize: DesignTokens.fontSizeBody,
                        ),
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: DesignTokens.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.search_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.spacing16,
                          vertical: DesignTokens.spacing16,
                        ),
                      ),
                    ),
                  ),
                  // Modern Filter Button
                  Container(
                    margin: const EdgeInsets.only(right: DesignTokens.spacing8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _toggleFilter,
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: _hasActiveFilters()
                                ? DesignTokens.primaryGradient
                                : null,
                            color: _hasActiveFilters() ? null : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              Icon(
                                Icons.tune_rounded,
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
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: DesignTokens.surfaceOf(context),
                                        width: 2,
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
            );
          },
        ),

        // Expandable Filter Section
        SizeTransition(
          sizeFactor: _expandAnimation,
          axisAlignment: -1.0,
          child: Container(
            margin: const EdgeInsets.only(top: DesignTokens.spacing12),
            padding: const EdgeInsets.all(DesignTokens.spacing16),
            decoration: BoxDecoration(
              color: DesignTokens.surfaceOf(context),
              borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
              boxShadow: DesignTokens.cardShadowOf(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.filter_alt_rounded,
                      size: 18,
                      color: DesignTokens.accentOrange,
                    ),
                    const SizedBox(width: DesignTokens.spacing8),
                    Text(
                      'Quick Filters',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeBody,
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.textPrimaryOf(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.spacing16),
                Wrap(
                  spacing: DesignTokens.spacing8,
                  runSpacing: DesignTokens.spacing8,
                  children: [
                    _FilterChipV2(
                      label: 'Distance',
                      icon: Icons.near_me_rounded,
                      isActive: widget.selectedSort == 'Distance',
                    ),
                    _FilterChipV2(
                      label: 'Rating',
                      icon: Icons.star_rounded,
                      isActive: widget.selectedSort == 'Rating',
                    ),
                    _FilterChipV2(
                      label: 'Verified',
                      icon: Icons.verified_rounded,
                      isActive: false,
                    ),
                    if (widget.maxDistance != null && widget.maxDistance! < 50)
                      _FilterChipV2(
                        label: '${widget.maxDistance!.toStringAsFixed(0)} km',
                        icon: Icons.location_on_rounded,
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

class _FilterChipV2 extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isActive;

  const _FilterChipV2({
    required this.label,
    required this.icon,
    this.isActive = false,
  });

  @override
  State<_FilterChipV2> createState() => _FilterChipV2State();
}

class _FilterChipV2State extends State<_FilterChipV2>
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing16,
            vertical: DesignTokens.spacing12,
          ),
          decoration: BoxDecoration(
            gradient: widget.isActive ? DesignTokens.primaryGradient : null,
            color: widget.isActive ? null : DesignTokens.surfaceOf(context),
            borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
            border: Border.all(
              color: widget.isActive
                  ? Colors.transparent
                  : DesignTokens.borderColorOf(context),
              width: 1,
            ),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: DesignTokens.accentOrange.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isActive
                    ? Colors.white
                    : DesignTokens.textSecondaryOf(context),
              ),
              const SizedBox(width: DesignTokens.spacing8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeMeta,
                  fontWeight: FontWeight.w700,
                  color: widget.isActive
                      ? Colors.white
                      : DesignTokens.textPrimaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

