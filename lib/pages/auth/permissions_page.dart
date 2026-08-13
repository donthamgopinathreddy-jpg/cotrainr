import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:health/health.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/auth_theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/auth/auth_screen_background.dart';
import '../../widgets/auth/auth_ui.dart';
import '../../widgets/provider/provider_professional_form_validation.dart';
import 'package:flutter/services.dart';

class PermissionsPage extends StatefulWidget {
  final String userRole; // 'client', 'trainer', 'nutritionist'

  const PermissionsPage({
    super.key,
    required this.userRole,
  });

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  Map<Permission?, PermissionStatus> _permissionStatuses = {};
  bool _isRequesting = false;

  final List<PermissionItem> _permissions = [
    PermissionItem(
      permission: null, // Health permission handled separately
      title: 'Health Data',
      description: 'Track your steps, calories burned, and activity data',
      icon: Icons.favorite,
      isRequired: true,
      isHealth: true,
    ),
    PermissionItem(
      permission: Permission.location,
      title: 'Location',
      description: 'Calculate distance traveled using GPS',
      icon: Icons.location_on,
      isRequired: true,
    ),
    PermissionItem(
      permission: Permission.camera,
      title: 'Camera',
      description: 'Take photos for profile and progress tracking',
      icon: Icons.camera_alt,
      isRequired: false,
    ),
    PermissionItem(
      permission: Permission.microphone,
      title: 'Microphone',
      description: 'Record voice messages and video calls',
      icon: Icons.mic,
      isRequired: false,
    ),
    PermissionItem(
      permission: Permission.storage,
      title: 'Storage',
      description: 'Save photos, documents, and app data',
      icon: Icons.folder,
      isRequired: false,
    ),
    PermissionItem(
      permission: Permission.notification,
      title: 'Notifications',
      description: 'Receive important updates and reminders',
      icon: Icons.notifications,
      isRequired: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final Map<Permission?, PermissionStatus> statuses = {};
    for (var item in _permissions) {
      if (item.isHealth) {
        // Check health permission separately
        try {
          final health = Health();
          final types = [
            HealthDataType.STEPS,
            HealthDataType.ACTIVE_ENERGY_BURNED,
            HealthDataType.DISTANCE_WALKING_RUNNING,
          ];
          final hasPermissions = await health.hasPermissions(types);
          statuses[null] = hasPermissions == true 
              ? PermissionStatus.granted 
              : PermissionStatus.denied;
        } catch (e) {
          statuses[null] = PermissionStatus.denied;
        }
      } else if (item.permission != null) {
        statuses[item.permission] = await item.permission!.status;
      }
    }
    setState(() {
      _permissionStatuses.clear();
      _permissionStatuses.addAll(statuses);
    });
  }

  Future<void> _requestPermission(PermissionItem item) async {
    setState(() => _isRequesting = true);
    HapticFeedback.lightImpact();

    PermissionStatus status;
    
    // Special handling for health permission
    if (item.isHealth) {
      try {
        // Request health permissions using health package
        final types = [
          HealthDataType.STEPS,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.DISTANCE_WALKING_RUNNING,
        ];
        
        final health = Health();
        bool? hasPermissions = await health.hasPermissions(types);
        
        if (hasPermissions == false) {
          try {
            hasPermissions = await health.requestAuthorization(types);
          } catch (e) {
            // Handle "Permission launcher not found" error gracefully
            // This happens when the health package can't open system settings
            // User can still grant permission manually through app settings
            print('Health permission request error (non-critical): $e');
            // Try to open app settings as fallback
            try {
              await openAppSettings();
            } catch (_) {
              // Ignore if we can't open settings either
            }
            hasPermissions = false;
          }
        }
        
        status = hasPermissions == true 
            ? PermissionStatus.granted 
            : PermissionStatus.denied;
      } catch (e) {
        print('Error checking health permissions: $e');
        status = PermissionStatus.denied;
      }
    } else if (item.permission == Permission.location) {
      // Special handling for location permission
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        status = PermissionStatus.denied;
      } else {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        status = permission == LocationPermission.whileInUse || 
                 permission == LocationPermission.always
            ? PermissionStatus.granted
            : PermissionStatus.denied;
      }
    } else if (item.permission != null) {
      status = await item.permission!.request();
    } else {
      status = PermissionStatus.denied;
    }

    setState(() {
      _permissionStatuses[item.permission] = status;
      _isRequesting = false;
    });

    if (status.isGranted) {
      HapticFeedback.mediumImpact();
    } else if (status.isPermanentlyDenied) {
      _showPermissionDeniedDialog(item);
    }
  }

