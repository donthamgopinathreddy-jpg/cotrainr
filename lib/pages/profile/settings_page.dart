import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/theme_mode_provider.dart';
import '../../providers/profile_images_provider.dart';
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
  bool _privateAccount = false;
  bool _showLocation = true;
  bool _pushNotifications = true;
  bool _communityNotifications = true;
  bool _reminderNotifications = true;

  /// Get current user role from Supabase
  String? get _userRole {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    return user?.userMetadata?['role']?.toString().toLowerCase();
  }

  /// Check if user is a provider (trainer or nutritionist)
  bool get _isProvider {
    final role = _userRole;
    return role == 'trainer' || role == 'nutritionist';
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
    final bg = isDark ? colorScheme.surface : const Color(0xFFFFF3E0);

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
            name: 'Gopinath Reddy',
            username: '@gopi_5412',
          ),
          const SizedBox(height: 16),
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
              foregroundColor: colorScheme.error,
              side: BorderSide.none,
              backgroundColor: colorScheme.error.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.logout),
            label: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w700),
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
    const bg = Color(0xFFFFE0B2); // light orange

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
  final String name;
  final String username;

  const _ProfileSection({
    required this.profileImagePath,
    required this.name,
    required this.username,
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
              image: profileImagePath != null && profileImagePath!.isNotEmpty
                  ? DecorationImage(
                      image: profileImagePath!.startsWith('http')
                          ? NetworkImage(profileImagePath!)
                          : FileImage(File(profileImagePath!)) as ImageProvider,
                      fit: BoxFit.cover,
                    )
                  : null,
              color: profileImagePath == null || profileImagePath!.isEmpty
                  ? colorScheme.surfaceContainerHighest
                  : null,
            ),
            child: profileImagePath == null || profileImagePath!.isEmpty
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
        ],
      ),
    );
  }
}

