import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/design_tokens.dart';
import '../../models/discover_filters.dart';
import '../../widgets/discover/discover_filter_sheet.dart';
import '../../repositories/provider_locations_repository.dart';
import '../../models/subscription_plans.dart';
import '../../repositories/subscriptions_repository.dart';
import '../../services/leads_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'center_detail_page.dart';
import '../profile/public_profile_readonly_page.dart';

const _discoverGradient = DesignTokens.discoverGradient;
const _discoverAccent = DesignTokens.discoverAccent;

/// Location state for discover page
enum DiscoverLocationState {
  granted,
  denied,
  manual,
  browse,
}

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
  String? _errorMessage;
  Position? _userPosition;
  DiscoverLocationState _locationState = DiscoverLocationState.granted;
  double? _manualLat;
  double? _manualLng;
  DiscoverFilters _filters = const DiscoverFilters();

  // Track request status: 'none', 'pending', 'accepted'
  final Map<String, String> _requestStatus = {};
  final Map<String, String> _leadIdsByProvider = {};
  final Set<String> _submittingProviders = {};

  // Real data from Supabase
  final List<DiscoverItem> _trainers = [];
  final List<DiscoverItem> _nutritionists = [];
  final List<DiscoverItem> _centers = [];

  final ProviderLocationsRepository _repo = ProviderLocationsRepository();
  final LeadsService _leadsService = LeadsService();

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
    _loadRealData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  /// Load real data from Supabase using nearby_providers RPC
  Future<void> _loadRealData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _trainers.clear();
      _nutritionists.clear();
      _centers.clear();
    });

    try {
      // Get user location
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'location_disabled';
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'location_denied';
            _isLoading = false;
          });
          return;
        }
      }

      if (!mounted) return;
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'location_denied_forever';
          _isLoading = false;
        });
        return;
      }

      _userPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (!mounted) return;
      // Fetch nearby trainers
      final trainerResults = await _repo.fetchNearbyProviders(
        userLat: _userPosition!.latitude,
        userLng: _userPosition!.longitude,
        filters: _filters.copyWith(providerTypes: ['trainer']),
      );

      // Fetch nearby nutritionists
      final nutritionistResults = await _repo.fetchNearbyProviders(
        userLat: _userPosition!.latitude,
        userLng: _userPosition!.longitude,
        filters: _filters.copyWith(providerTypes: ['nutritionist']),
      );
      if (!mounted) return;

      // Map trainer results to DiscoverItem
      for (var result in trainerResults) {
        final distanceKm = (result['distance_km'] as num?)?.toDouble() ?? 0.0;
        final locationType = result['location_type'] as String?;
        final geo = result['geo']; // May be null for home-private locations

        // Extract provider info
        final providerId = result['provider_id'] as String? ?? '';
        final displayName = result['display_name'] as String? ?? 'Unknown Location';
        final fullName = result['full_name'] as String? ?? 'Unknown Provider';
        final avatarUrl = result['avatar_url'] as String?;
        final verified = result['verified'] as bool? ?? false;
        final rating = (result['rating'] as num?)?.toDouble() ?? 0.0;
        final totalReviews = (result['total_reviews'] as int?) ?? 0;
        final experienceYears = (result['experience_years'] as int?) ?? 0;
        final specialization = (result['specialization'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        final subtitle = specialization.isNotEmpty 
            ? specialization.join(', ')
            : 'Fitness Trainer';

        // Create location string (use display_name for home-private, otherwise show distance)
        final location = geo == null && locationType == 'home'
            ? displayName
            : '${distanceKm.toStringAsFixed(1)} km away';

        _trainers.add(DiscoverItem(
          id: providerId,
          name: fullName,
          subtitle: subtitle,
          rating: rating,
          reviews: totalReviews,
          distance: distanceKm,
          location: location,
          isVerified: verified,
          avatarUrl: avatarUrl,
          experienceYears: experienceYears,
        ));
      }

      // Map nutritionist results to DiscoverItem
      for (var result in nutritionistResults) {
        final distanceKm = (result['distance_km'] as num?)?.toDouble() ?? 0.0;
        final locationType = result['location_type'] as String?;
        final geo = result['geo']; // May be null for home-private locations

        // Extract provider info
        final providerId = result['provider_id'] as String? ?? '';
        final displayName = result['display_name'] as String? ?? 'Unknown Location';
        final fullName = result['full_name'] as String? ?? 'Unknown Provider';
        final avatarUrl = result['avatar_url'] as String?;
        final verified = result['verified'] as bool? ?? false;
        final rating = (result['rating'] as num?)?.toDouble() ?? 0.0;
        final totalReviews = (result['total_reviews'] as int?) ?? 0;
        final experienceYears = (result['experience_years'] as int?) ?? 0;
        final specialization = (result['specialization'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        final subtitle = specialization.isNotEmpty 
            ? specialization.join(', ')
            : 'Nutritionist';

        // Create location string (use display_name for home-private, otherwise show distance)
        final location = geo == null && locationType == 'home'
            ? displayName
            : '${distanceKm.toStringAsFixed(1)} km away';

        _nutritionists.add(DiscoverItem(
          id: providerId,
          name: fullName,
          subtitle: subtitle,
          rating: rating,
          reviews: totalReviews,
          distance: distanceKm,
          location: location,
          isVerified: verified,
          avatarUrl: avatarUrl,
          experienceYears: experienceYears,
        ));
      }

      // Sort by distance
      _trainers.sort((a, b) => a.distance.compareTo(b.distance));
      _nutritionists.sort((a, b) => a.distance.compareTo(b.distance));

      final sub = await SubscriptionsRepository().fetchMine();
      final plan = sub?.plan ?? SubscriptionPlans.free;
      final cap = SubscriptionPlans.discoverResultCap(plan);
      if (cap != null) {
        if (_trainers.length > cap) {
          _trainers.removeRange(cap, _trainers.length);
        }
        _nutritionists.clear();
      }

      await _loadRequestStatuses();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('Discover load error: $e');
      if (kDebugMode) debugPrint('$st');
      if (!mounted) return;
      setState(() {
        _errorMessage = _classifyLoadError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRequestStatuses() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final leads = await _leadsService.getMyLeads();
      if (!mounted) return;

      _requestStatus.clear();
      _leadIdsByProvider.clear();
      for (final lead in leads.where((l) => l.clientId == uid)) {
        if (lead.status == 'requested') {
          _requestStatus[lead.providerId] = 'pending';
          _leadIdsByProvider[lead.providerId] = lead.id;
        } else if (lead.status == 'accepted') {
          _requestStatus[lead.providerId] = 'accepted';
        }
      }
    } catch (e) {
      debugPrint('Discover: failed to load lead statuses: $e');
    }
  }

  Future<void> _sendRequest(DiscoverItem item) async {
    if (_submittingProviders.contains(item.id)) return;
    HapticFeedback.mediumImpact();
    setState(() => _submittingProviders.add(item.id));

    try {
      final result = await _leadsService.createLead(providerId: item.id);
      if (!mounted) return;
      setState(() {
        _requestStatus[item.id] = 'pending';
        _leadIdsByProvider[item.id] = result.leadId;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request sent to ${item.name}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Discover: send request failed: $e');
      final err = e.toString();
      final String message;
      if (err.contains('Lead already exists')) {
        message = 'You already have a pending or active request with ${item.name}';
      } else if (err.contains('Only clients can create leads')) {
        message = 'Only client accounts can send coaching requests.';
      } else if (err.contains('Provider not found')) {
        message = 'This provider is no longer available.';
      } else if (err.contains('limit reached')) {
        message = 'Weekly request limit reached. Upgrade your plan for more requests.';
      } else if (err.contains('Nutritionist requests require')) {
        message = 'Nutritionist requests require a Basic or Premium plan.';
      } else {
        final match = RegExp(r'Exception:\s*(.+)$').firstMatch(err);
        message = match?.group(1)?.trim() ?? 'Could not send request. Please try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingProviders.remove(item.id));
      }
    }
  }

  Future<void> _cancelRequest(DiscoverItem item) async {
    final leadId = _leadIdsByProvider[item.id];
    if (leadId == null) {
      setState(() => _requestStatus[item.id] = 'none');
      return;
    }
    if (_submittingProviders.contains(item.id)) return;
    HapticFeedback.mediumImpact();
    setState(() => _submittingProviders.add(item.id));

    try {
      await _leadsService.updateLeadStatus(leadId: leadId, status: 'cancelled');
      if (!mounted) return;
      setState(() {
        _requestStatus[item.id] = 'none';
        _leadIdsByProvider.remove(item.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request canceled'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not cancel request: $e'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingProviders.remove(item.id));
      }
    }
  }

  String _classifyLoadError(Object e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('nearby_providers') ||
        raw.contains('postgrestexception') ||
        raw.contains('could not find function')) {
      return 'backend_unavailable';
    }
    return 'generic';
  }

  String _friendlyErrorMessage() {
    switch (_errorMessage) {
      case 'location_disabled':
        return 'Location services are off. Enable them to discover nearby providers.';
      case 'location_denied':
        return 'Location permission is required to find providers near you.';
      case 'location_denied_forever':
        return 'Location access was denied. Open settings to enable it.';
      case 'backend_unavailable':
        return 'We couldn\'t load providers right now.\nPlease try again.';
      default:
        return 'We couldn\'t load providers right now.\nPlease try again.';
    }
  }

  bool get _errorNeedsSettings =>
      _errorMessage == 'location_denied_forever' ||
      _errorMessage == 'location_disabled';


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

  void _showFilterSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    final filterType = _selectedTabIndex == 0
        ? FilterType.trainers
        : _selectedTabIndex == 1
            ? FilterType.nutritionists
            : FilterType.centers;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DiscoverFilterSheet(
        filterType: filterType,
        accentColor: _discoverAccent,
        gradient: _discoverGradient,
        initialFilters: _filters,
        onApply: (filters) {
          setState(() {
            _filters = filters.copyWith(
              providerTypes: filterType == FilterType.trainers
                  ? ['trainer']
                  : filterType == FilterType.nutritionists
                      ? ['nutritionist']
                      : null,
            );
          });
          _loadRealData();
        },
        onReset: () {
          setState(() => _filters = const DiscoverFilters());
          _loadRealData();
        },
      ),
    );
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
            await _loadRealData();
          },
          color: _discoverAccent,
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
                      selectedTabIndex: _selectedTabIndex,
                      onFilterTap: () => _showFilterSheet(context),
                    ),
                    const SizedBox(height: DesignTokens.spacing16),
                    _DiscoverSegmentTabs(
                      tabs: const ['Trainers', 'Nutritionists', 'Centers'],
                      selectedIndex: _selectedTabIndex,
                      onTabChanged: (index) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTabIndex = index);
                      },
                      selectedGradient: _discoverGradient,
                    ),
                    const SizedBox(height: DesignTokens.spacing12),
                  ],
                ),
              ),
            ),
            if (_isLoading) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacing16,
                    vertical: DesignTokens.spacing8,
                  ),
                  child: _DiscoverLoadingHeader(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: _DiscoverSkeletonCard(),
                    ),
                    childCount: 4,
                  ),
                ),
              ),
            ]
            else if (_errorMessage != null)
              SliverToBoxAdapter(child: _buildErrorState())
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
                            accentColor: _discoverAccent,
                            accentGradient: _discoverGradient,
                            isCenter: _selectedTabIndex == 2,
                            requestStatus: _requestStatus[item.id] ?? 'none',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              if (_selectedTabIndex == 2) {
                                // Navigate to center detail page
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CenterDetailPage(
                                      centerId: item.id,
                                      centerName: item.name,
                                      subtitle: item.subtitle,
                                      location: item.location,
                                      rating: item.rating,
                                      reviews: item.reviews,
                                      distance: item.distance,
                                    ),
                                  ),
                                );
                              } else {
                                // Navigate to user profile page for trainers/nutritionists
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PublicProfileReadonlyPage(
                                      userId: item.id,
                                      titleFallback: item.name,
                                      providerType: _selectedTabIndex == 0
                                          ? 'trainer'
                                          : 'nutritionist',
                                    ),
                                  ),
                                );
                              }
                            },
                            onRequest: () => _sendRequest(item),
                            onCancelRequest: () => _cancelRequest(item),
                            onChat: () {
                              HapticFeedback.lightImpact();
                              // TODO: Navigate to chat
                              context.push('/messaging');
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: DesignTokens.textSecondaryOf(context),
            ),
            const SizedBox(height: DesignTokens.spacing16),
            Text(
              'No providers found',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeH3,
                fontWeight: FontWeight.w700,
                color: DesignTokens.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: DesignTokens.spacing8),
            Text(
              'Try changing filters or distance.',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeBodySmall,
                color: DesignTokens.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spacing16),
            OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _filters = const DiscoverFilters());
                _loadRealData();
              },
              icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: const Text('Reset filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacing24),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: DesignTokens.textSecondaryOf(context),
            ),
            const SizedBox(height: DesignTokens.spacing16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeH3,
                fontWeight: FontWeight.w700,
                color: DesignTokens.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: DesignTokens.spacing8),
            Text(
              _friendlyErrorMessage(),
              style: TextStyle(
                fontSize: DesignTokens.fontSizeBodySmall,
                color: DesignTokens.textSecondaryOf(context),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spacing16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _loadRealData();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _discoverAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (_errorNeedsSettings) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Geolocator.openAppSettings();
                    },
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text('Settings'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverLoadingHeader extends StatefulWidget {
  @override
  State<_DiscoverLoadingHeader> createState() => _DiscoverLoadingHeaderState();
}

class _DiscoverLoadingHeaderState extends State<_DiscoverLoadingHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _discoverAccent,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Finding the best matches…',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: DesignTokens.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverHeaderRow extends StatelessWidget {
  const _DiscoverHeaderRow();

  @override
  Widget build(BuildContext context) {
    final titleColor = DesignTokens.textPrimaryOf(context);

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
              shaderCallback: (rect) =>
                  DesignTokens.discoverHeaderIconGradient.createShader(rect),
              child: const Icon(
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
            child: Text(
              'DISCOVER',
              style: GoogleFonts.montserrat(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: titleColor,
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
  final int selectedTabIndex;
  final VoidCallback onFilterTap;

  const _DiscoverSearchBar({
    required this.controller,
    required this.focusNode,
    required this.selectedTabIndex,
    required this.onFilterTap,
  });

  @override
  State<_DiscoverSearchBar> createState() => _DiscoverSearchBarState();
}

class _DiscoverSearchBarState extends State<_DiscoverSearchBar> {
  String get _hintText {
    switch (widget.selectedTabIndex) {
      case 1:
        return 'Search nutritionists...';
      case 2:
        return 'Search centers...';
      default:
        return 'Search trainers...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? DesignTokens.darkSurface : Colors.white;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : DesignTokens.lightBorder,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
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
          hintText: _hintText,
          hintStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: DesignTokens.textSecondaryOf(context),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 22,
            color: DesignTokens.textSecondaryOf(context),
          ),
          suffixIcon: GestureDetector(
            onTap: widget.onFilterTap,
            child: Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    DesignTokens.discoverOrange.withValues(alpha: 0.18),
                    DesignTokens.discoverOrangeDeep.withValues(alpha: 0.14),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: ShaderMask(
                shaderCallback: (rect) => _discoverGradient.createShader(rect),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: Colors.white,
                ),
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

  const _DiscoverSegmentTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChanged,
    required this.selectedGradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedTextColor = DesignTokens.textSecondaryOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / tabs.length;
        final pillWidth = tabWidth - 8;
        
        return Container(
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? DesignTokens.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : DesignTokens.lightBorder,
            ),
          ),
          child: Stack(
            children: [
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
                                  : unselectedTextColor,
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

String _formatDiscoverRating(DiscoverItem item) {
  if (item.reviews <= 0) return 'New';
  return '⭐ ${item.rating.toStringAsFixed(1)} (${item.reviews})';
}

class _DiscoverResultCard extends StatefulWidget {
  final DiscoverItem item;
  final Color accentColor;
  final LinearGradient accentGradient;
  final bool isCenter;
  final String requestStatus; // 'none', 'pending', 'accepted'
  final VoidCallback onTap;
  final VoidCallback? onRequest;
  final VoidCallback? onCancelRequest;
  final VoidCallback? onChat;

  const _DiscoverResultCard({
    required this.item,
    required this.accentColor,
    required this.accentGradient,
    this.isCenter = false,
    this.requestStatus = 'none',
    required this.onTap,
    this.onRequest,
    this.onCancelRequest,
    this.onChat,
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
          borderRadius: BorderRadius.circular(20),
          splashColor: splash,
          highlightColor: highlight,
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: widget.isCenter
                ? _buildCenterCard(colorScheme)
                : _buildProfileCard(colorScheme),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(ColorScheme colorScheme) {
    final hasRequest = widget.requestStatus != 'none';
    final isAccepted = widget.requestStatus == 'accepted';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.surfaceVariant,
                  ),
                  child: ClipOval(
                    child: widget.item.avatarUrl == null || widget.item.avatarUrl!.isEmpty
                        ? Container(
                            color: colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.person_rounded,
                              size: 35,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: widget.item.avatarUrl!,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: colorScheme.surfaceContainerHighest,
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.person_rounded,
                                size: 35,
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                  ),
                ),
                if (widget.item.isVerified)
                  Positioned(
                    bottom: -4,
                    right: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 3,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          gradient: widget.accentGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDiscoverRating(widget.item),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withOpacity(0.85),
                    ),
                  ),
                  if (widget.item.experienceYears > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.work_outline_rounded,
                          size: 12,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${widget.item.experienceYears} years',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${widget.item.distance.toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Request/Chat/Cancel Button
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            isAccepted
                ? Container(
                    decoration: BoxDecoration(
                      gradient: widget.accentGradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onChat,
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 5),
                              const Text(
                                'Chat',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : hasRequest
                    ? OutlinedButton.icon(
                        onPressed: widget.onCancelRequest,
                        icon: const Icon(Icons.close_rounded, size: 12),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.onSurfaceVariant,
                          side: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.3),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: widget.accentGradient,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onRequest,
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              child: const Text(
                                'Request',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
          ],
        ),
      ],
    );
  }

  Widget _buildCenterCard(ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: colorScheme.surfaceVariant,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: widget.item.avatarUrl == null || widget.item.avatarUrl!.isEmpty
                ? Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.place_rounded,
                      size: 35,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: widget.item.avatarUrl!,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.place_rounded,
                        size: 35,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDiscoverRating(widget.item),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 12,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${widget.item.distance.toStringAsFixed(1)} km',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          Icons.chevron_right_rounded,
          size: 16,
          color: colorScheme.onSurface.withOpacity(0.4),
        ),
      ],
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
  final int experienceYears;

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
    required this.experienceYears,
  });
}
