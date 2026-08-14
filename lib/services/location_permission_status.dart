import 'package:geolocator/geolocator.dart';

enum LocationAccessLabel {
  notRequested,
  denied,
  whileUsingApp,
  allowed,
  serviceOff,
}

String locationAccessLabelText(LocationAccessLabel label) {
  switch (label) {
    case LocationAccessLabel.notRequested:
      return 'Not requested';
    case LocationAccessLabel.denied:
      return 'Denied';
    case LocationAccessLabel.whileUsingApp:
      return 'While using app';
    case LocationAccessLabel.allowed:
      return 'Allowed';
    case LocationAccessLabel.serviceOff:
      return 'Off';
  }
}

LocationAccessLabel mapLocationAccess({
  required bool serviceEnabled,
  required LocationPermission permission,
}) {
  if (!serviceEnabled) return LocationAccessLabel.serviceOff;
  switch (permission) {
    case LocationPermission.denied:
      return LocationAccessLabel.notRequested;
    case LocationPermission.deniedForever:
      return LocationAccessLabel.denied;
    case LocationPermission.whileInUse:
      return LocationAccessLabel.whileUsingApp;
    case LocationPermission.always:
      return LocationAccessLabel.allowed;
    case LocationPermission.unableToDetermine:
      return LocationAccessLabel.notRequested;
  }
}

/// OS location permission for Discover / nearby / provider locations.
class LocationPermissionGateway {
  const LocationPermissionGateway();

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> check() => Geolocator.checkPermission();

  Future<LocationPermission> request() => Geolocator.requestPermission();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<LocationAccessLabel> readLabel() async {
    final enabled = await isServiceEnabled();
    final permission = await check();
    return mapLocationAccess(
      serviceEnabled: enabled,
      permission: permission,
    );
  }

  /// Request if still possible; otherwise open the matching system settings.
  Future<void> manage() async {
    final enabled = await isServiceEnabled();
    if (!enabled) {
      await openLocationSettings();
      return;
    }
    final permission = await check();
    if (permission == LocationPermission.denied) {
      await request();
      return;
    }
    await openAppSettings();
  }
}
