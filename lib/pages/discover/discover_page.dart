import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/design_tokens.dart';
import '../../theme/app_colors.dart';
import '../cocircle/cocircle_profile_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  int _selectedTabIndex = 0;
  bool _isLoading = false;


  // Mock data
  final List<DiscoverItem> _trainers = [];
  final List<DiscoverItem> _nutritionists = [];
  final List<DiscoverItem> _centers = [];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _loadMockData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
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


  LinearGradient _tabGradient(int index) {
    if (index == 1) {
      return const LinearGradient(
        colors: [
          Color(0xFF3ED598),
          Color(0xFF4DA3FF),
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
    if (index == 1) return const Color(0xFF3ED598); // Green for Nutritionists
    if (index == 2) return const Color(0xFF8B5CF6); // Purple for Centers
    return const Color(0xFFFF8A00); // Orange for Trainers
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            setState(() => _isLoading = true);
            await Future.delayed(const Duration(seconds: 1));
            setState(() => _isLoading = false);
          },
          color: DesignTokens.accentGreen,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
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
                    const _DiscoverHeaderRow(),
                    const SizedBox(height: DesignTokens.spacing16),
                    _DiscoverSearchBar(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      hintText: 'Search trainers...',
                      onFilterTap: () => HapticFeedback.selectionClick(),
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
                              // Navigate to profile page
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CocircleProfilePage(
                                    userId: item.id,
                                    userName: item.name,
                                    isOwnProfile: false,
                                  ),
                                ),
                              );
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
  const _DiscoverHeaderRow();

  @override
  Widget build(BuildContext context) {
    final discoverGradient = const LinearGradient(
      colors: [Color(0xFF3ED598), Color(0xFF4DA3FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    
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
            child: ShaderMask(
              shaderCallback: (rect) => discoverGradient.createShader(rect),
              child: Icon(
                Icons.explore_outlined,
                size: 26,
                color: Colors.white,
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
              shaderCallback: (rect) => discoverGradient.createShader(rect),
              child: Text(
                'DISCOVER',
                style: GoogleFonts.montserrat(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
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

class _DiscoverSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final VoidCallback onFilterTap;

  const _DiscoverSearchBar({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onFilterTap,
  });

  @override
  State<_DiscoverSearchBar> createState() => _DiscoverSearchBarState();
}

class _DiscoverSearchBarState extends State<_DiscoverSearchBar> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.transparent,
          hintText: widget.hintText,
          hintStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurface.withOpacity(0.4),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 22,
            color: colorScheme.onSurface.withOpacity(0.5),
          ),
          suffixIcon: GestureDetector(
            onTap: widget.onFilterTap,
            child: Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 18,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
        ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / tabs.length;
        final pillWidth = tabWidth - 8;
        
        return SizedBox(
          height: 44,
          child: Stack(
            children: [
              // Sliding pill background
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: (selectedIndex * tabWidth) + 4,
                top: 4,
                bottom: 4,
                width: pillWidth,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: selectedGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              // Tabs
              Row(
                children: List.generate(tabs.length, (index) {
                  final isSelected = index == selectedIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTabChanged(index),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Center(
                          child: Text(
                            tabs[index],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : colorScheme.onSurface.withOpacity(0.85),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
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
    final colorScheme = Theme.of(context).colorScheme;

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
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
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
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.surfaceVariant,
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
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
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
                            color: colorScheme.onSurface.withOpacity(0.6),
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
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colorScheme.onSurface.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.item.distance.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withOpacity(0.55),
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
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.item.location,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withOpacity(0.55),
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
                    color: colorScheme.onSurface.withOpacity(0.4),
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
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 20,
              spreadRadius: -2,
            ),
          ],
        ),
        child: child,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).size.height * 0.1,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
                  color: colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close_rounded,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: colorScheme.outline.withOpacity(0.2), height: 1),
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
              activeTrackColor: widget.accentColor,
              inactiveTrackColor: colorScheme.outline.withOpacity(0.3),
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
          Divider(color: colorScheme.outline.withOpacity(0.2), height: 1),
          const SizedBox(height: 16),
          _FilterChipSection(
            title: 'Minimum Rating',
            options: _ratingOptions,
            selected: selectedRating,
            onChanged: (value) =>
                setState(() => _minRating = value == 'Any' ? null : value),
            selectedColor: widget.accentColor,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 20, color: accentColor),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: colorScheme.onSurface.withOpacity(0.5),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
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
                  color: isSelected ? selectedColor : colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? selectedColor
                        : colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? Colors.white
                        : colorScheme.onSurface.withOpacity(0.6),
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
    final colorScheme = Theme.of(context).colorScheme;

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
                  : colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? accentColor
                    : colorScheme.outline.withOpacity(0.16),
              ),
            ),
            child: Text(
              category,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : colorScheme.onSurface.withOpacity(0.6),
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
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.35),
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
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface.withOpacity(0.7),
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
