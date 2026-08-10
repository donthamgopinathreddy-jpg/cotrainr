import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/design_tokens.dart';
import '../../models/discover_filters.dart';
import '../../models/provider_specialty_taxonomy.dart';
import '../../widgets/discover/discover_filter_sheet.dart';
import '../../repositories/provider_locations_repository.dart';
import '../../repositories/partner_centers_repository.dart';
import '../../models/subscription_plans.dart';
import '../../repositories/subscriptions_repository.dart';
import '../../services/entitlement_service.dart';
import '../../services/leads_service.dart';
import '../../widgets/provider/discover_provider_card.dart';
import '../../widgets/subscription/nutritionist_upgrade_sheet.dart';
import '../../widgets/subscription/connection_limit_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'center_detail_page.dart';

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
  /// Soft banner when browsing without GPS (list still loads).
  String? _locationNotice;
  bool _browseWithoutLocation = false;
  /// Cached client plan (DB ids: free / basic / premium).
  String _clientPlan = SubscriptionPlans.free;
  /// From get-entitlements / create_lead_tx; null = unlimited.
  int? _requestLimit;
  Position? _userPosition;
  DiscoverLocationState _locationState = DiscoverLocationState.granted;
  double? _manualLat;
  double? _manualLng;
  DiscoverFilters _filters = const DiscoverFilters();
  String _searchQuery = '';

  // Track request status: 'none', 'pending', 'accepted'
  final Map<String, String> _requestStatus = {};
  final Map<String, String> _leadIdsByProvider = {};
  final Set<String> _submittingProviders = {};

  // Real data from Supabase
  final List<DiscoverItem> _trainers = [];
  final List<DiscoverItem> _nutritionists = [];
  final List<DiscoverItem> _centers = [];

  final ProviderLocationsRepository _repo = ProviderLocationsRepository();
  final PartnerCentersRepository _partnerCentersRepo =
      PartnerCentersRepository();
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
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final discoverTab =
          GoRouterState.of(context).uri.queryParameters['discover'];
      if (discoverTab == 'nutritionists') {
        setState(() => _selectedTabIndex = 1);
      } else if (discoverTab == 'centers') {
        setState(() => _selectedTabIndex = 2);
      }
    });
    _loadRealData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _searchQuery) return;
    setState(() => _searchQuery = next);
  }

  /// Load real data from Supabase (nearby when GPS available, else browse).
  Future<void> _loadRealData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _locationNotice = null;
      _browseWithoutLocation = false;
      _trainers.clear();
      _nutritionists.clear();
      _centers.clear();
    });

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (kDebugMode) {
        debugPrint('Discover load start user=${uid ?? 'anon'}');
      }

      final location = await _resolveClientLocation();
      if (!mounted) return;

      List<Map<String, dynamic>> trainerResults;
      List<Map<String, dynamic>> nutritionistResults;

      if (location != null) {
        _userPosition = location;
        _locationState = DiscoverLocationState.granted;
        trainerResults = await _repo.fetchNearbyProviders(
          userLat: location.latitude,
          userLng: location.longitude,
          filters: _filtersForProviderType('trainer'),
        );
        nutritionistResults = await _repo.fetchNearbyProviders(
          userLat: location.latitude,
          userLng: location.longitude,
          filters: _filtersForProviderType('nutritionist'),
        );
      } else {
        _browseWithoutLocation = true;
        _locationState = DiscoverLocationState.browse;
        _locationNotice =
            'Location unavailable — showing all eligible providers.';
        trainerResults = await _repo.fetchDiscoverableProviders(
          filters: _filtersForProviderType('trainer'),
        );
        nutritionistResults = await _repo.fetchDiscoverableProviders(
          filters: _filtersForProviderType('nutritionist'),
        );
      }
      if (!mounted) return;

      _trainers
        ..clear()
        ..addAll(_mapProviderRows(trainerResults, fallbackSubtitle: 'Fitness Trainer'));
      _nutritionists
        ..clear()
        ..addAll(
          _mapProviderRows(nutritionistResults, fallbackSubtitle: 'Nutritionist'),
        );

      _trainers.sort(_compareDiscoverItems);
      _nutritionists.sort(_compareDiscoverItems);

      try {
        final partnerCenters = await _partnerCentersRepo.listForDiscover();
        _centers
          ..clear()
          ..addAll(_mapPartnerCenters(partnerCenters));
        _centers.sort(_compareDiscoverItems);
      } catch (e) {
        if (kDebugMode) debugPrint('Discover partner centres: $e');
        // Centres tab stays empty if partner RPC/migration not applied yet.
      }

      final sub = await SubscriptionsRepository().fetchMine();
      final plan = sub?.plan ?? SubscriptionPlans.free;
      _clientPlan = plan;
      // Authoritative monthly allowance (server); used before Connect.
      try {
        final ents = await EntitlementService().getEntitlements();
        _requestLimit = ents.limits.requestsUnlimited
            ? null
            : ents.limits.requests;
      } catch (_) {
        _requestLimit =
            SubscriptionPlans.monthlyConnectionRequestLimit(plan);
      }
      final cap = SubscriptionPlans.discoverResultCap(plan);
      // Cap trainers only — nutritionists stay fully browsable for Free.
      if (cap != null && _trainers.length > cap) {
        _trainers.removeRange(cap, _trainers.length);
      }

      if (kDebugMode) {
        debugPrint(
          'Discover mapped trainers=${_trainers.length} '
          'nutritionists=${_nutritionists.length} '
          'browse=$_browseWithoutLocation filters=${_filters.toChipLabel()}',
        );
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

  List<DiscoverItem> _mapPartnerCenters(
    List<PartnerCenterDiscoverItem> centres,
  ) {
    return centres.map((c) {
      double distance = double.infinity;
      if (_userPosition != null &&
          c.latitude != null &&
          c.longitude != null) {
        distance = Geolocator.distanceBetween(
              _userPosition!.latitude,
              _userPosition!.longitude,
              c.latitude!,
              c.longitude!,
            ) /
            1000.0;
      }
      final facilities = c.facilities.take(3).join(', ');
      final subtitle = facilities.isNotEmpty
          ? '${c.businessType} · $facilities'
          : c.businessType;
      return DiscoverItem(
        id: c.id,
        name: c.name,
        subtitle: subtitle,
        roleLabel: 'Centre',
        rating: 0,
        reviews: 0,
        distance: distance,
        location: c.locationLabel,
        isVerified: true,
        avatarUrl: c.logoUrl,
        isCotrainrPartner: true,
        activeOfferTitle: c.offerTitle,
        googlePlaceId: c.googlePlaceId,
      );
    }).toList();
  }

  /// Scope specialty chips to the role being queried so trainer filters
  /// (e.g. yoga) do not wipe the nutritionist RPC results.
  DiscoverFilters _filtersForProviderType(String providerType) {
    final allowed = ProviderSpecialtyTaxonomy.forRole(providerType)
        .map((s) => s.id)
        .toSet();
    final scoped = _filters.categories.where(allowed.contains).toSet();
    return _filters.copyWith(
      providerTypes: [providerType],
      categories: scoped,
    );
  }

  Future<Position?> _resolveClientLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Discover location resolve failed: $e');
      }
      return null;
    }
  }

  List<DiscoverItem> _mapProviderRows(
    List<Map<String, dynamic>> rows, {
    required String fallbackSubtitle,
  }) {
    final byId = <String, DiscoverItem>{};
    for (final result in rows) {
      final providerId = result['provider_id'] as String? ?? '';
      if (providerId.isEmpty) continue;

      final distanceKm = (result['distance_km'] as num?)?.toDouble();
      final locationType = result['location_type'] as String?;
      final geo = result['geo'];
      final displayName = result['display_name'] as String?;
      final fullName = result['full_name'] as String? ?? 'Unknown Provider';
      final avatarUrl = result['avatar_url'] as String?;
      final verified = result['verified'] as bool? ?? false;
      final rating = (result['rating'] as num?)?.toDouble() ?? 0.0;
      final totalReviews = (result['total_reviews'] as num?)?.toInt() ?? 0;
      final experienceYears = (result['experience_years'] as num?)?.toInt();
      final specializationRaw = (result['specialization'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final specializationIds =
          ProviderSpecialtyTaxonomy.normalizeList(specializationRaw);
      final specialtyLabels = ProviderSpecialtyTaxonomy.labelsFor(
        specializationIds.take(3),
      );
      final headline =
          (result['professional_headline'] as String?)?.trim() ?? '';
      final sessionModes = (result['session_modes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];

      final String subtitle;
      if (headline.isNotEmpty && specialtyLabels.isNotEmpty) {
        subtitle = '$headline · ${specialtyLabels.join(', ')}';
      } else if (headline.isNotEmpty) {
        subtitle = headline;
      } else if (specialtyLabels.isNotEmpty) {
        subtitle = specialtyLabels.join(', ');
      } else {
        subtitle = fallbackSubtitle;
      }

      final String? locationLabel;
      if (distanceKm != null && distanceKm > 0) {
        locationLabel =
            (geo == null && locationType == 'home' && displayName != null)
                ? displayName
                : '${distanceKm.toStringAsFixed(1)} km away';
      } else if (displayName != null && displayName.trim().isNotEmpty) {
        locationLabel = displayName.trim();
      } else {
        locationLabel = null;
      }

      final item = DiscoverItem(
        id: providerId,
        name: fullName,
        subtitle: subtitle,
        headline: headline.isNotEmpty ? headline : null,
        specialtyChips: specialtyLabels,
        roleLabel: fallbackSubtitle,
        rating: rating,
        reviews: totalReviews,
        distance: (distanceKm != null && distanceKm > 0)
            ? distanceKm
            : double.infinity,
        location: locationLabel ?? '',
        isVerified: verified,
        avatarUrl: avatarUrl,
        experienceYears: (experienceYears != null && experienceYears > 0)
            ? experienceYears
            : null,
        sessionModes: sessionModes,
        offersOnline: sessionModes.contains(ProviderSessionModes.online),
      );

      final existing = byId[providerId];
      if (existing == null || item.distance < existing.distance) {
        byId[providerId] = item;
      }
    }
    return byId.values.toList();
  }

  int _compareDiscoverItems(DiscoverItem a, DiscoverItem b) {
    final ad = a.distance.isFinite ? a.distance : double.infinity;
    final bd = b.distance.isFinite ? b.distance : double.infinity;
    final byDistance = ad.compareTo(bd);
    if (byDistance != 0) return byDistance;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  Future<void> _loadRequestStatuses() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final leads = await _leadsService.getMyLeads();
      if (!mounted) return;

      _requestStatus.clear();
      _leadIdsByProvider.clear();
      final acceptedIds = <String>{};
      for (final lead in leads.where((l) => l.clientId == uid)) {
        if (lead.status == 'requested') {
          _requestStatus[lead.providerId] = 'pending';
          _leadIdsByProvider[lead.providerId] = lead.id;
        } else if (lead.status == 'accepted') {
          _requestStatus[lead.providerId] = 'accepted';
          acceptedIds.add(lead.providerId);
        }
      }

      // Exclude accepted/active connections from Discover listings.
      setState(() {
        _trainers.removeWhere((i) => acceptedIds.contains(i.id));
        _nutritionists.removeWhere((i) => acceptedIds.contains(i.id));
      });
    } catch (e) {
      debugPrint('Discover: failed to load lead statuses: $e');
    }
  }

  Future<void> _sendRequest(DiscoverItem item) async {
    final isNutritionist = _selectedTabIndex == 1;
    if (isNutritionist &&
        !SubscriptionPlans.canConnectToNutritionist(_clientPlan)) {
      await showNutritionistUpgradeSheet(context);
      return;
    }

    // Do not client-block solely on remaining==0: same-provider re-request
    // in-month must still reach create_lead_tx (no second unique quota unit).

    if (_submittingProviders.contains(item.id)) return;
    HapticFeedback.mediumImpact();
    setState(() => _submittingProviders.add(item.id));

    try {
      final result = await _leadsService.createLead(providerId: item.id);
      if (!mounted) return;
      setState(() {
        _requestStatus[item.id] = 'pending';
        _leadIdsByProvider[item.id] = result.leadId;
        if (!result.unlimited && result.limit != null) {
          _requestLimit = result.limit;
        }
      });
      final remainingHint = result.unlimited
          ? null
          : (result.remaining != null
              ? ' · ${result.remaining} connection request${result.remaining == 1 ? '' : 's'} remaining this month'
              : null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Request sent to ${item.name}${remainingHint ?? ''}',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Discover: send request failed: $e');
      final err = e.toString();
      if (err.contains('Nutritionist requests require')) {
        await showNutritionistUpgradeSheet(context);
        return;
      }
      if (err.contains('Request limit reached') ||
          err.contains('limit reached')) {
        await showConnectionLimitSheet(
          context,
          plan: _clientPlan,
          limit: _requestLimit ??
              SubscriptionPlans.monthlyConnectionRequestLimit(_clientPlan),
        );
        return;
      }
      final String message;
      if (err.contains('Lead already exists')) {
        message = 'You already have a pending or active request with ${item.name}';
      } else if (err.contains('Only clients can create leads')) {
        message = 'Only client accounts can send coaching requests.';
      } else if (err.contains('Provider not found')) {
        message = 'This provider is no longer available.';
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
        raw.contains('discover_providers') ||
        raw.contains('postgrestexception') ||
        raw.contains('could not find function')) {
      return 'backend_unavailable';
    }
    return 'generic';
  }

  String _friendlyErrorMessage() {
    switch (_errorMessage) {
      case 'backend_unavailable':
        return 'We couldn\'t load providers right now.\nPlease try again.';
      default:
        return 'We couldn\'t load providers right now.\nPlease try again.';
    }
  }

  bool get _errorNeedsSettings => false;

  List<DiscoverItem> get _currentItems {
    final source = switch (_selectedTabIndex) {
      1 => _nutritionists,
      2 => _centers,
      _ => _trainers,
    };
    final q = _searchQuery.toLowerCase();
    if (q.isEmpty) return source;
    return source.where((item) {
      return item.name.toLowerCase().contains(q) ||
          item.subtitle.toLowerCase().contains(q) ||
          item.location.toLowerCase().contains(q);
    }).toList();
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
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 300),
        reverseDuration: Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
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
                    if (_locationNotice != null) ...[
                      const SizedBox(height: DesignTokens.spacing12),
                      _LocationBrowseBanner(
                        message: _locationNotice!,
                        onOpenSettings: () async {
                          await Geolocator.openAppSettings();
                        },
                      ),
                    ],
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
                          child: _selectedTabIndex == 2
                              ? _DiscoverResultCard(
                                  item: item,
                                  accentColor: _discoverAccent,
                                  accentGradient: _discoverGradient,
                                  isCenter: true,
                                  requestStatus: 'none',
                                  onTap: () {
                                    HapticFeedback.lightImpact();
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
                                          isCotrainrPartner:
                                              item.isCotrainrPartner,
                                          activeOfferTitle:
                                              item.activeOfferTitle,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : DiscoverProviderCard(
                                  data: DiscoverProviderCardData(
                                    id: item.id,
                                    name: item.name,
                                    roleLabel: item.roleLabel,
                                    headline: item.headline ??
                                        (item.specialtyChips.isEmpty
                                            ? null
                                            : item.specialtyChips.first),
                                    specialtyChips: item.specialtyChips,
                                    rating: item.rating,
                                    reviewCount: item.reviews,
                                    experienceYears: item.experienceYears,
                                    sessionModeLabels: item.sessionModes
                                        .map(
                                          (m) => ProviderSessionModes.labelFor(
                                            m,
                                            role: _selectedTabIndex == 0
                                                ? 'trainer'
                                                : 'nutritionist',
                                          ),
                                        )
                                        .toList(),
                                    distanceOrLocation: item.location.isEmpty
                                        ? null
                                        : item.location,
                                    verified: item.isVerified,
                                    offersOnline: item.offersOnline,
                                    avatarUrl: item.avatarUrl,
                                    requestStatus:
                                        _requestStatus[item.id] ?? 'none',
                                  ),
                                  accentColor: _discoverAccent,
                                  submitting:
                                      _submittingProviders.contains(item.id),
                                  planBadge: _selectedTabIndex == 1 &&
                                          !SubscriptionPlans
                                              .canConnectToNutritionist(
                                            _clientPlan,
                                          )
                                      ? SubscriptionPlans
                                          .nutritionistAccessPlansLabel
                                      : null,
                                  requestRequiresUpgrade:
                                      _selectedTabIndex == 1 &&
                                          !SubscriptionPlans
                                              .canConnectToNutritionist(
                                            _clientPlan,
                                          ),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    context.push(
                                      '/providers/${item.id}',
                                      extra: {
                                        'titleFallback': item.name,
                                        'providerType': _selectedTabIndex == 0
                                            ? 'trainer'
                                            : 'nutritionist',
                                      },
                                    );
                                  },
                                  onRequest: () => _sendRequest(item),
                                  onCancelRequest: () => _cancelRequest(item),
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
    final searching = _searchQuery.isNotEmpty;
    final filtered = _filters.hasActiveFilters;
    final isNutritionists = _selectedTabIndex == 1;
    final roleWord = isNutritionists ? 'nutritionists' : 'trainers';
    final String title;
    final String subtitle;
    VoidCallback? connectedCta;
    String? connectedCtaLabel;
    if (_selectedTabIndex == 2) {
      title = searching
          ? 'No partner centres match “$_searchQuery”'
          : 'No Partner Centres yet';
      subtitle = searching
          ? 'Try another name or city.'
          : 'Approved Cotrainr Partner Centres will appear here. Tap Become a Partner from Cotrainr Pass to apply.';
    } else if (searching) {
      title = 'No matches for “$_searchQuery”';
      subtitle = 'Try another name, specialty, or clear your search.';
    } else if (filtered) {
      title = 'No $roleWord match these filters';
      subtitle = 'Clear filters to see more results.';
    } else if (_requestStatus.values.any((s) => s == 'accepted')) {
      title = 'You’re connected with matching $roleWord';
      subtitle =
          'Connected providers appear in your ${isNutritionists ? 'Nutritionists' : 'Trainers'} list.';
      connectedCta = () => context.push(
            isNutritionists ? '/my-nutritionists' : '/my-trainers',
          );
      connectedCtaLabel =
          isNutritionists ? 'Open Nutritionists' : 'Open Trainers';
    } else {
      title = 'No matching $roleWord';
      subtitle =
          'Verified, discoverable $roleWord will appear here once they complete their profile.';
    }

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
              title,
              style: TextStyle(
                fontSize: DesignTokens.fontSizeH3,
                fontWeight: FontWeight.w700,
                color: DesignTokens.textPrimaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spacing8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: DesignTokens.fontSizeBodySmall,
                color: DesignTokens.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            if (connectedCta != null && connectedCtaLabel != null) ...[
              const SizedBox(height: DesignTokens.spacing16),
              FilledButton(
                onPressed: connectedCta,
                style: FilledButton.styleFrom(
                  backgroundColor: _discoverAccent,
                  foregroundColor: Colors.white,
                ),
                child: Text(connectedCtaLabel),
              ),
            ],
            if (filtered || searching) ...[
              const SizedBox(height: DesignTokens.spacing16),
              OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _filters = const DiscoverFilters();
                    _searchController.clear();
                    _searchQuery = '';
                  });
                  _loadRealData();
                },
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: const Text('Clear filters'),
              ),
            ],
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

class _LocationBrowseBanner extends StatelessWidget {
  final String message;
  final VoidCallback onOpenSettings;

  const _LocationBrowseBanner({
    required this.message,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DesignTokens.accentOrange.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: DesignTokens.accentOrange.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_off_rounded,
            size: 18,
            color: DesignTokens.accentOrange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DesignTokens.textPrimaryOf(context),
              ),
            ),
          ),
          TextButton(
            onPressed: onOpenSettings,
            child: const Text('Settings'),
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
        return 'Search nutritionists, specialties, or goals';
      case 2:
        return 'Search centers';
      default:
        return 'Search trainers, skills, or goals';
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
                  if (widget.item.experienceYears != null &&
                      widget.item.experienceYears! > 0) ...[
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
                          widget.item.experienceYears == 1
                              ? '1 year'
                              : '${widget.item.experienceYears} years',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        if (widget.item.offersOnline) ...[
                          const SizedBox(width: 10),
                          Icon(
                            Icons.videocam_outlined,
                            size: 12,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Online',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ] else if (widget.item.offersOnline) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.videocam_outlined,
                          size: 12,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Online',
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
                      Flexible(
                        child: Text(
                          widget.item.distance.isFinite
                              ? '${widget.item.distance.toStringAsFixed(1)} km'
                              : widget.item.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
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
              if (widget.item.isCotrainrPartner) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: DesignTokens.accentOrange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Cotrainr Partner',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: DesignTokens.accentOrange,
                      ),
                    ),
                  ],
                ),
              ],
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
              if (widget.item.activeOfferTitle != null &&
                  widget.item.activeOfferTitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: DesignTokens.accentOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Cotrainr Member Offer · ${widget.item.activeOfferTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.accentOrange,
                    ),
                  ),
                ),
              ],
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
                  Flexible(
                    child: Text(
                      widget.item.distance.isFinite
                          ? '${widget.item.distance.toStringAsFixed(1)} km'
                          : widget.item.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
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
  final String? headline;
  final List<String> specialtyChips;
  final String roleLabel;
  final double rating;
  final int reviews;
  final double distance;
  final String location;
  final bool isVerified;
  final String? avatarUrl;
  final int? experienceYears;
  final List<String> sessionModes;
  final bool offersOnline;
  final bool isCotrainrPartner;
  final String? activeOfferTitle;
  final String? googlePlaceId;

  DiscoverItem({
    required this.id,
    required this.name,
    required this.subtitle,
    this.headline,
    this.specialtyChips = const [],
    this.roleLabel = 'Trainer',
    required this.rating,
    required this.reviews,
    required this.distance,
    required this.location,
    required this.isVerified,
    required this.avatarUrl,
    this.experienceYears,
    this.sessionModes = const [],
    this.offersOnline = false,
    this.isCotrainrPartner = false,
    this.activeOfferTitle,
    this.googlePlaceId,
  });
}