  void _showPermissionDeniedDialog(PermissionItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${item.title} Permission Required'),
        content: Text(
          'Please enable ${item.title.toLowerCase()} permission in your device settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.of(context).pop();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestAllPermissions() async {
    setState(() => _isRequesting = true);
    HapticFeedback.mediumImpact();

    for (var item in _permissions) {
      if (!_permissionStatuses[item.permission]!.isGranted) {
        await _requestPermission(item);
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    setState(() => _isRequesting = false);
    _proceedToApp();
  }

  void _navigateAfterOnboarding() {
    HapticFeedback.heavyImpact();
    context.go(postPermissionsDestination(widget.userRole));
  }

  void _proceedToApp() {
    // Check if required permissions are granted
    final requiredPermissions = _permissions.where((p) => p.isRequired).toList();
    final allRequiredGranted = requiredPermissions.every(
      (item) {
        final key = item.isHealth ? null : item.permission;
        return _permissionStatuses[key]?.isGranted ?? false;
      },
    );

    if (allRequiredGranted) {
      _navigateAfterOnboarding();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please grant required permissions to continue',
          ),
          backgroundColor: DesignTokens.accentRed,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _requestAllPermissions,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final borderColor = DesignTokens.borderColorOf(context);
    final pageBg = AuthUi.pageBg(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AuthTheme.overlay(context),
      child: Scaffold(
        backgroundColor: pageBg,
        body: AuthScreenBackground.onboarding(
          scrimStrength: 0.4,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AuthBrandLogo(width: 120),
                  const SizedBox(height: 18),
                  Text(
                    'Enable Permissions',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: DesignTokens.fontSizeH1,
                      fontWeight: DesignTokens.fontWeightBold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Grant permissions to track your health data and enhance your experience',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: DesignTokens.fontSizeBody,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Permissions List
                  Expanded(
                    child: ListView.builder(
                      itemCount: _permissions.length,
                      itemBuilder: (context, index) {
                        final item = _permissions[index];
                        final status = _permissionStatuses[item.permission] ??
                            PermissionStatus.denied;
                        final isGranted = status.isGranted;

                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 280 + index * 40),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 10 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AuthTheme.surface(context),
                              borderRadius: BorderRadius.circular(
                                DesignTokens.radiusCard,
                              ),
                              border: Border.all(
                                color: isGranted
                                    ? DesignTokens.accentGreen
                                        .withValues(alpha: 0.7)
                                    : borderColor,
                                width: isGranted ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isGranted
                                        ? DesignTokens.accentGreen
                                            .withValues(alpha: 0.12)
                                        : DesignTokens.accentOrange
                                            .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(
                                      DesignTokens.radiusSmall,
                                    ),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    color: isGranted
                                        ? DesignTokens.accentGreen
                                        : DesignTokens.accentOrange,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: TextStyle(
                                                color: textPrimary,
                                                fontSize:
                                                    DesignTokens.fontSizeBody,
                                                fontWeight: DesignTokens
                                                    .fontWeightSemiBold,
                                              ),
                                            ),
                                          ),
                                          if (item.isRequired)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: DesignTokens.accentRed
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Required',
                                                style: TextStyle(
                                                  color:
                                                      DesignTokens.accentRed,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.description,
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize:
                                              DesignTokens.fontSizeBodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (isGranted)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: DesignTokens.accentGreen,
                                    size: 24,
                                  )
                                else
                                  TextButton(
                                    onPressed: _isRequesting
                                        ? null
                                        : () => _requestPermission(item),
                                    child: const Text(
                                      'Grant',
                                      style: TextStyle(
                                        color: DesignTokens.accentOrange,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _navigateAfterOnboarding();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                DesignTokens.radiusButton,
                              ),
                              side: BorderSide(color: borderColor),
                            ),
                          ),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: DesignTokens.fontSizeBody,
                              fontWeight: DesignTokens.fontWeightSemiBold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: AuthPrimaryButton(
                          label: 'Allow All',
                          isLoading: _isRequesting,
                          onPressed:
                              _isRequesting ? null : _requestAllPermissions,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PermissionItem {
  final Permission? permission;
  final String title;
  final String description;
  final IconData icon;
  final bool isRequired;
  final bool isHealth;

  PermissionItem({
    this.permission,
    required this.title,
    required this.description,
    required this.icon,
    this.isRequired = false,
    this.isHealth = false,
  });
}
