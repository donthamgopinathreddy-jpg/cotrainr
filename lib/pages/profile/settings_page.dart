import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/theme_mode_provider.dart';
import '../../providers/profile_images_provider.dart';
import '../../repositories/profile_repository.dart';
import '../../utils/page_transitions.dart';
import 'edit_profile_page.dart';
import 'settings/info_pages.dart';
import '../../widgets/common/logout_confirmation_sheet.dart';
import '../../pages/help/app_version_page.dart';
import 'settings/notifications_page.dart';
import 'settings/privacy_security_page.dart';
import 'settings/service_locations_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final ProfileRepository _profileRepo = ProfileRepository();
  
  bool _privateAccount = false;
  bool _showLocation = true;
  bool _pushNotifications = true;
  bool _communityNotifications = true;
  bool _reminderNotifications = true;
  
  // Profile data
  Map<String, dynamic>? _profile;
  bool _isLoadingProfile = true;
  bool _isAccountDetailsExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final profile = await _profileRepo.fetchMyProfile();
      setState(() {
        _profile = profile;
        _isLoadingProfile = false;
      });
    } catch (e) {
      setState(() => _isLoadingProfile = false);
      print('Error loading profile: $e');
    }
  }

  /// Get current user role from Supabase
  String? get _userRole {
    return _profile?['role'] as String?;
  }

  /// Check if user is a provider (trainer or nutritionist)
  bool get _isProvider {
    final role = _userRole;
    return role == 'trainer' || role == 'nutritionist';
  }
  
  String get _displayName {
    return _profile?['full_name'] as String? ?? 
           _profile?['username'] as String? ?? 
           'User';
  }
  
  String get _username {
    return _profile?['username'] as String? ?? '';
  }

  // (Image picking previously lived here; removed since it's not used in current Settings UI.)

  void _navigateToEditProfile(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageTransitions.slideRoute(
        const EditProfilePage(),
        beginOffset: const Offset(0, 0.05),
      ),
    );
  }

  Future<void> _openPrivacySecurity(BuildContext context) async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push<PrivacySecurityResult>(
      context,
      PageTransitions.slideRoute(
        PrivacySecurityPage(
          privateAccount: _privateAccount,
          showLocation: _showLocation,
        ),
        beginOffset: const Offset(0, 0.05),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _privateAccount = result.privateAccount;
      _showLocation = result.showLocation;
    });
  }

  Future<void> _openNotifications(BuildContext context) async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push<NotificationsResult>(
      context,
      PageTransitions.slideRoute(
        NotificationsPage(
          pushNotifications: _pushNotifications,
          communityNotifications: _communityNotifications,
          reminderNotifications: _reminderNotifications,
        ),
        beginOffset: const Offset(0, 0.05),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _pushNotifications = result.push;
      _communityNotifications = result.community;
      _reminderNotifications = result.reminders;
    });
  }

  void _openInfoPage(BuildContext context, Widget page) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageTransitions.slideRoute(page, beginOffset: const Offset(0, 0.05)),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    HapticFeedback.mediumImpact();
    
    try {
      // Sign out from Supabase
      await Supabase.instance.client.auth.signOut();
      
      if (!mounted) return;
      
      // Navigate to splash (which will check session and go to login)
      context.go('/splash');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final profileImages = ref.watch(profileImagesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark 
        ? Colors.black // Total black
        : Colors.grey.shade100; // Light grey

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colorScheme.onBackground,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Profile Section
          _ProfileSection(
            profileImagePath: profileImages.profileImagePath,
            avatarUrl: _profile?['avatar_url'] as String?,
            name: _isLoadingProfile ? 'Loading...' : _displayName,
            username: _isLoadingProfile ? '@loading' : '@$_username',
            isExpanded: _isAccountDetailsExpanded,
            onToggleExpanded: () {
              setState(() {
                _isAccountDetailsExpanded = !_isAccountDetailsExpanded;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Account Details Section (shows all signup flow details - collapsible)
          if (_isAccountDetailsExpanded && !_isLoadingProfile && _profile != null) ...[
            _AccountDetailsSection(profile: _profile!),
            const SizedBox(height: 16),
          ],
          _SettingsGroup(
            title: 'Account',
            children: [
              _SettingsRow(
                icon: Icons.edit,
                title: 'Edit Profile',
                onTap: () => _navigateToEditProfile(context),
              ),
              _SettingsRow(
                icon: Icons.security,
                title: 'Privacy & Security',
                onTap: () => _openPrivacySecurity(context),
              ),
              // Service Locations (only for trainers and nutritionists)
              if (_isProvider)
                _SettingsRow(
                  icon: Icons.location_on_rounded,
                  title: 'Service Locations',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      PageTransitions.slideRoute(
                        const ServiceLocationsPage(),
                        beginOffset: const Offset(0, 0.05),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: 'App',
            children: [
              _AppearanceRow(
                themeMode: themeMode,
                onChanged: (mode) =>
                    ref.read(themeModeProvider.notifier).state = mode,
              ),
              _SettingsRow(
                icon: Icons.notifications_none,
                title: 'Notifications',
                onTap: () => _openNotifications(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: 'Support',
            children: [
              _SettingsRow(
                icon: Icons.help_outline,
                title: 'Help Center',
                onTap: () => _openInfoPage(context, const HelpCenterPage()),
              ),
              _SettingsRow(
                icon: Icons.quiz_outlined,
                title: 'FAQ',
                onTap: () => _openInfoPage(context, const FaqPage()),
              ),
              _SettingsRow(
                icon: Icons.feedback_outlined,
                title: 'Feedback',
                onTap: () => _openInfoPage(context, const FeedbackPage()),
              ),
              _SettingsRow(
                icon: Icons.report_problem_outlined,
                title: 'Report a Problem',
                onTap: () => _openInfoPage(context, const ReportProblemPage()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: 'About',
            children: [
              _SettingsRow(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () => _openInfoPage(context, const TermsOfServicePage()),
              ),
              _SettingsRow(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () => _openInfoPage(context, const PrivacyPolicyPage()),
              ),
              _SettingsRow(
                icon: Icons.info_outline,
                title: 'App Version',
                onTap: () => _openInfoPage(context, const AppVersionPage()),
              ),
            ],
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              HapticFeedback.lightImpact();
              await LogoutConfirmationSheet.show(
                context,
                () => _handleLogout(context),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: Colors.white,
              side: BorderSide.none,
              backgroundColor: colorScheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text(
              'Logout',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// (_themeIndexFromMode / _themeModeFromIndex removed; Appearance uses icon selector.)

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color textColor = colorScheme.onSurface;
    final Color iconColor = colorScheme.onSurface.withOpacity(0.7);

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right,
                    color: colorScheme.onSurface.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

// (_ToggleRow removed; notification/privacy toggles are now on dedicated pages.)

// (_SegmentRow removed; Appearance uses icon selector.)

class _AppearanceRow extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChanged;

  const _AppearanceRow({
    required this.themeMode,
    required this.onChanged,
  });

  int _indexFromMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 0;
      case ThemeMode.light:
        return 1;
      case ThemeMode.dark:
        return 2;
    }
  }

  ThemeMode _modeFromIndex(int index) {
    switch (index) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      case 0:
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = _indexFromMode(themeMode);
    final bg = Colors.grey.withOpacity(0.3); // grey

    Widget seg(int index, IconData icon) {
      final isSelected = index == selected;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(_modeFromIndex(index)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected ? cs.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : cs.onSurface,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Appearance',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              seg(0, Icons.brightness_auto_rounded),
              seg(1, Icons.light_mode_rounded),
              seg(2, Icons.dark_mode_rounded),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String? profileImagePath;
  final String? avatarUrl;
  final String name;
  final String username;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;

  const _ProfileSection({
    required this.profileImagePath,
    this.avatarUrl,
    required this.name,
    required this.username,
    this.isExpanded = false,
    this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: (avatarUrl != null && avatarUrl!.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : (profileImagePath != null && profileImagePath!.isNotEmpty)
                      ? DecorationImage(
                          image: profileImagePath!.startsWith('http')
                              ? NetworkImage(profileImagePath!)
                              : FileImage(File(profileImagePath!)) as ImageProvider,
                          fit: BoxFit.cover,
                        )
                      : null,
              color: (avatarUrl == null || avatarUrl!.isEmpty) &&
                      (profileImagePath == null || profileImagePath!.isEmpty)
                  ? colorScheme.surfaceContainerHighest
                  : null,
            ),
            child: (avatarUrl == null || avatarUrl!.isEmpty) &&
                    (profileImagePath == null || profileImagePath!.isEmpty)
                ? Icon(Icons.person, size: 32, color: colorScheme.onSurface.withOpacity(0.5))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  username,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          if (onToggleExpanded != null)
            IconButton(
              icon: Icon(
                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              ),
              onPressed: onToggleExpanded,
              tooltip: isExpanded ? 'Hide account details' : 'Show account details',
            ),
        ],
      ),
    );
  }
}

/// Account Details Section - Shows all signup flow details
class _AccountDetailsSection extends StatelessWidget {
  final Map<String, dynamic> profile;

  const _AccountDetailsSection({required this.profile});

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateOfBirth(dynamic dob) {
    if (dob == null) return 'Not set';
    if (dob is DateTime) return _formatDate(dob);
    if (dob is String) {
      try {
        final date = DateTime.parse(dob);
        return _formatDate(date);
      } catch (e) {
        return dob.toString();
      }
    }
    return dob.toString();
  }

  @override
  Widget build(BuildContext context) {
    final heightCm = (profile['height_cm'] as num?)?.toInt();
    final weightKg = (profile['weight_kg'] as num?)?.toDouble();
    final dob = profile['date_of_birth'];
    final gender = profile['gender'] as String?;
    final phone = profile['phone'] as String?;
    final email = profile['email'] as String?;

    return _SettingsGroup(
      title: 'Account Details',
      children: [
        _DetailRow(
          label: 'Email',
          value: email ?? 'Not set',
          icon: Icons.email_outlined,
        ),
        _DetailRow(
          label: 'Phone',
          value: phone ?? 'Not set',
          icon: Icons.phone_outlined,
        ),
        _CombinedDetailRow(
          leftLabel: 'Date of Birth',
          leftValue: _formatDateOfBirth(dob),
          leftIcon: Icons.calendar_today_outlined,
          rightLabel: 'Gender',
          rightValue: gender ?? 'Not set',
          rightIcon: Icons.wc_outlined,
        ),
        _CombinedDetailRow(
          leftLabel: 'Height',
          leftValue: heightCm != null ? '$heightCm cm' : 'Not set',
          leftIcon: Icons.height,
          rightLabel: 'Weight',
          rightValue: weightKg != null ? '${weightKg.toStringAsFixed(1)} kg' : 'Not set',
          rightIcon: Icons.monitor_weight_outlined,
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color textColor = valueColor ?? colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurface.withOpacity(0.7), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CombinedDetailRow extends StatelessWidget {
  final String leftLabel;
  final String leftValue;
  final IconData leftIcon;
  final String rightLabel;
  final String rightValue;
  final IconData rightIcon;

  const _CombinedDetailRow({
    required this.leftLabel,
    required this.leftValue,
    required this.leftIcon,
    required this.rightLabel,
    required this.rightValue,
    required this.rightIcon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Left field
          Expanded(
            child: Row(
              children: [
                Icon(leftIcon, color: colorScheme.onSurface.withOpacity(0.7), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leftLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        leftValue,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right field
          Expanded(
            child: Row(
              children: [
                Icon(rightIcon, color: colorScheme.onSurface.withOpacity(0.7), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rightLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rightValue,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

