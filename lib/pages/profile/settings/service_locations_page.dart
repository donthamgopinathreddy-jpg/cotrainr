import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/provider_location_model.dart';
import '../../../providers/provider_locations_provider.dart';
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
  final _displayNameController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  LocationType _selectedType = LocationType.gym;
  double _radiusKm = 5.0;
  bool _isPublicExact = false;
  bool _isSaving = false;
  bool _isLoadingLocation = false;
  ProviderLocation? _editingLocation;
  late MapController _mapController;

  static const LatLng _defaultCenter = LatLng(17.3850, 78.4867);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _displayNameController.addListener(_onFormChanged);
    _latitudeController.addListener(_onFormChanged);
    _longitudeController.addListener(_onFormChanged);
  }

  void _onFormChanged() => setState(() {});

  void _startEdit(ProviderLocation loc) {
    setState(() {
      _editingLocation = loc;
      _displayNameController.text = loc.displayName;
      _latitudeController.text = loc.latitude.toStringAsFixed(6);
      _longitudeController.text = loc.longitude.toStringAsFixed(6);
      _selectedType = loc.locationType;
      _radiusKm = loc.radiusKm;
      _isPublicExact = loc.isPublicExact;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(LatLng(loc.latitude, loc.longitude), 14);
      }
    });
  }

  void _clearForm() {
    setState(() {
      _editingLocation = null;
      _displayNameController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      _selectedType = LocationType.gym;
      _radiusKm = 5.0;
      _isPublicExact = false;
    });
  }

  bool get _isFormValid {
    if (_displayNameController.text.trim().isEmpty) return false;
    final lat = double.tryParse(_latitudeController.text);
    final lng = double.tryParse(_longitudeController.text);
    if (lat == null || lng == null) return false;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
    return true;
  }

  Future<void> _useCurrentLocation() async {
    HapticFeedback.lightImpact();
    setState(() => _isLoadingLocation = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
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
    });
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
            content: Text(_editingLocation == null ? 'Location added' : 'Location updated'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
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
    _displayNameController.removeListener(_onFormChanged);
    _latitudeController.removeListener(_onFormChanged);
    _longitudeController.removeListener(_onFormChanged);
    _displayNameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: _SectionHeader(
                  title: 'Your Locations',
                  count: locations.length,
                  icon: Icons.location_on_rounded,
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
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _LocationCard(
                          location: locations[index],
                          onEdit: () => _startEdit(locations[index]),
                          onDelete: () => _deleteLocation(context, ref, locations[index].id),
                          onToggleActive: (isActive) =>
                              _toggleActive(context, ref, locations[index].id, isActive),
                          onSetPrimary: () => _setPrimary(context, ref, locations[index].id),
                        ),
                      ),
                    ),
                    childCount: locations.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: _SectionHeader(
                  title: _editingLocation == null ? 'Add New Location' : 'Edit Location',
                  icon: Icons.add_road_rounded,
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
      expandedHeight: 160,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface, size: 22),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 20),
        title: Text(
          'Service Locations',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
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
                          AppColors.blue.withValues(alpha: 0.1),
                          AppColors.purple.withValues(alpha: 0.05),
                        ]
                      : [
                          AppColors.purple.withValues(alpha: 0.12),
                          AppColors.blue.withValues(alpha: 0.06),
                          Colors.white.withValues(alpha: 0.5),
                        ],
                ),
              ),
            ),
            Positioned(
              right: -20,
              top: -20,
              child: Opacity(
                opacity: isDark ? 0.15 : 0.2,
                child: Icon(
                  Icons.map_rounded,
                  size: 140,
                  color: AppColors.purple,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.purple.withValues(alpha: 0.15),
                    AppColors.blue.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_location_alt_rounded,
                size: 48,
                color: AppColors.purple,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No locations yet',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: DesignTokens.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add gyms, studios, or home locations\nwhere you provide services',
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.5,
                color: DesignTokens.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddForm(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Form(
      key: _formKey,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
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
              label: 'Display name',
              icon: Icons.badge_outlined,
              child: TextFormField(
                controller: _displayNameController,
                decoration: _inputDecoration(
                  context,
                  'e.g., Gachibowli Gym, Downtown Studio',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
            const SizedBox(height: 24),
            _FormSection(
              label: 'Location type',
              icon: Icons.category_outlined,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: LocationType.values.map((type) {
                  final sel = _selectedType == type;
                  return _SelectChip(
                    label: type.displayName,
                    icon: type.icon,
                    selected: sel,
                    onTap: () {
                      setState(() {
                        _selectedType = type;
                        if (type == LocationType.home) _isPublicExact = false;
                      });
                      HapticFeedback.selectionClick();
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            _FormSection(
              label: 'Service radius',
              icon: Icons.radar_outlined,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [2.0, 5.0, 10.0, 15.0, 20.0].map((r) {
                  final sel = _radiusKm == r;
                  return _SelectChip(
                    label: '${r.toStringAsFixed(0)} km',
                    selected: sel,
                    onTap: () {
                      setState(() => _radiusKm = r);
                      HapticFeedback.selectionClick();
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            _FormSection(
              label: 'Pick on map',
              subtitle: 'Tap the map or use your current location',
              icon: Icons.map_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.purple.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        height: 220,
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _mapCenter,
                            initialZoom: 14,
                            onTap: _onMapTap,
                            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.cotrainr.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _mapCenter,
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
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
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
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _latitudeController.text.isEmpty
                                ? 'Tap map or use location'
                                : '${_latitudeController.text}, ${_longitudeController.text}',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: DesignTokens.textSecondaryOf(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_selectedType != LocationType.home) ...[
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
                            'Allow others to see coordinates',
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
                      onChanged: (v) {
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
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 22, color: Colors.orange.shade700),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Home locations hide exact coordinates for privacy',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
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
    String locationId,
    bool isActive,
  ) async {
    try {
      await ref.read(providerLocationsProvider.notifier).setActive(locationId, !isActive);
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.purple.withValues(alpha: 0.2),
                AppColors.blue.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.purple, size: 22),
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: DesignTokens.textPrimaryOf(context),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.purple,
              ),
            ),
          ),
        ],
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

class _SelectChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _SelectChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.distanceGradient : null,
          color: selected ? null : colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : colorScheme.outline.withValues(alpha: 0.3),
            width: selected ? 0 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
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
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onEdit,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? DesignTokens.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.location.isPrimary
                    ? AppColors.purple
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
                width: widget.location.isPrimary ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.purple.withValues(alpha: 0.2),
                            AppColors.blue.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        widget.location.locationType.icon,
                        color: AppColors.purple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
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
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (widget.location.isPrimary)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.distanceGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'PRIMARY',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
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
                    Switch(
                      value: widget.location.isActive,
                      onChanged: widget.onToggleActive,
                      activeTrackColor: AppColors.purple.withValues(alpha: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.edit_rounded,
                        label: 'Edit',
                        onTap: widget.onEdit,
                      ),
                    ),
                    if (!widget.location.isPrimary) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.star_outline_rounded,
                          label: 'Set Primary',
                          onTap: widget.onSetPrimary,
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
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
    final color = isDestructive ? AppColors.red : DesignTokens.textSecondaryOf(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
