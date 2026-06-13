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
    if (isActiveSource && permissionsGranted) return 'Connected';
    if (permissionsGranted) return 'Permissions granted';
    return 'Not connected';
  }

  bool get needsInstall =>
      sdkStatus == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired ||
      sdkStatus == HealthConnectSdkStatus.sdkUnavailable;
}
