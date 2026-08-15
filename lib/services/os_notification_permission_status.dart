import 'package:permission_handler/permission_handler.dart' as ph;

enum OsNotificationAccessLabel {
  allowed,
  denied,
  permanentlyDenied,
  restricted,
  limited,
  notDetermined,
}

String osNotificationAccessLabelText(OsNotificationAccessLabel label) {
  switch (label) {
    case OsNotificationAccessLabel.allowed:
      return 'Allowed';
    case OsNotificationAccessLabel.denied:
      return 'Denied';
    case OsNotificationAccessLabel.permanentlyDenied:
      return 'Denied';
    case OsNotificationAccessLabel.restricted:
      return 'Restricted';
    case OsNotificationAccessLabel.limited:
      return 'Limited';
    case OsNotificationAccessLabel.notDetermined:
      return 'Not determined';
  }
}

OsNotificationAccessLabel mapOsNotificationAccess(ph.PermissionStatus status) {
  switch (status) {
    case ph.PermissionStatus.granted:
    case ph.PermissionStatus.provisional:
      return OsNotificationAccessLabel.allowed;
    case ph.PermissionStatus.denied:
      return OsNotificationAccessLabel.denied;
    case ph.PermissionStatus.permanentlyDenied:
      return OsNotificationAccessLabel.permanentlyDenied;
    case ph.PermissionStatus.restricted:
      return OsNotificationAccessLabel.restricted;
    case ph.PermissionStatus.limited:
      return OsNotificationAccessLabel.limited;
  }
}

/// OS notification permission — does not invent or override system state.
class OsNotificationPermissionGateway {
  const OsNotificationPermissionGateway();

  Future<ph.PermissionStatus> check() => ph.Permission.notification.status;

  Future<bool> openSystemSettings() => ph.openAppSettings();

  Future<OsNotificationAccessLabel> readLabel() async {
    final status = await check();
    return mapOsNotificationAccess(status);
  }

  /// Opens system settings so the user can change OS notification permission.
  Future<void> manage() async {
    await openSystemSettings();
  }
}
