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

/// Single-page Service Locations: list on top, add/edit form inline below.
/// No separate screens for add/edit or map picker.
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
          slivers: [
            SliverAppBar(
              expandedHeight: 100,
              pinned: true,
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
                title: Text(
                  'Service Locations',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              AppColors.purple.withValues(alpha: 0.15),
                              AppColors.blue.withValues(alpha: 0.08),
                            ]
                          : [
                              AppColors.purple.withValues(alpha: 0.08),
                              AppColors.blue.withValues(alpha: 0.04),
                            ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Your Locations',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.textSecondaryOf(context),
                  ),
                ),
              ),
            ),
            if (locations.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? DesignTokens.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_off_rounded, size: 40, color: AppColors.purple.withValues(alpha: 0.6)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'No locations yet. Add one below.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: DesignTokens.textSecondaryOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LocationCard(
                        location: locations[index],
                        onEdit: () => _startEdit(locations[index]),
                        onDelete: () => _deleteLocation(context, ref, locations[index].id),
                        onToggleActive: (isActive) =>
                            _toggleActive(context, ref, locations[index].id, isActive),
                        onSetPrimary: () => _setPrimary(context, ref, locations[index].id),
                      ),
                    ),
                    childCount: locations.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: _buildAddForm(context, colorScheme, isDark),
            ),
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

  Widget _buildAddForm(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Form(
      key: _formKey,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_location_alt_rounded, color: AppColors.purple, size: 24),
                const SizedBox(width: 10),
                Text(
                  _editingLocation == null ? 'Add Location' : 'Edit Location',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (_editingLocation != null) ...[
                  const Spacer(),
                  TextButton(
                    onPressed: _clearForm,
                    child: Text('Cancel', style: TextStyle(color: AppColors.purple)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _displayNameController,
              decoration: InputDecoration(
                labelText: 'Display name',
                hintText: 'e.g., Gachibowli Gym',
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Text(
              'Location type',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: LocationType.values.map((type) {
                final sel = _selectedType == type;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedType = type;
                      if (type == LocationType.home) _isPublicExact = false;
                    });
                    HapticFeedback.selectionClick();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: sel ? AppColors.distanceGradient : null,
                      color: sel ? null : colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? Colors.transparent : colorScheme.outline.withValues(alpha: 0.3),
                        width: sel ? 0 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(type.icon, size: 16, color: sel ? Colors.white : colorScheme.onSurface),
                        const SizedBox(width: 6),
                        Text(
                          type.displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Service radius',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [2.0, 5.0, 10.0, 15.0, 20.0].map((r) {
                final sel = _radiusKm == r;
                return GestureDetector(
                  onTap: () {
                    setState(() => _radiusKm = r);
                    HapticFeedback.selectionClick();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: sel ? AppColors.distanceGradient : null,
                      color: sel ? null : colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? Colors.transparent : colorScheme.outline.withValues(alpha: 0.3),
                        width: sel ? 0 : 1,
                      ),
                    ),
                    child: Text(
                      '${r.toStringAsFixed(0)} km',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Pick on map',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 200,
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
                          width: 40,
                          height: 40,
                          child: Icon(Icons.location_on_rounded, size: 40, color: AppColors.purple),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoadingLocation ? null : _useCurrentLocation,
                    icon: _isLoadingLocation
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purple),
                          )
                        : const Icon(Icons.my_location_rounded, size: 20),
                    label: Text(_isLoadingLocation ? '...' : 'Use my location'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: AppColors.purple.withValues(alpha: 0.6)),
                      foregroundColor: AppColors.purple,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _latitudeController.text.isEmpty
                        ? 'Tap map or use location'
                        : '${_latitudeController.text}, ${_longitudeController.text}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: DesignTokens.textSecondaryOf(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (_selectedType != LocationType.home) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Show exact location',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
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
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 18, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Home locations hide exact coordinates for privacy',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: (_isSaving || !_isFormValid) ? null : _saveLocation,
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: (_isSaving || !_isFormValid) ? null : AppColors.distanceGradient,
                    color: (_isSaving || !_isFormValid)
                        ? DesignTokens.textTertiaryOf(context)
                        : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _isFormValid && !_isSaving
                        ? [
                            BoxShadow(
                              color: AppColors.purple.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _editingLocation == null ? 'Add Location' : 'Save Changes',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? DesignTokens.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
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
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                      child: Icon(
                        widget.location.locationType.icon,
                        color: AppColors.purple,
                        size: 22,
                      ),
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
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (widget.location.isPrimary)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.distanceGradient,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'PRIMARY',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.location.locationType.displayName} • ${widget.location.radiusKm.toStringAsFixed(0)} km',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
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
                const SizedBox(height: 14),
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.star_outline_rounded,
                          label: 'Primary',
                          onTap: widget.onSetPrimary,
                        ),
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
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
