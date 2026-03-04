import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/provider_location_model.dart';
import '../../../providers/provider_locations_provider.dart';
import '../../../services/nominatim_search_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/design_tokens.dart';

/// Service Locations: single-page design with hero, list, and inline add/edit form.
class ServiceLocationsPage extends ConsumerStatefulWidget {
  const ServiceLocationsPage({super.key});

  @override
  ConsumerState<ServiceLocationsPage> createState() => _ServiceLocationsPageState();
}

class _ServiceLocationsPageState extends ConsumerState<ServiceLocationsPage> {
  final _formKey = GlobalKey<FormState>();
  final _formKeyGlobal = GlobalKey();
  final _displayNameController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _searchController = TextEditingController();

  LocationType _selectedType = LocationType.gym;
  double _radiusKm = 5.0;
  bool _isPublicExact = false;
  bool _isSaving = false;
  bool _isLoadingLocation = false;
  bool _isLoadingPlaceName = false;
  ProviderLocation? _editingLocation;
  late MapController _mapController;

  bool _userEditedDisplayName = false;
  LatLng? _lastReverseGeocodedPoint;
  Timer? _reverseGeocodeDebounceTimer;

  List<NominatimSearchResult> _searchResults = [];
  bool _searching = false;
  Timer? _searchDebounceTimer;
  final _nominatimService = NominatimSearchService();

