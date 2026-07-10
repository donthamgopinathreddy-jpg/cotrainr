import 'package:health/health.dart';

/// Status snapshot for Settings → Health Connect.
class HealthConnectSettingsInfo {
  final String platformLabel;
  final bool isAvailable;
  final HealthConnectSdkStatus? sdkStatus;
  final bool permissionsGranted;
  final bool isActiveSource;
  final String activeSourceLabel;
  final Map<String, bool> typePermissions;

  const HealthConnectSettingsInfo({
    required this.platformLabel,
    required this.isAvailable,
    this.sdkStatus,
    required this.permissionsGranted,
    required this.isActiveSource,
    required this.activeSourceLabel,
    required this.typePermissions,
  });

  String get statusLabel {
    if (!isAvailable) return 'Not installed';
    if (isConnected) return 'Connected';
    if (hasCorePermissions) return 'Permissions granted';
    if (hasAnyPermission) return 'Partial access';
    return 'Not connected';
  }

  /// Health Connect is actively syncing core metrics.
  bool get isConnected => isAvailable && isActiveSource && hasCorePermissions;

  /// Steps plus at least one calories type, distance, and water.
  bool get hasCorePermissions {
    final steps = typePermissions['Steps'] ?? false;
    final calories = (typePermissions['Active calories'] ?? false) ||
        (typePermissions['Total calories'] ?? false);
    final distance = typePermissions['Distance'] ?? false;
    final water = typePermissions['Water'] ?? false;
    return steps && calories && distance && water;
  }

  bool get hasAnyPermission => typePermissions.values.any((granted) => granted);

  bool get needsInstall =>
      sdkStatus == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired ||
      sdkStatus == HealthConnectSdkStatus.sdkUnavailable;
}
