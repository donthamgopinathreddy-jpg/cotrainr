import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/theme_mode_provider.dart';
import '../../providers/profile_images_provider.dart';
import '../../utils/page_transitions.dart';
import 'edit_profile_page.dart';

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

  Future<void> _pickProfileImage(BuildContext context) async {
    HapticFeedback.lightImpact();
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      ref.read(profileImagesProvider.notifier).updateProfileImage(image.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _pickCoverImage(BuildContext context) async {
    HapticFeedback.lightImpact();
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      ref.read(profileImagesProvider.notifier).updateCoverImage(image.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cover photo updated'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final profileImages = ref.watch(profileImagesProvider);

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
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
                icon: Icons.lock_outline,
                title: 'Privacy',
                onTap: () => HapticFeedback.lightImpact(),
              ),
              _SettingsRow(
                icon: Icons.security,
                title: 'Security',
                onTap: () => HapticFeedback.lightImpact(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: 'App',
            children: [
              _SegmentRow(
                title: 'Appearance',
                options: const ['System', 'Light', 'Dark'],
                selectedIndex: _themeIndexFromMode(themeMode),
                onChanged: (value) {
                  ref.read(themeModeProvider.notifier).state =
                      _themeModeFromIndex(value);
                },
              ),
              _SettingsRow(
                icon: Icons.notifications_none,
                title: 'Notifications',
                onTap: () => HapticFeedback.lightImpact(),
              ),
              _SettingsRow(
                icon: Icons.language,
                title: 'Language',
                onTap: () => HapticFeedback.lightImpact(),
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
                onTap: () => HapticFeedback.lightImpact(),
              ),
              _SettingsRow(
                icon: Icons.help_outline,
                title: 'FAQ',
                onTap: () => HapticFeedback.lightImpact(),
              ),
              _SettingsRow(
                icon: Icons.feedback_outlined,
                title: 'Feedback',
                onTap: () => HapticFeedback.lightImpact(),
              ),
              _SettingsRow(
                icon: Icons.report_problem_outlined,
                title: 'Report a Problem',
                onTap: () => HapticFeedback.lightImpact(),
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
                onTap: () => HapticFeedback.lightImpact(),
              ),
              _SettingsRow(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () => HapticFeedback.lightImpact(),
              ),
              _SettingsRow(
                icon: Icons.info_outline,
                title: 'App Version',
                trailing: const Text(
                  '1.0.0',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => HapticFeedback.mediumImpact(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error.withOpacity(0.6)),
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

int _themeIndexFromMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 1;
    case ThemeMode.dark:
      return 2;
    case ThemeMode.system:
      return 0;
  }
}

ThemeMode _themeModeFromIndex(int index) {
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
        border: Border.all(color: colorScheme.outline.withOpacity(0.18)),
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

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurface.withOpacity(0.7), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  final String title;
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentRow({
    required this.title,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: List.generate(options.length, (index) {
              final isSelected = index == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        options[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              isSelected ? Colors.white : colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
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
        border: Border.all(color: colorScheme.outline.withOpacity(0.18)),
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

