import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import '../../theme/app_colors.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  int _selectedTabIndex = 0;
  bool _isSearchFocused = false;
  bool _isFilterPressed = false;
  bool _isLoading = false;

  // Filter state
  RangeValues _distance = const RangeValues(0, 50);
  String? _minRating;
  Set<String> _selectedCategories = {};

  // Mock data
  final List<DiscoverItem> _trainers = [];
  final List<DiscoverItem> _nutritionists = [];
  final List<DiscoverItem> _centers = [];

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    });
    _loadMockData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMockData() {
    _trainers.addAll([
      DiscoverItem(
        id: '1',
        name: 'Priya Sharma',
        subtitle: 'Strength & Conditioning Coach',
        rating: 4.9,
        reviews: 127,
        distance: 0.8,
        location: 'Andheri, Mumbai',
        isVerified: true,
        avatarUrl: null,
      ),
      DiscoverItem(
        id: '2',
        name: 'Rahul Verma',
        subtitle: 'Yoga & Mindfulness Instructor',
        rating: 4.8,
        reviews: 94,
        distance: 1.5,
        location: 'Koramangala, Bangalore',
        isVerified: true,
        avatarUrl: null,
      ),
      DiscoverItem(
        id: '3',
        name: 'Sneha Patel',
        subtitle: 'Certified Nutritionist',
        rating: 4.9,
        reviews: 156,
        distance: 3.2,
        location: 'Gurgaon, Delhi NCR',
        isVerified: true,
        avatarUrl: null,
      ),
    ]);

    _nutritionists.addAll([
      DiscoverItem(
        id: '4',
        name: 'Sneha Patel',
        subtitle: 'Certified Clinical Nutritionist',
        rating: 4.9,
        reviews: 156,
        distance: 2.1,
        location: 'Bandra, Mumbai',
        isVerified: true,
        avatarUrl: null,
      ),
      DiscoverItem(
        id: '5',
        name: 'Arjun Mehta',
        subtitle: 'Sports Nutrition Specialist',
        rating: 4.7,
        reviews: 89,
        distance: 4.5,
        location: 'Powai, Mumbai',
        isVerified: true,
        avatarUrl: null,
      ),
      DiscoverItem(
        id: '6',
        name: 'Kavya Rao',
        subtitle: 'Diet Planning Expert',
        rating: 4.8,
        reviews: 112,
        distance: 1.8,
        location: 'Indiranagar, Bangalore',
        isVerified: true,
        avatarUrl: null,
      ),
    ]);

    _centers.addAll([
      DiscoverItem(
        id: '7',
        name: 'FitZone Gym',
        subtitle: 'Premium Fitness Center',
        rating: 4.6,
        reviews: 248,
        distance: 0.6,
        location: 'Juhu, Mumbai',
        isVerified: true,
        avatarUrl: null,
      ),
      DiscoverItem(
        id: '8',
        name: 'Zen Yoga Studio',
        subtitle: 'Mind & Body Wellness',
        rating: 4.9,
        reviews: 178,
        distance: 2.3,
        location: 'Whitefield, Bangalore',
        isVerified: true,
        avatarUrl: null,
      ),
      DiscoverItem(
        id: '9',
        name: 'PowerHouse CrossFit',
        subtitle: 'High Intensity Training',
        rating: 4.7,
        reviews: 203,
        distance: 3.9,
        location: 'Cyber City, Gurgaon',
        isVerified: true,
        avatarUrl: null,
      ),
    ]);
  }

  List<DiscoverItem> get _currentItems {
    switch (_selectedTabIndex) {
      case 0:
        return _trainers;
      case 1:
        return _nutritionists;
      case 2:
        return _centers;
      default:
        return _trainers;
    }
  }

  String get _currentTabName {
    switch (_selectedTabIndex) {
      case 0:
        return 'trainers';
      case 1:
        return 'nutritionists';
      case 2:
        return 'centers';
      default:
        return 'trainers';
    }
  }

  LinearGradient _tabGradient(int index) {
    if (index == 1) {
      return LinearGradient(
        colors: [
          DesignTokens.accentGreen,
          DesignTokens.accentGreen.withValues(alpha: 204),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (index == 2) {
      return LinearGradient(
        colors: [DesignTokens.accentPurple, DesignTokens.accentBlueLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return LinearGradient(
      colors: [DesignTokens.accentOrange, DesignTokens.accentAmber],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Color _tabAccent(int index) {
    if (index == 1) return DesignTokens.accentGreen;
    if (index == 2) return DesignTokens.accentPurple;
    return DesignTokens.accentOrange;
  }

  List<String> _categoriesForTab() {
    switch (_selectedTabIndex) {
      case 0:
        return ['Strength', 'Yoga', 'Cardio', 'Boxing', 'HIIT'];
      case 1:
        return [
          'Weight Loss',
          'Sports Nutrition',
          'Clinical',
          'Plant-Based',
          'Lifestyle',
        ];
      case 2:
        return ['Gym', 'Yoga Studio', 'CrossFit', 'Pilates', 'Martial Arts'];
      default:
        return ['Strength', 'Yoga', 'Cardio'];
    }
  }

  void _openFilterSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _DiscoverFilterSheet(
          title: 'Filter ${_currentTabName[0].toUpperCase()}${_currentTabName.substring(1)}',
          accentColor: _tabAccent(_selectedTabIndex),
          categories: _categoriesForTab(),
          distance: _distance,
          minRating: _minRating,
          selectedCategories: _selectedCategories,
          onApply: (distance, minRating, categories) {
            setState(() {
              _distance = distance;
              _minRating = minRating;
              _selectedCategories = categories;
            });
          },
          onReset: () {
            setState(() {
              _distance = const RangeValues(0, 50);
              _minRating = null;
              _selectedCategories = {};
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: DesignTokens.spacing16,
                  right: DesignTokens.spacing16,
                  top: DesignTokens.spacing12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DiscoverHeaderRow(accentColor: AppColors.purple),
                    const SizedBox(height: DesignTokens.spacing16),
                    _DiscoverSearchBar(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      isFocused: _isSearchFocused,
                      hintText: 'Search $_currentTabName...',
                      isFilterPressed: _isFilterPressed,
                      onFilterTap: () async {
                        setState(() => _isFilterPressed = true);
                        await Future.delayed(const Duration(milliseconds: 120));
                        setState(() => _isFilterPressed = false);
                        _openFilterSheet();
                      },
                    ),
                    const SizedBox(height: DesignTokens.spacing16),
                    _DiscoverSegmentTabs(
                      tabs: const ['Trainers', 'Nutritionists', 'Centers'],
                      selectedIndex: _selectedTabIndex,
                      onTabChanged: (index) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTabIndex = index);
                      },
                      selectedGradient: _tabGradient(_selectedTabIndex),
                      selectedAccent: _tabAccent(_selectedTabIndex),
                    ),
                    const SizedBox(height: DesignTokens.spacing12),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: _DiscoverSkeletonCard(),
                    ),
                    childCount: 3,
                  ),
                ),
              )
            else if (_currentItems.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _currentItems[index];
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 260 + (index * 60)),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 12 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _DiscoverResultCard(
                            item: item,
                            accentColor: _tabAccent(_selectedTabIndex),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              // TODO: Navigate to detail page
                            },
                          ),
                        ),
                      );
                    },
                    childCount: _currentItems.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacing24),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: DesignTokens.textSecondaryOf(context),
            ),
            const SizedBox(height: DesignTokens.spacing16),
            Text(
              'No results',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeH3,
                fontWeight: FontWeight.w700,
                color: DesignTokens.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: DesignTokens.spacing8),
            Text(
              'Try changing filters',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeBodySmall,
                color: DesignTokens.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverHeaderRow extends StatelessWidget {
  final Color accentColor;

  const _DiscoverHeaderRow({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.92, end: 1.0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.explore_rounded,
                size: 22,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                colors: [AppColors.purple, AppColors.blue],
              ).createShader(rect),
              child: const Text(
                'DISCOVER',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final String hintText;
  final bool isFilterPressed;
  final VoidCallback onFilterTap;

  const _DiscoverSearchBar({
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.hintText,
    required this.isFilterPressed,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isFocused
              ? AppColors.orange.withOpacity(0.6)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 20,
            color: Colors.black.withOpacity(0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
              cursorColor: AppColors.orange,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.4),
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              if (value.text.isEmpty) {
                return const SizedBox.shrink();
              }
              return GestureDetector(
                onTap: controller.clear,
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.black.withOpacity(0.5),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onFilterTap,
            child: AnimatedScale(
              scale: isFilterPressed ? 0.98 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orange.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverSegmentTabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final LinearGradient selectedGradient;
  final Color selectedAccent;

  const _DiscoverSegmentTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChanged,
    required this.selectedGradient,
    required this.selectedAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        height: 44,
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = index == selectedIndex;
            final selectedColor =
                index == 1 ? Colors.green : (index == 2 ? Colors.grey : AppColors.orange);
            return Expanded(
              child: GestureDetector(
                onTap: () => onTabChanged(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? selectedColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: selectedColor.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      tabs[index],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : Colors.black.withOpacity(0.55),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _DiscoverResultCard extends StatefulWidget {
  final DiscoverItem item;
  final Color accentColor;
  final VoidCallback onTap;

  const _DiscoverResultCard({
    required this.item,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_DiscoverResultCard> createState() => _DiscoverResultCardState();
}

class _DiscoverResultCardState extends State<_DiscoverResultCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final splash = widget.accentColor.withValues(alpha: 20);
    final highlight = widget.accentColor.withValues(alpha: 10);

    return AnimatedScale(
      scale: _pressed ? 0.99 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          splashColor: splash,
          highlightColor: highlight,
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: SizedBox(
              height: 108,
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF1F1F4),
                        ),
                        child: ClipOval(
                          child: widget.item.avatarUrl == null
                              ? const _ShimmerBox(radius: 36)
                              : Image.network(
                                  widget.item.avatarUrl!,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      if (widget.item.isVerified)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.orange,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.orange.withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.item.subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: widget.accentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.item.rating.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.item.distance.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black.withOpacity(0.55),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: Colors.black.withOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.item.location,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black.withOpacity(0.55),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Colors.black.withOpacity(0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoverSkeletonCard extends StatelessWidget {
  const _DiscoverSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 108,
        child: Row(
          children: [
            const _ShimmerBox(width: 64, height: 64, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _ShimmerBox(width: double.infinity, height: 16, radius: 8),
                  SizedBox(height: 8),
                  _ShimmerBox(width: 180, height: 12, radius: 6),
                  SizedBox(height: 10),
                  _ShimmerBox(width: 140, height: 12, radius: 6),
                  SizedBox(height: 10),
                  _ShimmerBox(width: 160, height: 12, radius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final double radius;
  final EdgeInsets padding;
  final Widget child;

  const _GlassCard({
    required this.radius,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 20,
                spreadRadius: -2,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    this.width = double.infinity,
    this.height = double.infinity,
    this.radius = 12,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = DesignTokens.textSecondaryOf(context).withValues(alpha: 35);
    final highlight =
        DesignTokens.textSecondaryOf(context).withValues(alpha: 80);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + (2 * _controller.value), -1),
              end: Alignment(1 + (2 * _controller.value), 1),
              colors: [base, highlight, base],
            ),
          ),
        );
      },
    );
  }
}

class _DiscoverFilterSheet extends StatefulWidget {
  final String title;
  final Color accentColor;
  final List<String> categories;
  final RangeValues distance;
  final String? minRating;
  final Set<String> selectedCategories;
  final void Function(RangeValues, String?, Set<String>) onApply;
  final VoidCallback onReset;

  const _DiscoverFilterSheet({
    required this.title,
    required this.accentColor,
    required this.categories,
    required this.distance,
    required this.minRating,
    required this.selectedCategories,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_DiscoverFilterSheet> createState() => _DiscoverFilterSheetState();
}

class _DiscoverFilterSheetState extends State<_DiscoverFilterSheet> {
  late RangeValues _distance;
  String? _minRating;
  late Set<String> _selectedCategories;

  final List<String> _ratingOptions = ['Any', '4.5+', '4.0+', '3.5+'];

  @override
  void initState() {
    super.initState();
    _distance = widget.distance;
    _minRating = widget.minRating;
    _selectedCategories =
        widget.selectedCategories.where(widget.categories.contains).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final selectedRating = _minRating ?? 'Any';

    return Container(
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).size.height * 0.1,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: DesignTokens.borderColorOf(context).withValues(alpha: 64),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.black.withOpacity(0.08), height: 1),
          const SizedBox(height: 16),
          _FilterSectionHeader(
            icon: Icons.map_outlined,
            label: 'Distance',
            value: '${_distance.start.toInt()} - ${_distance.end.toInt()}+ km',
            accentColor: widget.accentColor,
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: AppColors.orange,
              inactiveTrackColor: Colors.black.withOpacity(0.1),
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 14,
              ),
            ),
            child: RangeSlider(
              values: _distance,
              min: 0,
              max: 50,
              divisions: 50,
              onChanged: (value) => setState(() => _distance = value),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.black.withOpacity(0.08), height: 1),
          const SizedBox(height: 16),
          _FilterChipSection(
            title: 'Minimum Rating',
            options: _ratingOptions,
            selected: selectedRating,
            onChanged: (value) =>
                setState(() => _minRating = value == 'Any' ? null : value),
            selectedColor: AppColors.orange,
          ),
          const SizedBox(height: 16),
          _CategoryChips(
            categories: widget.categories,
            selected: _selectedCategories,
            accentColor: widget.accentColor,
            onToggle: (value) {
              setState(() {
                if (_selectedCategories.contains(value)) {
                  _selectedCategories.remove(value);
                } else {
                  _selectedCategories.add(value);
                }
              });
            },
          ),
          const SizedBox(height: 20),
          _PrimaryActionButton(
            label: 'Apply Filters',
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onApply(_distance, _minRating, _selectedCategories);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 12),
          _SecondaryActionButton(
            label: 'Reset',
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onReset();
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _FilterSectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  const _FilterSectionHeader({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 20, color: AppColors.orange),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: Colors.black.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}

class _FilterChipSection extends StatelessWidget {
  final String title;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final Color selectedColor;

  const _FilterChipSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((option) {
            final isSelected = option == selected;
            return GestureDetector(
              onTap: () => onChanged(isSelected ? null : option),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? selectedColor : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? selectedColor
                        : Colors.black.withOpacity(0.08),
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? Colors.white
                        : Colors.black.withOpacity(0.6),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final Set<String> selected;
  final Color accentColor;
  final ValueChanged<String> onToggle;

  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.accentColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: categories.map((category) {
        final isSelected = selected.contains(category);
        return GestureDetector(
          onTap: () => onToggle(category),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor
                  : const Color(0xFFF1F1F4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? accentColor
                    : Colors.black.withOpacity(0.06),
              ),
            ),
            child: Text(
              category,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : Colors.black.withOpacity(0.6),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryActionButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.orange,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.orange.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryActionButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.black.withOpacity(0.08),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
}

class DiscoverItem {
  final String id;
  final String name;
  final String subtitle;
  final double rating;
  final int reviews;
  final double distance;
  final String location;
  final bool isVerified;
  final String? avatarUrl;

  DiscoverItem({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.rating,
    required this.reviews,
    required this.distance,
    required this.location,
    required this.isVerified,
    required this.avatarUrl,
  });
}
