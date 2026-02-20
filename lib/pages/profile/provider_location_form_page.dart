import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/provider_location_model.dart';
import '../../providers/provider_locations_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import 'map_location_picker_page.dart';

/// Form page for adding/editing provider locations
class ProviderLocationFormPage extends ConsumerStatefulWidget {
  final ProviderLocation? location;
  final VoidCallback onSaved;

  const ProviderLocationFormPage({
    super.key,
    this.location,
    required this.onSaved,
  });

  @override
  ConsumerState<ProviderLocationFormPage> createState() =>
      _ProviderLocationFormPageState();
}

class _ProviderLocationFormPageState
    extends ConsumerState<ProviderLocationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  LocationType _selectedType = LocationType.gym;
  double _radiusKm = 5.0;
  bool _isPublicExact = false;
  bool _isSaving = false;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    if (widget.location != null) {
      _displayNameController.text = widget.location!.displayName;
      _latitudeController.text = widget.location!.latitude.toStringAsFixed(6);
      _longitudeController.text = widget.location!.longitude.toStringAsFixed(6);
      _selectedType = widget.location!.locationType;
      _radiusKm = widget.location!.radiusKm;
      _isPublicExact = widget.location!.isPublicExact;
    }
    _displayNameController.addListener(_onFormChanged);
    _latitudeController.addListener(_onFormChanged);
    _longitudeController.addListener(_onFormChanged);
  }

  void _onFormChanged() => setState(() {});

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

  bool get _isFormValid {
    final name = _displayNameController.text.trim();
    if (name.isEmpty) return false;
    final lat = double.tryParse(_latitudeController.text);
    final lng = double.tryParse(_longitudeController.text);
    if (lat == null || lng == null) return false;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
    return true;
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

  Future<void> _saveLocation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate lat/lng
    final lat = double.tryParse(_latitudeController.text);
    final lng = double.tryParse(_longitudeController.text);

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid latitude or longitude'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (lat < -90 || lat > 90) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Latitude must be between -90 and 90'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (lng < -180 || lng > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Longitude must be between -180 and 180'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Enforce home location privacy
    if (_selectedType == LocationType.home) {
      _isPublicExact = false;
    }

    setState(() => _isSaving = true);

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final location = ProviderLocation(
        id: widget.location?.id ?? '',
        providerId: currentUserId,
        locationType: _selectedType,
        displayName: _displayNameController.text.trim(),
        latitude: lat,
        longitude: lng,
        radiusKm: _radiusKm,
        isPublicExact: _isPublicExact,
        isActive: widget.location?.isActive ?? true,
        isPrimary: widget.location?.isPrimary ?? false,
        createdAt: widget.location?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(providerLocationsProvider.notifier).upsertLocation(location);

      if (mounted) {
        HapticFeedback.mediumImpact();
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save location: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? DesignTokens.darkBackground : DesignTokens.lightBackground,
      appBar: AppBar(
        title: Text(
          widget.location == null ? 'Add Location' : 'Edit Location',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.purple.withValues(alpha: 0.1),
                AppColors.blue.withValues(alpha: 0.05),
              ],
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AnimatedSection(
                delay: 0,
                child: _FormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Display Name',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _displayNameController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Gachibowli, Downtown Gym',
                        filled: true,
                        fillColor: colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Display name is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              ),
              const SizedBox(height: 18),
              _AnimatedSection(
                delay: 60,
                child: _FormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location Type',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: LocationType.values.map((type) {
                        final isSelected = _selectedType == type;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedType = type;
                              // Enforce home privacy
                              if (type == LocationType.home) {
                                _isPublicExact = false;
                              }
                            });
                            HapticFeedback.selectionClick();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? AppColors.distanceGradient
                                  : null,
                              color: isSelected ? null : colorScheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : colorScheme.outline.withValues(alpha: 0.3),
                                width: isSelected ? 0 : 1,
                              ),
                              boxShadow: isSelected
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
                                Icon(
                                  type.icon,
                                  size: 18,
                                  color: isSelected
                                      ? Colors.white
                                      : colorScheme.onSurface,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  type.displayName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              ),
              const SizedBox(height: 18),
              _AnimatedSection(
                delay: 120,
                child: _FormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Radius',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [2.0, 5.0, 10.0, 15.0, 20.0].map((radius) {
                        final isSelected = _radiusKm == radius;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _radiusKm = radius);
                            HapticFeedback.selectionClick();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected ? AppColors.distanceGradient : null,
                              color: isSelected ? null : colorScheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : colorScheme.outline.withValues(alpha: 0.3),
                                width: isSelected ? 0 : 1,
                              ),
                            ),
                            child: Text(
                              '${radius.toStringAsFixed(0)} km',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              ),
              const SizedBox(height: 18),
              _AnimatedSection(
                delay: 180,
                child: _FormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the map to pick your service location.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final lat = double.tryParse(_latitudeController.text);
                              final lng = double.tryParse(_longitudeController.text);
                              final result = await Navigator.push<MapLocationPickerResult?>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MapLocationPickerPage(
                                    initialLat: lat,
                                    initialLng: lng,
                                  ),
                                ),
                              );
                              if (result != null && mounted) {
                                setState(() {
                                  _latitudeController.text =
                                      result.lat.toStringAsFixed(6);
                                  _longitudeController.text =
                                      result.lng.toStringAsFixed(6);
                                });
                              }
                            },
                            icon: const Icon(Icons.map_rounded, size: 20),
                            label: const Text('Pick on Map'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: AppColors.purple.withValues(alpha: 0.6),
                              ),
                              foregroundColor: AppColors.purple,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoadingLocation ? null : _useCurrentLocation,
                            icon: _isLoadingLocation
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.purple,
                                    ),
                                  )
                                : const Icon(Icons.my_location_rounded, size: 20),
                            label: Text(_isLoadingLocation ? '...' : 'Use my location'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: AppColors.purple.withValues(alpha: 0.6),
                              ),
                              foregroundColor: AppColors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latitudeController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Latitude',
                              filled: true,
                              fillColor: colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Pick location on map';
                              }
                              final lat = double.tryParse(value);
                              if (lat == null) return 'Invalid';
                              if (lat < -90 || lat > 90) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _longitudeController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Longitude',
                              filled: true,
                              fillColor: colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Pick location on map';
                              }
                              final lng = double.tryParse(value);
                              if (lng == null) return 'Invalid';
                              if (lng < -180 || lng > 180) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ),
              const SizedBox(height: 18),
              if (_selectedType != LocationType.home)
                _AnimatedSection(
                  delay: 240,
                  child: _FormCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Show Exact Location',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Allow others to see exact coordinates',
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
                        onChanged: (value) {
                          setState(() => _isPublicExact = value);
                          HapticFeedback.selectionClick();
                        },
                        activeTrackColor: AppColors.purple.withValues(alpha: 0.5),
                        thumbColor: WidgetStateProperty.resolveWith((states) =>
                            states.contains(WidgetState.selected)
                                ? AppColors.purple
                                : null),
                      ),
                    ],
                  ),
                ),
                )
              else
                _AnimatedSection(
                  delay: 240,
                  child: _FormCard(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 20,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Home locations always hide exact coordinates for privacy',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: DesignTokens.surfaceOf(context),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: AnimatedOpacity(
            opacity: _isFormValid ? 1 : 0.5,
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: (_isSaving || !_isFormValid) ? null : _saveLocation,
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: (_isSaving || !_isFormValid)
                        ? null
                        : AppColors.distanceGradient,
                    color: (_isSaving || !_isFormValid)
                        ? DesignTokens.textTertiaryOf(context)
                        : null,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: _isFormValid && !_isSaving
                        ? [
                            BoxShadow(
                              color: AppColors.purple.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
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
                            widget.location == null ? 'Add Location' : 'Save Changes',
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
          ),
        ),
      ),
    );
  }
}

class _AnimatedSection extends StatelessWidget {
  final int delay;
  final Widget child;

  const _AnimatedSection({required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + delay),
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
      child: child,
    );
  }
}

class _FormCard extends StatelessWidget {
  final Widget child;

  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? DesignTokens.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