  static const LatLng _defaultCenter = LatLng(17.3850, 78.4867);
  static const double _minDistanceForReverseGeocodeMeters = 20;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _displayNameController.addListener(_onFormChanged);
    _latitudeController.addListener(_onFormChanged);
    _longitudeController.addListener(_onFormChanged);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();
    final query = _searchController.text.trim();
    if (query.length < 3) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final results = await _nominatimService.search(query);
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _searching = false;
    });
  }

  void _onSearchResultSelected(NominatimSearchResult result) {
    HapticFeedback.lightImpact();
    setState(() {
      _latitudeController.text = result.lat.toStringAsFixed(6);
      _longitudeController.text = result.lon.toStringAsFixed(6);
      _displayNameController.text = result.displayName;
      _userEditedDisplayName = false;
      _searchResults = [];
      _searchController.clear();
    });
    _mapController.move(LatLng(result.lat, result.lon), 14);
  }

  void _onFormChanged() => setState(() {});

  void _startEdit(ProviderLocation loc) {
    setState(() {
      _editingLocation = loc;
      _displayNameController.text = loc.displayName;
      _latitudeController.text = loc.latitude.toStringAsFixed(6);
      _longitudeController.text = loc.longitude.toStringAsFixed(6);
      _searchController.clear();
      _searchResults = [];
      _selectedType = loc.locationType;
      _radiusKm = loc.radiusKm;
      _isPublicExact = loc.isPublicExact;
      _userEditedDisplayName = false;
      _lastReverseGeocodedPoint = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(LatLng(loc.latitude, loc.longitude), 14);
        _scrollToForm();
      }
    });
  }

  void _clearForm() {
    setState(() {
      _editingLocation = null;
      _displayNameController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      _searchController.clear();
      _searchResults = [];
      _selectedType = LocationType.gym;
      _radiusKm = 5.0;
      _isPublicExact = false;
      _userEditedDisplayName = false;
      _lastReverseGeocodedPoint = null;
    });
  }

  void _scrollToForm() {
    final ctx = _formKeyGlobal.currentContext;
    if (ctx != null && mounted) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.3,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  bool get _hasValidCoords {
    final lat = double.tryParse(_latitudeController.text);
    final lng = double.tryParse(_longitudeController.text);
    if (lat == null || lng == null) return false;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
    return true;
  }

  bool get _isFormValid {
    if (_displayNameController.text.trim().isEmpty) return false;
    return _hasValidCoords;
  }

  Future<void> _useCurrentLocation() async {
    HapticFeedback.lightImpact();
    setState(() => _isLoadingLocation = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          setState(() => _isLoadingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          setState(() => _isLoadingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (mounted) {
        setState(() {
          _latitudeController.text = pos.latitude.toStringAsFixed(6);
          _longitudeController.text = pos.longitude.toStringAsFixed(6);
          _isLoadingLocation = false;
        });
        _mapController.move(LatLng(pos.latitude, pos.longitude), 14);
        _scheduleReverseGeocode(pos.latitude, pos.longitude);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    HapticFeedback.lightImpact();
    setState(() {
      _latitudeController.text = point.latitude.toStringAsFixed(6);
      _longitudeController.text = point.longitude.toStringAsFixed(6);
      _searchResults = [];
    });
    _scheduleReverseGeocode(point.latitude, point.longitude);
  }

  void _scheduleReverseGeocode(double lat, double lng) {
    _reverseGeocodeDebounceTimer?.cancel();
    _reverseGeocodeDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_userEditedDisplayName) return;
      final last = _lastReverseGeocodedPoint;
      if (last != null) {
        final dist = Geolocator.distanceBetween(
          last.latitude, last.longitude, lat, lng,
        );
        if (dist < _minDistanceForReverseGeocodeMeters) return;
      }
      _updateDisplayNameFromCoords(lat, lng);
    });
  }

  /// Reverse geocode lat/lng to place/area name and update display name field
  Future<void> _updateDisplayNameFromCoords(double lat, double lng) async {
    if (!mounted || _userEditedDisplayName) return;
    setState(() => _isLoadingPlaceName = true);
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (!mounted) return;
      if (placemarks.isEmpty) {
        await _updateDisplayNameFromNominatim(lat, lng);
        return;
      }
      final p = placemarks.first;
      // Collect all non-empty placemark fields, avoiding duplicates (order: most specific first)
      final seen = <String>{};
      final parts = <String>[];
      for (final value in [
        p.name,
        p.street,
        p.thoroughfare,
        p.subLocality,
        p.locality,
        p.subAdministrativeArea,
        p.administrativeArea,
        p.country,
      ]) {
        if (value != null && value.trim().isNotEmpty && !seen.contains(value.trim())) {
          seen.add(value.trim());
          parts.add(value.trim());
        }
      }
      if (parts.isNotEmpty && mounted && !_userEditedDisplayName) {
        setState(() {
          _displayNameController.text = parts.join(', ');
          _isLoadingPlaceName = false;
          _lastReverseGeocodedPoint = LatLng(lat, lng);
        });
      } else if (mounted) {
        await _updateDisplayNameFromNominatim(lat, lng);
      }
    } catch (_) {
      // Platform geocoding failed - try OpenStreetMap Nominatim as fallback
      if (mounted) {
        await _updateDisplayNameFromNominatim(lat, lng);
      }
    }
  }

  /// Fallback: use OpenStreetMap Nominatim when platform geocoding fails
  Future<void> _updateDisplayNameFromNominatim(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'Cotrainr/1.0 (contact@cotrainr.com)'},
      );
      if (!mounted || response.statusCode != 200) {
        if (mounted) {
          setState(() {
            _displayNameController.text = 'Selected location';
            _isLoadingPlaceName = false;
          });
        }
        return;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final address = json['address'] as Map<String, dynamic>?;
      if (address == null) {
        if (mounted) {
          setState(() {
            _displayNameController.text = 'Selected location';
            _isLoadingPlaceName = false;
          });
        }
        return;
      }
      // Nominatim returns: suburb, neighbourhood, village, town, city, municipality, state, country
      final parts = <String>[];
      for (final key in [
        'suburb',
        'neighbourhood',
        'village',
        'town',
        'city',
        'municipality',
        'state',
        'country',
      ]) {
        final v = address[key];
        if (v is String && v.trim().isNotEmpty && !parts.contains(v.trim())) {
          parts.add(v.trim());
        }
      }
      final name = parts.isNotEmpty ? parts.join(', ') : 'Selected location';
      if (mounted && !_userEditedDisplayName) {
        setState(() {
          _displayNameController.text = name;
          _isLoadingPlaceName = false;
          _lastReverseGeocodedPoint = LatLng(lat, lng);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _displayNameController.text = 'Selected location';
          _isLoadingPlaceName = false;
        });
      }
    }
  }

  LatLng get _mapCenter {
    final lat = double.tryParse(_latitudeController.text);
    final lng = double.tryParse(_longitudeController.text);
    if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
      return LatLng(lat, lng);
    }
    return _defaultCenter;
  }

  Future<void> _saveLocation() async {
    if (!_formKey.currentState!.validate() || !_isFormValid) return;
    final lat = double.tryParse(_latitudeController.text)!;
    final lng = double.tryParse(_longitudeController.text)!;
    if (_selectedType == LocationType.home) _isPublicExact = false;

    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final location = ProviderLocation(
        id: _editingLocation?.id ?? '',
        providerId: userId,
        locationType: _selectedType,
        displayName: _displayNameController.text.trim(),
        latitude: lat,
        longitude: lng,
        radiusKm: _radiusKm,
        isPublicExact: _isPublicExact,
        isActive: _editingLocation?.isActive ?? true,
        isPrimary: _editingLocation?.isPrimary ?? false,
        createdAt: _editingLocation?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(providerLocationsProvider.notifier).upsertLocation(location);
      if (mounted) {
        HapticFeedback.mediumImpact();
        _clearForm();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location saved ✓'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save location'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _reverseGeocodeDebounceTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _displayNameController.removeListener(_onFormChanged);
    _latitudeController.removeListener(_onFormChanged);
    _longitudeController.removeListener(_onFormChanged);
    _searchController.removeListener(_onSearchChanged);
    _displayNameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locationsAsync = ref.watch(providerLocationsProvider);

    return Scaffold(
      backgroundColor: isDark ? DesignTokens.darkBackground : DesignTokens.lightBackground,
      body: locationsAsync.when(
        data: (locations) => CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildHeroAppBar(context, colorScheme, isDark),
            if (locations.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: _SectionHeader(
                    title: 'Your Locations',
                    count: locations.length,
                    icon: Icons.place_rounded,
                  ),
                ),
              ),
            if (locations.isEmpty)
              SliverToBoxAdapter(
                child: _buildEmptyState(context, isDark),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 350 + (index * 50)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          _LocationCard(
                            location: locations[index],
                            onEdit: () => _startEdit(locations[index]),
                            onDelete: () => _deleteLocation(context, ref, locations[index].id),
                            onToggleActive: (isActive) =>
                                _toggleActive(context, ref, locations, locations[index].id, isActive),
                            onSetPrimary: () => _setPrimary(context, ref, locations[index].id),
                          ),
                          if (index < locations.length - 1)
                            Divider(
                              height: 1,
                              indent: 0,
                              endIndent: 0,
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                            ),
                        ],
                      ),
                    ),
                    childCount: locations.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: _SectionHeader(
                  title: _editingLocation == null ? 'Add New Location' : 'Edit Location',
                  icon: Icons.add_location_alt_rounded,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildAddForm(context, colorScheme, isDark),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
        loading: () => Column(
          children: [
            _buildAppBar(context, colorScheme, isDark),
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purple),
              ),
            ),
          ],
        ),
        error: (error, stack) => Column(
          children: [
            _buildAppBar(context, colorScheme, isDark),
            Expanded(child: _buildError(context, ref, error)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return SliverAppBar(
      expandedHeight: 110,
      pinned: true,
      stretch: true,
      backgroundColor: colorScheme.surface,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface, size: 22),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
        title: Text(
          'Service Locations',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: colorScheme.onSurface,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          AppColors.purple.withValues(alpha: 0.2),
                          AppColors.blue.withValues(alpha: 0.08),
                          colorScheme.surface,
                        ]
                      : [
                          AppColors.purple.withValues(alpha: 0.08),
                          AppColors.blue.withValues(alpha: 0.04),
                          colorScheme.surface,
                        ],
                ),
              ),
            ),
            Positioned(
              right: -40,
              top: -30,
              child: Icon(
                Icons.location_on_outlined,
                size: 160,
                color: AppColors.purple.withValues(alpha: isDark ? 0.06 : 0.04),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.add_location_alt_rounded,
            size: 48,
            color: AppColors.purple.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 20),
          Text(
            'No locations yet',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: DesignTokens.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a service location so clients can discover you nearby.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.5,
              color: DesignTokens.textSecondaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAddForm(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return KeyedSubtree(
      key: _formKeyGlobal,
      child: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_editingLocation != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _clearForm,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Cancel'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.purple,
                      ),
                    ),
                  ],
                ),
              ),
            _FormSection(
              label: 'Location type',
              icon: Icons.category_outlined,
              child: DropdownButtonFormField<LocationType>(
                // ignore: deprecated_member_use - value required for controlled dropdown
                value: _selectedType,
                decoration: _inputDecoration(context, 'Select type').copyWith(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: LocationType.values.map((type) => DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(type.icon, size: 20, color: AppColors.purple),
                      const SizedBox(width: 12),
                      Text(type.displayName),
                    ],
                  ),
                )).toList(),
                onChanged: (type) {
                  if (type != null) {
                    setState(() {
                      _selectedType = type;
                      if (type == LocationType.home) _isPublicExact = false;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
            _FormSection(
              label: 'Pick on map',
              subtitle: 'Search, tap the map, or use your current location — display name auto-fills',
              icon: Icons.map_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LocationSearchBar(
                    controller: _searchController,
                    searching: _searching,
                    results: _searchResults,
                    colorScheme: colorScheme,
                    onResultSelected: _onSearchResultSelected,
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      height: 200,
                      child: RepaintBoundary(
                        child: _LocationMapPicker(
                          center: _mapCenter,
                          radiusKm: _radiusKm,
                          mapController: _mapController,
                          onTap: _onMapTap,
                        ),
                      ),
                    ),
                  ),
                  if (!_hasValidCoords)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Pick a location on the map',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.red,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingLocation ? null : _useCurrentLocation,
                      icon: _isLoadingLocation
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.purple,
                              ),
                            )
                          : const Icon(Icons.my_location_rounded, size: 20),
                      label: Text(_isLoadingLocation ? 'Getting...' : 'Use my location'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppColors.purple.withValues(alpha: 0.6)),
                        foregroundColor: AppColors.purple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _FormSection(
              label: 'Display name',
              icon: Icons.badge_outlined,
              subtitle: 'Tap map or use location — place/area name auto-fills',
              child: TextFormField(
                controller: _displayNameController,
                readOnly: _isLoadingPlaceName,
                onChanged: (_) => setState(() => _userEditedDisplayName = true),
                decoration: _inputDecoration(
                  context,
                  _isLoadingPlaceName ? 'Fetching place name...' : 'Place or area name',
                ).copyWith(
                  suffixIcon: _isLoadingPlaceName
                      ? const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Display name is required' : null,
              ),
            ),
            const SizedBox(height: 24),
            _FormSection(
              label: 'Service coverage radius',
              subtitle: 'Clients within this distance can discover you.',
              icon: Icons.radar_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      activeTrackColor: AppColors.purple,
                      inactiveTrackColor: colorScheme.outline.withValues(alpha: 0.3),
                      thumbColor: AppColors.purple,
                      overlayColor: AppColors.purple.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _radiusKm.clamp(2.0, 50.0),
                      min: 2,
                      max: 50,
                      divisions: 48,
                      onChanged: (v) {
                        setState(() => _radiusKm = v);
                        HapticFeedback.selectionClick();
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${_radiusKm.toStringAsFixed(0)} km',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.purple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Show exact location',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          _selectedType == LocationType.home
                              ? 'Home locations always hide exact coordinates for privacy.'
                              : 'Allow others to see coordinates',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isPublicExact,
                    onChanged: _selectedType == LocationType.home
                        ? null
                        : (v) {
                            setState(() => _isPublicExact = v);
                            HapticFeedback.selectionClick();
                          },
                    activeTrackColor: AppColors.purple.withValues(alpha: 0.5),
                    thumbColor: WidgetStateProperty.resolveWith((s) =>
                        s.contains(WidgetState.selected) ? AppColors.purple : null),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: (_isSaving || !_isFormValid) ? null : _saveLocation,
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: (_isSaving || !_isFormValid) ? null : AppColors.distanceGradient,
                    color: (_isSaving || !_isFormValid)
                        ? DesignTokens.textTertiaryOf(context)
                        : null,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: _isFormValid && !_isSaving
                        ? [
                            BoxShadow(
                              color: AppColors.purple.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                            BoxShadow(
                              color: AppColors.blue.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _editingLocation == null ? 'Add Location' : 'Save Changes',
                            style: GoogleFonts.poppins(
                              fontSize: 17,
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
      ),
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String hint) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Service Locations',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppColors.purple.withValues(alpha: 0.12),
                    AppColors.blue.withValues(alpha: 0.06),
                  ]
                : [
                    AppColors.purple.withValues(alpha: 0.06),
                    AppColors.blue.withValues(alpha: 0.03),
                  ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: AppColors.red),
            const SizedBox(height: 20),
            Text(
              'Error Loading Locations',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: DesignTokens.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              error.toString(),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: DesignTokens.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => ref.refresh(providerLocationsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteLocation(
    BuildContext context,
    WidgetRef ref,
    String locationId,
  ) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Location'),
        content: const Text('Are you sure you want to delete this location?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(providerLocationsProvider.notifier).deleteLocation(locationId);
        if (_editingLocation?.id == locationId) _clearForm();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location deleted'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: ${e.toString()}'),
              backgroundColor: AppColors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    List<ProviderLocation> locations,
    String locationId,
    bool newValue,
  ) async {
    // newValue is the value after toggle; when false, user is deactivating
    if (!newValue) {
      final activeCount = locations.where((l) => l.isActive).length;
      if (activeCount <= 1) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Disable Location'),
            content: const Text(
              'Disabling this location will remove you from discovery. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.red),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
      }
    }
    try {
      await ref.read(providerLocationsProvider.notifier).setActive(locationId, newValue);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: ${e.toString()}'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _setPrimary(
    BuildContext context,
    WidgetRef ref,
    String locationId,
  ) async {
    HapticFeedback.lightImpact();
    try {
      await ref.read(providerLocationsProvider.notifier).setPrimary(locationId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Primary location updated'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set primary: ${e.toString()}'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.purple.withValues(alpha: 0.22),
                AppColors.blue.withValues(alpha: 0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.purple.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.purple, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: DesignTokens.textPrimaryOf(context),
            ),
          ),
        ),
        if (count != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.purple.withValues(alpha: 0.2),
                  AppColors.blue.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.purple.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.purple,
              ),
            ),
          ),
      ],
    );
  }
}

class _LocationSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool searching;
  final List<NominatimSearchResult> results;
  final ColorScheme colorScheme;
  final void Function(NominatimSearchResult) onResultSelected;

  const _LocationSearchBar({
    required this.controller,
    required this.searching,
    required this.results,
    required this.colorScheme,
    required this.onResultSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Search location',
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppColors.purple.withValues(alpha: 0.8),
            ),
            suffixIcon: searching
                ? const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            filled: true,
            fillColor: colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
        if (results.isNotEmpty) ...[
          const SizedBox(height: 8),
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(16),
            color: colorScheme.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: results.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
                itemBuilder: (context, index) {
                  final r = results[index];
                  return ListTile(
                    leading: Icon(
                      Icons.place_outlined,
                      size: 22,
                      color: AppColors.purple,
                    ),
                    title: Text(
                      r.displayName,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onResultSelected(r),
                  );
                },
              ),
            ),
          ),
        ] else if (controller.text.trim().length >= 3 && !searching) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'No results',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Isolated map widget to reduce rebuilds on parent state changes.
class _LocationMapPicker extends StatefulWidget {
  final LatLng center;
  final double radiusKm;
  final MapController mapController;
  final void Function(TapPosition position, LatLng point) onTap;

  const _LocationMapPicker({
    required this.center,
    required this.radiusKm,
    required this.mapController,
    required this.onTap,
  });

  @override
  State<_LocationMapPicker> createState() => _LocationMapPickerState();
}

class _LocationMapPickerState extends State<_LocationMapPicker> {
  @override
  Widget build(BuildContext context) {
    final radiusMeters = widget.radiusKm * 1000;
    return FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: 14,
        onTap: widget.onTap,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.cotrainr.app',
        ),
        CircleLayer(
          circles: [
            CircleMarker(
              point: widget.center,
              radius: radiusMeters,
              useRadiusInMeter: true,
              color: AppColors.purple.withValues(alpha: 0.15),
              borderStrokeWidth: 2,
              borderColor: AppColors.purple.withValues(alpha: 0.5),
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: widget.center,
              width: 48,
              height: 48,
              child: Icon(
                Icons.location_on_rounded,
                size: 48,
                color: AppColors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FormSection extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final Widget child;

  const _FormSection({
    required this.label,
    this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.purple.withValues(alpha: 0.8)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: DesignTokens.textPrimaryOf(context),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: DesignTokens.textSecondaryOf(context),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _LocationCard extends StatefulWidget {
  final ProviderLocation location;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onSetPrimary;

  const _LocationCard({
    required this.location,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onSetPrimary,
  });

  @override
  State<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<_LocationCard> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    widget.location.locationType.icon,
                    color: AppColors.purple,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.location.displayName,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (widget.location.isPrimary)
                              Text(
                                'Primary',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.purple,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.location.locationType.displayName} • ${widget.location.radiusKm.toStringAsFixed(0)} km radius',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: DesignTokens.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: widget.location.isActive,
                    onChanged: widget.onToggleActive,
                    activeTrackColor: AppColors.purple.withValues(alpha: 0.5),
                    thumbColor: WidgetStateProperty.resolveWith((s) =>
                        s.contains(WidgetState.selected) ? AppColors.purple : null),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _ActionButton(
                    icon: Icons.edit_rounded,
                    label: 'Edit',
                    onTap: widget.onEdit,
                  ),
                  if (!widget.location.isPrimary) ...[
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: Icons.star_outline_rounded,
                      label: 'Set Primary',
                      onTap: widget.onSetPrimary,
                    ),
                  ],
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    onTap: widget.onDelete,
                    isDestructive: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.red : AppColors.purple;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDestructive ? 0.1 : 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
