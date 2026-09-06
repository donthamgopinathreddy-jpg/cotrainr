import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../services/nominatim_search_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import '../../utils/location_display_name_resolver.dart';

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

/// Full-screen OSM map picker for selecting a location only.
/// Returns [MapLocationPickerResult] on confirm, null on cancel/back.
///
/// Interaction model: tap-to-place marker (not center-pin).
class MapLocationPickerPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
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
  late final MapController _mapController;
  final _searchController = TextEditingController();
  final _nominatim = NominatimSearchService();
  final _displayNameResolver = LocationDisplayNameResolver();

  LatLng? _selectedPosition;
  String? _resolvedLabel;
  bool _isLoadingGps = false;
  bool _isResolvingLabel = false;
  bool _searching = false;
  String? _gpsError;
  String? _searchError;
  List<NominatimSearchResult> _searchResults = [];
  Timer? _searchDebounce;
  Timer? _reverseDebounce;
  int _resolveGeneration = 0;

  static const LatLng _defaultCenter = LatLng(17.3850, 78.4867);
  static const int _minSearchLength = 3;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedPosition = LatLng(widget.initialLat!, widget.initialLng!);
      _scheduleResolveLabel(_selectedPosition!);
    } else {
      _selectedPosition = _defaultCenter;
      _tryCenterOnUserLocation();
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _reverseDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
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
      if (!mounted || _selectedPosition != _defaultCenter) return;
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() => _selectedPosition = point);
      _mapController.move(point, widget.initialZoom);
      _scheduleResolveLabel(point);
    } catch (_) {
      // Keep default center.
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();
    if (query.length < _minSearchLength) {
      setState(() {
        _searchResults = [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    final captured = query;
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _performSearch(captured);
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      final results = await _nominatim.search(query);
      if (!mounted) return;
      if (_searchController.text.trim() != query) return; // stale
      setState(() {
        _searchResults = results;
        _searching = false;
        _searchError = results.isEmpty ? 'No places found' : null;
      });
    } catch (_) {
      if (!mounted) return;
      if (_searchController.text.trim() != query) return;
      setState(() {
        _searchResults = [];
        _searching = false;
        _searchError = 'Search failed. Try again or tap the map.';
      });
    }
  }

  void _onSearchResultSelected(NominatimSearchResult result) {
    HapticFeedback.lightImpact();
    final point = LatLng(result.lat, result.lon);
    setState(() {
      _selectedPosition = point;
      _resolvedLabel = result.displayName;
      _searchResults = [];
      _searchController.clear();
      _searchError = null;
      _isResolvingLabel = false;
    });
    _mapController.move(point, widget.initialZoom);
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedPosition = point;
      _searchResults = [];
    });
    _scheduleResolveLabel(point);
  }

  void _scheduleResolveLabel(LatLng point) {
    _reverseDebounce?.cancel();
    final generation = ++_resolveGeneration;
    setState(() => _isResolvingLabel = true);
    _reverseDebounce = Timer(const Duration(milliseconds: 450), () async {
      final label = await _displayNameResolver.resolve(
        point.latitude,
        point.longitude,
      );
      if (!mounted || generation != _resolveGeneration) return;
      setState(() {
        _resolvedLabel = label ?? 'Selected location';
        _isResolvingLabel = false;
      });
    });
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
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _selectedPosition = point;
        _isLoadingGps = false;
        _gpsError = null;
        _searchResults = [];
      });
      _mapController.move(point, widget.initialZoom);
      _scheduleResolveLabel(point);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingGps = false;
        _gpsError = 'Could not get location';
      });
    }
  }

  void _onConfirm() {
    final selected = _selectedPosition;
    if (selected == null) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      MapLocationPickerResult(
        lat: selected.latitude,
        lng: selected.longitude,
        addressLabel: _resolvedLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor:
          isDark ? DesignTokens.darkBackground : DesignTokens.lightBackground,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'Select location',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search location',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchResults = [];
                                    _searchError = null;
                                  });
                                },
                              )
                            : null),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.55),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_searchError != null && _searchResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _searchError!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                if (_searchResults.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(12),
                      color: colorScheme.surface,
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _searchResults.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final r = _searchResults[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.place_outlined,
                              color: AppColors.orange,
                            ),
                            title: Text(
                              r.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            onTap: () => _onSearchResultSelected(r),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
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
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                              color: AppColors.orange,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'map_picker_my_location',
                    onPressed: _isLoadingGps ? null : _useCurrentLocation,
                    backgroundColor: colorScheme.surface,
                    child: _isLoadingGps
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.orange,
                            ),
                          )
                        : Icon(
                            Icons.my_location_rounded,
                            color: AppColors.orange,
                          ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Material(
              elevation: 8,
              color: colorScheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isResolvingLabel)
                        Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.orange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Resolving place name...',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        )
                      else if (_resolvedLabel != null)
                        Text(
                          _resolvedLabel!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      if (_selectedPosition != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedPosition!.latitude.toStringAsFixed(5)}, '
                          '${_selectedPosition!.longitude.toStringAsFixed(5)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                      if (_gpsError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _gpsError!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed:
                            _selectedPosition == null ? null : _onConfirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Confirm location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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
  }
}
