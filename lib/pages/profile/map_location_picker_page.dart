import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_colors.dart';

/// Result returned when user confirms a location.
class MapLocationPickerResult {
  final double lat;
  final double lng;
  final String? addressLabel;

  const MapLocationPickerResult({
    required this.lat,
    required this.lng,
    this.addressLabel,
  });

  LatLng toLatLng() => LatLng(lat, lng);
}

/// Full-screen map picker for selecting a location.
/// Returns [MapLocationPickerResult] on confirm, null on cancel.
class MapLocationPickerPage extends StatefulWidget {
  /// Initial center (e.g. existing location when editing)
  final double? initialLat;
  final double? initialLng;
  /// Optional: initial zoom level
  final double initialZoom;

  const MapLocationPickerPage({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialZoom = 14.0,
  });

  @override
  State<MapLocationPickerPage> createState() => _MapLocationPickerPageState();
}

class _MapLocationPickerPageState extends State<MapLocationPickerPage> {
  late MapController _mapController;
  LatLng? _selectedPosition;
  bool _isLoadingGps = false;
  String? _gpsError;

  static const LatLng _defaultCenter = LatLng(17.3850, 78.4867); // Hyderabad

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedPosition = LatLng(widget.initialLat!, widget.initialLng!);
    } else {
      _selectedPosition = _defaultCenter;
      _tryCenterOnUserLocation();
    }
  }

  Future<void> _tryCenterOnUserLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (mounted && _selectedPosition == _defaultCenter) {
        setState(() {
          _selectedPosition = LatLng(pos.latitude, pos.longitude);
        });
        _mapController.move(_selectedPosition!, widget.initialZoom);
      }
    } catch (_) {
      // Silently fall back to default center
    }
  }

  Future<void> _useCurrentLocation() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isLoadingGps = true;
      _gpsError = null;
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() {
          _isLoadingGps = false;
          _gpsError = 'Location services are disabled';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() {
          _isLoadingGps = false;
          _gpsError = 'Location permission denied';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      if (mounted) {
        setState(() {
          _selectedPosition = LatLng(pos.latitude, pos.longitude);
          _isLoadingGps = false;
          _gpsError = null;
        });
        _mapController.move(_selectedPosition!, widget.initialZoom);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGps = false;
          _gpsError = 'Could not get location';
        });
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedPosition = point;
    });
  }

  void _onConfirm() {
    HapticFeedback.mediumImpact();
    if (_selectedPosition != null) {
      Navigator.pop(
        context,
        MapLocationPickerResult(
          lat: _selectedPosition!.latitude,
          lng: _selectedPosition!.longitude,
        ),
      );
    }
  }

  void _onCancel() {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A0F2E) : const Color(0xFFF0EBFF),
      appBar: AppBar(
        title: const Text(
          'Pick Location',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _onCancel,
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPosition ?? _defaultCenter,
              initialZoom: widget.initialZoom,
              onTap: _onMapTap,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.cotrainr.app',
              ),
              if (_selectedPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPosition!,
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_selectedPosition != null)
                      Text(
                        '${_selectedPosition!.latitude.toStringAsFixed(6)}, ${_selectedPosition!.longitude.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'monospace',
                          color: colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isLoadingGps ? null : _useCurrentLocation,
                      icon: _isLoadingGps
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.purple,
                              ),
                            )
                          : const Icon(Icons.my_location_rounded, size: 20),
                      label: Text(_isLoadingGps ? 'Getting location...' : 'Use my current location'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: AppColors.purple.withValues(alpha: 0.6)),
                        foregroundColor: AppColors.purple,
                      ),
                    ),
                    if (_gpsError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _gpsError!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _onConfirm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.purple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Confirm Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
